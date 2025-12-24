"""
Expense views for Chippin API.
"""
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from django.utils import timezone

from api.models import Expense, ExpenseSplit, Group, Settlement, Category
from api.serializers import (
    ExpenseSerializer, ExpenseListSerializer, SettlementSerializer, CategorySerializer
)
from api.permissions import IsGroupMember, IsExpenseOwner


class ExpenseViewSet(viewsets.ModelViewSet):
    """
    ViewSet for Expense CRUD operations.
    """
    serializer_class = ExpenseSerializer

    def get_queryset(self):
        """Return expenses for groups where user is a member."""
        user_groups = Group.objects.filter(members=self.request.user)
        queryset = Expense.objects.filter(
            group__in=user_groups,
            is_deleted=False
        ).select_related('paid_by', 'created_by', 'category', 'group').prefetch_related('splits')

        # Filter by group if specified
        group_id = self.request.query_params.get('group')
        if group_id:
            queryset = queryset.filter(group_id=group_id)

        # Filter by category
        category = self.request.query_params.get('category')
        if category:
            queryset = queryset.filter(category_id=category)

        # Filter by date range
        start_date = self.request.query_params.get('start_date')
        end_date = self.request.query_params.get('end_date')
        if start_date:
            queryset = queryset.filter(expense_date__gte=start_date)
        if end_date:
            queryset = queryset.filter(expense_date__lte=end_date)

        # Filter by settled status
        is_settled = self.request.query_params.get('is_settled')
        if is_settled is not None:
            queryset = queryset.filter(is_settled=is_settled.lower() == 'true')

        return queryset

    def get_serializer_class(self):
        """Use different serializers for different actions."""
        if self.action == 'list':
            return ExpenseListSerializer
        return ExpenseSerializer

    def get_permissions(self):
        """Set permissions based on action."""
        if self.action in ['update', 'partial_update', 'destroy']:
            return [IsExpenseOwner()]
        return super().get_permissions()

    def create(self, request, *args, **kwargs):
        """Create a new expense."""
        # Verify user is member of the group
        group_id = request.data.get('group')
        if group_id:
            group = get_object_or_404(Group, id=group_id)
            if not group.members.filter(id=request.user.id).exists():
                return Response(
                    {'error': 'You are not a member of this group'},
                    status=status.HTTP_403_FORBIDDEN
                )

        return super().create(request, *args, **kwargs)

    def destroy(self, request, *args, **kwargs):
        """Soft delete an expense."""
        expense = self.get_object()
        expense.is_deleted = True
        expense.save(update_fields=['is_deleted', 'updated_at'])
        return Response(status=status.HTTP_204_NO_CONTENT)

    @action(detail=True, methods=['post'])
    def settle(self, request, pk=None):
        """Mark an expense as settled."""
        expense = self.get_object()
        expense.is_settled = True
        expense.save(update_fields=['is_settled', 'updated_at'])

        # Mark all splits as settled
        expense.splits.update(is_settled=True, settled_at=timezone.now())

        return Response({'message': 'Expense marked as settled'})

    @action(detail=False, methods=['get'])
    def summary(self, request):
        """
        Get expense summary for a group.
        """
        group_id = request.query_params.get('group')
        if not group_id:
            return Response(
                {'error': 'group parameter is required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        group = get_object_or_404(Group, id=group_id)
        if not group.members.filter(id=request.user.id).exists():
            return Response(
                {'error': 'You are not a member of this group'},
                status=status.HTTP_403_FORBIDDEN
            )

        expenses = Expense.objects.filter(group=group, is_deleted=False)

        # Calculate totals
        from django.db.models import Sum, Count
        from django.db.models.functions import TruncMonth

        total = expenses.aggregate(
            total_amount=Sum('amount'),
            total_count=Count('id')
        )

        # Category breakdown
        category_breakdown = expenses.values(
            'category__name', 'category__icon'
        ).annotate(
            total=Sum('amount'),
            count=Count('id')
        ).order_by('-total')

        # Monthly breakdown
        monthly_breakdown = expenses.annotate(
            month=TruncMonth('expense_date')
        ).values('month').annotate(
            total=Sum('amount'),
            count=Count('id')
        ).order_by('-month')[:12]

        # User breakdown (who paid most)
        user_breakdown = expenses.values(
            'paid_by__id', 'paid_by__display_name'
        ).annotate(
            total=Sum('amount'),
            count=Count('id')
        ).order_by('-total')

        return Response({
            'total_amount': float(total['total_amount'] or 0),
            'total_count': total['total_count'] or 0,
            'by_category': list(category_breakdown),
            'by_month': [
                {
                    'month': item['month'].isoformat() if item['month'] else None,
                    'total': float(item['total']),
                    'count': item['count']
                }
                for item in monthly_breakdown
            ],
            'by_user': [
                {
                    'user_id': str(item['paid_by__id']),
                    'display_name': item['paid_by__display_name'],
                    'total': float(item['total']),
                    'count': item['count']
                }
                for item in user_breakdown
            ]
        })


class SettlementViewSet(viewsets.ModelViewSet):
    """
    ViewSet for Settlement operations.
    """
    serializer_class = SettlementSerializer

    def get_queryset(self):
        """Return settlements for groups where user is a member."""
        user_groups = Group.objects.filter(members=self.request.user)
        queryset = Settlement.objects.filter(
            group__in=user_groups
        ).select_related('from_user', 'to_user', 'created_by', 'group')

        # Filter by group if specified
        group_id = self.request.query_params.get('group')
        if group_id:
            queryset = queryset.filter(group_id=group_id)

        return queryset

    def create(self, request, *args, **kwargs):
        """Create a new settlement."""
        group_id = request.data.get('group')
        if group_id:
            group = get_object_or_404(Group, id=group_id)
            if not group.members.filter(id=request.user.id).exists():
                return Response(
                    {'error': 'You are not a member of this group'},
                    status=status.HTTP_403_FORBIDDEN
                )

        # Set created_by
        request.data['created_by'] = request.user.id

        return super().create(request, *args, **kwargs)


class CategoryViewSet(viewsets.ModelViewSet):
    """
    ViewSet for Category operations.
    """
    serializer_class = CategorySerializer

    def get_queryset(self):
        """Return preset categories and custom categories for user's groups."""
        user_groups = Group.objects.filter(members=self.request.user)
        return Category.objects.filter(
            models.Q(is_preset=True) |
            models.Q(group__in=user_groups)
        )

    def list(self, request, *args, **kwargs):
        """List all categories including presets."""
        # Get predefined categories
        presets = [
            {'id': cat[0], 'name': cat[1], 'icon': cat[2], 'is_preset': True}
            for cat in Category.PRESET_CATEGORIES
        ]

        # Get custom categories
        user_groups = Group.objects.filter(members=request.user)
        custom = Category.objects.filter(group__in=user_groups)
        custom_serialized = CategorySerializer(custom, many=True).data

        return Response({
            'presets': presets,
            'custom': custom_serialized
        })


# Import models for the Q object
from django.db import models
