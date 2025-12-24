"""
Custom permissions for Chippin API.
"""
from rest_framework import permissions


class IsGroupMember(permissions.BasePermission):
    """
    Permission to check if user is a member of the group.
    """
    message = "You must be a member of this group."

    def has_object_permission(self, request, view, obj):
        # Handle both Group objects and objects with a 'group' field
        if hasattr(obj, 'members'):
            group = obj
        elif hasattr(obj, 'group'):
            group = obj.group
        else:
            return False

        return group.members.filter(id=request.user.id).exists()


class IsGroupOwnerOrAdmin(permissions.BasePermission):
    """
    Permission to check if user is owner or admin of the group.
    """
    message = "You must be the owner or admin of this group."

    def has_object_permission(self, request, view, obj):
        from api.models import GroupMembership

        if hasattr(obj, 'members'):
            group = obj
        elif hasattr(obj, 'group'):
            group = obj.group
        else:
            return False

        # Check if owner
        if group.owner == request.user:
            return True

        # Check membership role
        try:
            membership = GroupMembership.objects.get(user=request.user, group=group)
            return membership.role in ['owner', 'admin']
        except GroupMembership.DoesNotExist:
            return False


class IsExpenseOwner(permissions.BasePermission):
    """
    Permission to check if user created the expense or is group admin.
    """
    message = "You can only modify expenses you created."

    def has_object_permission(self, request, view, obj):
        # Allow group owner/admin
        if obj.group.owner == request.user:
            return True

        # Allow expense creator
        return obj.created_by == request.user


class IsOwnerOrReadOnly(permissions.BasePermission):
    """
    Object-level permission to only allow owners to edit objects.
    """

    def has_object_permission(self, request, view, obj):
        # Read permissions for any request
        if request.method in permissions.SAFE_METHODS:
            return True

        # Write permissions only for owner
        if hasattr(obj, 'owner'):
            return obj.owner == request.user
        if hasattr(obj, 'created_by'):
            return obj.created_by == request.user

        return False
