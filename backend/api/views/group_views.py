"""
Group views for Chippin API.
"""
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django.shortcuts import get_object_or_404

from api.models import Group, GroupMembership, User
from api.serializers import (
    GroupSerializer, GroupListSerializer, GroupCreateSerializer,
    JoinGroupSerializer, GroupMembershipSerializer, BalanceSerializer
)
from api.permissions import IsGroupMember, IsGroupOwnerOrAdmin


class GroupViewSet(viewsets.ModelViewSet):
    """
    ViewSet for Group CRUD operations.
    """
    serializer_class = GroupSerializer

    def get_queryset(self):
        """Return groups where user is a member."""
        return Group.objects.filter(
            members=self.request.user,
            is_active=True
        ).prefetch_related('members', 'groupmembership_set')

    def get_serializer_class(self):
        """Use different serializers for different actions."""
        if self.action == 'list':
            return GroupListSerializer
        if self.action == 'create':
            return GroupCreateSerializer
        return GroupSerializer

    def get_permissions(self):
        """Set permissions based on action."""
        if self.action in ['update', 'partial_update', 'destroy']:
            return [IsGroupOwnerOrAdmin()]
        if self.action in ['retrieve', 'members', 'balances']:
            return [IsGroupMember()]
        return super().get_permissions()

    def create(self, request, *args, **kwargs):
        """Create a new group."""
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        group = serializer.save()
        
        # Return full group details
        response_serializer = GroupSerializer(group)
        return Response(response_serializer.data, status=status.HTTP_201_CREATED)

    @action(detail=False, methods=['post'])
    def join(self, request):
        """
        Join a group using invite code.

        Request body:
        {
            "invite_code": "ABC12345"
        }
        """
        serializer = JoinGroupSerializer(data=request.data, context={'request': request})
        serializer.is_valid(raise_exception=True)
        group = serializer.save()
        
        response_serializer = GroupSerializer(group)
        return Response(response_serializer.data, status=status.HTTP_200_OK)

    @action(detail=True, methods=['get'])
    def members(self, request, pk=None):
        """Get group members."""
        group = self.get_object()
        memberships = GroupMembership.objects.filter(group=group).select_related('user')
        serializer = GroupMembershipSerializer(memberships, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def leave(self, request, pk=None):
        """Leave a group."""
        group = self.get_object()

        # Owner cannot leave
        if group.owner == request.user:
            return Response(
                {'error': 'Owner cannot leave the group. Transfer ownership first.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            membership = GroupMembership.objects.get(user=request.user, group=group)
            membership.delete()
            return Response({'message': 'Left group successfully'})
        except GroupMembership.DoesNotExist:
            return Response(
                {'error': 'Not a member of this group'},
                status=status.HTTP_400_BAD_REQUEST
            )

    @action(detail=True, methods=['post'])
    def remove_member(self, request, pk=None):
        """Remove a member from the group (owner/admin only)."""
        group = self.get_object()
        user_id = request.data.get('user_id')

        if not user_id:
            return Response(
                {'error': 'user_id is required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Check permission
        if not IsGroupOwnerOrAdmin().has_object_permission(request, self, group):
            return Response(
                {'error': 'Only owner or admin can remove members'},
                status=status.HTTP_403_FORBIDDEN
            )

        # Cannot remove owner
        if str(group.owner.id) == user_id:
            return Response(
                {'error': 'Cannot remove the group owner'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            membership = GroupMembership.objects.get(user_id=user_id, group=group)
            membership.delete()
            return Response({'message': 'Member removed successfully'})
        except GroupMembership.DoesNotExist:
            return Response(
                {'error': 'User is not a member of this group'},
                status=status.HTTP_400_BAD_REQUEST
            )

    @action(detail=True, methods=['get'])
    def balances(self, request, pk=None):
        """
        Get balance summary for all members.
        Shows who owes whom and net amounts.
        """
        group = self.get_object()
        balances = self._calculate_balances(group)
        return Response(balances)

    def _calculate_balances(self, group):
        """Calculate balances for all group members."""
        from decimal import Decimal
        from collections import defaultdict
        from api.models import Expense, ExpenseSplit, Settlement

        # Get all expenses and splits
        expenses = Expense.objects.filter(
            group=group,
            is_deleted=False,
            is_settled=False
        ).prefetch_related('splits')

        # Get all settlements
        settlements = Settlement.objects.filter(group=group)

        # Calculate what each person has paid and owes
        paid = defaultdict(Decimal)
        owes = defaultdict(Decimal)

        for expense in expenses:
            paid[str(expense.paid_by_id)] += expense.amount
            for split in expense.splits.all():
                owes[str(split.user_id)] += split.amount

        # Apply settlements
        for settlement in settlements:
            paid[str(settlement.from_user_id)] += settlement.amount
            owes[str(settlement.from_user_id)] -= settlement.amount
            paid[str(settlement.to_user_id)] -= settlement.amount
            owes[str(settlement.to_user_id)] += settlement.amount

        # Calculate net balance for each member
        members = group.members.all()
        result = []

        for member in members:
            member_id = str(member.id)
            net_paid = paid.get(member_id, Decimal(0))
            net_owed = owes.get(member_id, Decimal(0))
            balance = net_paid - net_owed

            result.append({
                'user': {
                    'id': member_id,
                    'display_name': member.display_name,
                    'avatar_url': member.avatar_url
                },
                'paid': float(net_paid),
                'owes': float(net_owed),
                'balance': float(balance)  # Positive = owed money, Negative = owes money
            })

        # Sort by balance (who owes most first)
        result.sort(key=lambda x: x['balance'])

        # Calculate simplified debts (who should pay whom)
        simplified = self._simplify_debts(result)

        return {
            'balances': result,
            'simplified_debts': simplified
        }

    def _simplify_debts(self, balances):
        """
        Simplify debts to minimize transactions.
        Uses greedy algorithm to match creditors and debtors.
        """
        from decimal import Decimal

        debtors = []  # People who owe money (negative balance)
        creditors = []  # People who are owed money (positive balance)

        for b in balances:
            if b['balance'] < -0.01:
                debtors.append({
                    'user': b['user'],
                    'amount': abs(b['balance'])
                })
            elif b['balance'] > 0.01:
                creditors.append({
                    'user': b['user'],
                    'amount': b['balance']
                })

        # Sort for greedy matching
        debtors.sort(key=lambda x: x['amount'], reverse=True)
        creditors.sort(key=lambda x: x['amount'], reverse=True)

        transactions = []
        i, j = 0, 0

        while i < len(debtors) and j < len(creditors):
            debtor = debtors[i]
            creditor = creditors[j]

            amount = min(debtor['amount'], creditor['amount'])
            if amount > 0.01:
                transactions.append({
                    'from_user': debtor['user'],
                    'to_user': creditor['user'],
                    'amount': round(amount, 2)
                })

            debtor['amount'] -= amount
            creditor['amount'] -= amount

            if debtor['amount'] < 0.01:
                i += 1
            if creditor['amount'] < 0.01:
                j += 1

        return transactions

    @action(detail=True, methods=['post'])
    def regenerate_invite(self, request, pk=None):
        """Regenerate invite code for a group."""
        group = self.get_object()

        if not IsGroupOwnerOrAdmin().has_object_permission(request, self, group):
            return Response(
                {'error': 'Only owner or admin can regenerate invite code'},
                status=status.HTTP_403_FORBIDDEN
            )

        group.invite_code = group._generate_invite_code()
        group.save(update_fields=['invite_code'])

        return Response({'invite_code': group.invite_code})
