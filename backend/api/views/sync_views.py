"""
Sync views for Chippin API.
Handles offline-first sync operations.
"""
from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response
from django.utils import timezone
from django.db import transaction
from datetime import datetime

from api.models import Expense, ExpenseSplit, Group, Settlement, SyncLog
from api.serializers import (
    ExpenseSerializer, GroupSerializer, SettlementSerializer,
    SyncPushSerializer, SyncPullSerializer
)


class SyncPushView(APIView):
    """
    Push local changes to the server.
    Handles conflict resolution.
    """

    def post(self, request):
        """
        Push local changes to the server.

        Request body:
        {
            "changes": [
                {
                    "entity_type": "expense",
                    "operation": "create|update|delete",
                    "entity_id": "local_uuid",
                    "local_id": "optional_local_uuid",
                    "data": {...},
                    "client_timestamp": "2024-01-15T10:30:00Z"
                }
            ]
        }
        """
        changes = request.data.get('changes', [])
        if not changes:
            return Response({'error': 'No changes provided'}, status=status.HTTP_400_BAD_REQUEST)

        results = []
        conflicts = []

        with transaction.atomic():
            for change in changes:
                serializer = SyncPushSerializer(data=change)
                if not serializer.is_valid():
                    results.append({
                        'local_id': change.get('local_id') or change.get('entity_id'),
                        'success': False,
                        'error': serializer.errors
                    })
                    continue

                result = self._process_change(request.user, serializer.validated_data)
                if result.get('conflict'):
                    conflicts.append(result)
                results.append(result)

        return Response({
            'results': results,
            'conflicts': conflicts,
            'server_timestamp': timezone.now().isoformat()
        })

    def _process_change(self, user, change_data):
        """Process a single change and handle conflicts."""
        entity_type = change_data['entity_type']
        operation = change_data['operation']
        entity_id = change_data['entity_id']
        local_id = change_data.get('local_id')
        data = change_data['data']
        client_timestamp = change_data['client_timestamp']

        result = {
            'local_id': local_id or entity_id,
            'entity_type': entity_type,
            'operation': operation,
            'success': False
        }

        try:
            if entity_type == 'expense':
                result = self._sync_expense(user, operation, entity_id, local_id, data, client_timestamp, result)
            elif entity_type == 'group':
                result = self._sync_group(user, operation, entity_id, local_id, data, client_timestamp, result)
            elif entity_type == 'settlement':
                result = self._sync_settlement(user, operation, entity_id, local_id, data, client_timestamp, result)
            else:
                result['error'] = f'Unknown entity type: {entity_type}'

        except Exception as e:
            result['error'] = str(e)

        # Log sync operation
        SyncLog.objects.create(
            user=user,
            entity_type=entity_type,
            entity_id=entity_id,
            operation=operation,
            data=data,
            client_timestamp=client_timestamp,
            is_resolved=result['success']
        )

        return result

    def _sync_expense(self, user, operation, entity_id, local_id, data, client_timestamp, result):
        """Sync an expense."""
        if operation == 'create':
            # Check user has access to group
            group = Group.objects.filter(id=data.get('group'), members=user).first()
            if not group:
                result['error'] = 'Group not found or access denied'
                return result

            # Create expense
            expense = Expense.objects.create(
                group=group,
                description=data.get('description', ''),
                amount=data.get('amount'),
                currency=data.get('currency', 'INR'),
                paid_by_id=data.get('paid_by'),
                split_type=data.get('split_type', 'equal'),
                expense_date=data.get('expense_date', timezone.now().date()),
                notes=data.get('notes', ''),
                created_by=user,
                local_id=local_id,
                last_synced_at=timezone.now()
            )

            # Create splits
            splits = data.get('splits', [])
            for split in splits:
                ExpenseSplit.objects.create(
                    expense=expense,
                    user_id=split.get('user_id'),
                    amount=split.get('amount'),
                    percentage=split.get('percentage'),
                    shares=split.get('shares', 1)
                )

            result['success'] = True
            result['server_id'] = str(expense.id)
            result['data'] = ExpenseSerializer(expense).data

        elif operation == 'update':
            try:
                expense = Expense.objects.get(id=entity_id)

                # Check for conflicts
                if expense.updated_at > client_timestamp:
                    result['conflict'] = True
                    result['server_data'] = ExpenseSerializer(expense).data
                    result['error'] = 'Server version is newer'
                    return result

                # Check permission
                if expense.created_by != user and expense.group.owner != user:
                    result['error'] = 'Permission denied'
                    return result

                # Update expense
                for field in ['description', 'amount', 'currency', 'split_type', 'expense_date', 'notes']:
                    if field in data:
                        setattr(expense, field, data[field])

                expense.sync_version += 1
                expense.last_synced_at = timezone.now()
                expense.save()

                # Update splits if provided
                if 'splits' in data:
                    expense.splits.all().delete()
                    for split in data['splits']:
                        ExpenseSplit.objects.create(
                            expense=expense,
                            user_id=split.get('user_id'),
                            amount=split.get('amount'),
                            percentage=split.get('percentage'),
                            shares=split.get('shares', 1)
                        )

                result['success'] = True
                result['data'] = ExpenseSerializer(expense).data

            except Expense.DoesNotExist:
                result['error'] = 'Expense not found'

        elif operation == 'delete':
            try:
                expense = Expense.objects.get(id=entity_id)

                # Check permission
                if expense.created_by != user and expense.group.owner != user:
                    result['error'] = 'Permission denied'
                    return result

                expense.is_deleted = True
                expense.save(update_fields=['is_deleted', 'updated_at'])
                result['success'] = True

            except Expense.DoesNotExist:
                result['error'] = 'Expense not found'

        return result

    def _sync_group(self, user, operation, entity_id, local_id, data, client_timestamp, result):
        """Sync a group."""
        if operation == 'create':
            group = Group.objects.create(
                name=data.get('name'),
                description=data.get('description', ''),
                currency=data.get('currency', 'INR'),
                owner=user
            )

            # Add owner as member
            from api.models import GroupMembership
            GroupMembership.objects.create(user=user, group=group, role='owner')

            result['success'] = True
            result['server_id'] = str(group.id)
            result['data'] = GroupSerializer(group).data

        elif operation == 'update':
            try:
                group = Group.objects.get(id=entity_id, owner=user)

                if group.updated_at > client_timestamp:
                    result['conflict'] = True
                    result['server_data'] = GroupSerializer(group).data
                    result['error'] = 'Server version is newer'
                    return result

                for field in ['name', 'description', 'currency']:
                    if field in data:
                        setattr(group, field, data[field])
                group.save()

                result['success'] = True
                result['data'] = GroupSerializer(group).data

            except Group.DoesNotExist:
                result['error'] = 'Group not found or permission denied'

        return result

    def _sync_settlement(self, user, operation, entity_id, local_id, data, client_timestamp, result):
        """Sync a settlement."""
        if operation == 'create':
            group = Group.objects.filter(id=data.get('group'), members=user).first()
            if not group:
                result['error'] = 'Group not found or access denied'
                return result

            settlement = Settlement.objects.create(
                group=group,
                from_user_id=data.get('from_user'),
                to_user_id=data.get('to_user'),
                amount=data.get('amount'),
                notes=data.get('notes', ''),
                created_by=user
            )

            result['success'] = True
            result['server_id'] = str(settlement.id)
            result['data'] = SettlementSerializer(settlement).data

        return result


class SyncPullView(APIView):
    """
    Pull changes from the server.
    """

    def get(self, request):
        """
        Pull changes since last sync.

        Query params:
        - last_sync: ISO timestamp of last sync
        - group_ids: comma-separated list of group IDs (optional)
        """
        last_sync_str = request.query_params.get('last_sync')
        group_ids_str = request.query_params.get('group_ids')

        last_sync = None
        if last_sync_str:
            try:
                last_sync = datetime.fromisoformat(last_sync_str.replace('Z', '+00:00'))
            except ValueError:
                return Response(
                    {'error': 'Invalid last_sync timestamp'},
                    status=status.HTTP_400_BAD_REQUEST
                )

        # Get user's groups
        user_groups = Group.objects.filter(members=request.user)
        if group_ids_str:
            group_ids = group_ids_str.split(',')
            user_groups = user_groups.filter(id__in=group_ids)

        # Fetch changes
        changes = {
            'groups': [],
            'expenses': [],
            'settlements': [],
            'server_timestamp': timezone.now().isoformat()
        }

        # Groups
        groups_query = user_groups
        if last_sync:
            groups_query = groups_query.filter(updated_at__gt=last_sync)
        changes['groups'] = GroupSerializer(groups_query, many=True).data

        # Expenses
        expenses_query = Expense.objects.filter(group__in=user_groups)
        if last_sync:
            expenses_query = expenses_query.filter(updated_at__gt=last_sync)
        changes['expenses'] = ExpenseSerializer(expenses_query, many=True).data

        # Settlements
        settlements_query = Settlement.objects.filter(group__in=user_groups)
        if last_sync:
            settlements_query = settlements_query.filter(settled_at__gt=last_sync)
        changes['settlements'] = SettlementSerializer(settlements_query, many=True).data

        return Response(changes)
