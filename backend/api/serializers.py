"""
Serializers for Chippin API.
"""
from rest_framework import serializers
from decimal import Decimal
from .models import User, Group, GroupMembership, Category, Expense, ExpenseSplit, Settlement, SyncLog


class UserSerializer(serializers.ModelSerializer):
    """User serializer."""

    class Meta:
        model = User
        fields = ['id', 'firebase_uid', 'email', 'display_name', 'avatar_url', 'is_guest', 'created_at']
        read_only_fields = ['id', 'firebase_uid', 'created_at']


class UserMinimalSerializer(serializers.ModelSerializer):
    """Minimal user info for nested representations."""

    class Meta:
        model = User
        fields = ['id', 'display_name', 'avatar_url']


class GroupMembershipSerializer(serializers.ModelSerializer):
    """Group membership serializer."""
    user = UserMinimalSerializer(read_only=True)

    class Meta:
        model = GroupMembership
        fields = ['id', 'user', 'role', 'joined_at']


class CategorySerializer(serializers.ModelSerializer):
    """Category serializer."""

    class Meta:
        model = Category
        fields = ['id', 'name', 'icon', 'color', 'is_preset']


class ExpenseSplitSerializer(serializers.ModelSerializer):
    """Expense split serializer."""
    user = UserMinimalSerializer(read_only=True)
    user_id = serializers.UUIDField(write_only=True)

    class Meta:
        model = ExpenseSplit
        fields = ['id', 'user', 'user_id', 'amount', 'percentage', 'shares', 'is_settled']
        read_only_fields = ['id']


class ExpenseSerializer(serializers.ModelSerializer):
    """Expense serializer."""
    paid_by_user = UserMinimalSerializer(source='paid_by', read_only=True)
    created_by_user = UserMinimalSerializer(source='created_by', read_only=True)
    category_details = CategorySerializer(source='category', read_only=True)
    splits = ExpenseSplitSerializer(many=True, read_only=True)
    split_data = serializers.ListField(child=serializers.DictField(), write_only=True, required=False)

    class Meta:
        model = Expense
        fields = [
            'id', 'group', 'description', 'amount', 'currency', 'category', 'category_details',
            'paid_by', 'paid_by_user', 'split_type', 'receipt_url', 'notes', 'expense_date',
            'is_settled', 'is_deleted', 'created_by', 'created_by_user', 'created_at', 'updated_at',
            'splits', 'split_data', 'local_id', 'sync_version'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'created_by']

    def validate_amount(self, value):
        """Ensure amount is positive."""
        if value <= 0:
            raise serializers.ValidationError("Amount must be greater than zero.")
        return value

    def validate(self, data):
        """Validate split amounts match total."""
        split_data = data.get('split_data', [])
        if split_data:
            total_split = sum(Decimal(str(s.get('amount', 0))) for s in split_data)
            if abs(total_split - data['amount']) > Decimal('0.01'):
                raise serializers.ValidationError({
                    'split_data': f"Split amounts ({total_split}) must equal expense amount ({data['amount']})"
                })
        return data

    def create(self, validated_data):
        """Create expense with splits."""
        split_data = validated_data.pop('split_data', [])
        validated_data['created_by'] = self.context['request'].user

        expense = Expense.objects.create(**validated_data)

        # Create splits
        if split_data:
            for split in split_data:
                ExpenseSplit.objects.create(
                    expense=expense,
                    user_id=split['user_id'],
                    amount=split['amount'],
                    percentage=split.get('percentage'),
                    shares=split.get('shares', 1)
                )
        else:
            # Create equal splits for all group members
            self._create_equal_splits(expense)

        return expense

    def _create_equal_splits(self, expense):
        """Create equal splits for all group members."""
        members = expense.group.members.all()
        if not members:
            return

        per_person = expense.amount / len(members)
        # Handle rounding - give extra cents to first person
        remainder = expense.amount - (per_person * len(members))

        for i, member in enumerate(members):
            amount = per_person
            if i == 0:
                amount += remainder
            ExpenseSplit.objects.create(
                expense=expense,
                user=member,
                amount=amount
            )


class ExpenseListSerializer(serializers.ModelSerializer):
    """Lightweight expense serializer for list views."""
    paid_by_name = serializers.CharField(source='paid_by.display_name', read_only=True)
    category_icon = serializers.CharField(source='category.icon', read_only=True, default='📦')

    class Meta:
        model = Expense
        fields = [
            'id', 'description', 'amount', 'currency', 'paid_by', 'paid_by_name',
            'category_icon', 'expense_date', 'is_settled', 'created_at'
        ]


class GroupSerializer(serializers.ModelSerializer):
    """Group serializer."""
    owner_details = UserMinimalSerializer(source='owner', read_only=True)
    memberships = GroupMembershipSerializer(source='groupmembership_set', many=True, read_only=True)
    member_count = serializers.SerializerMethodField()
    total_expenses = serializers.SerializerMethodField()

    class Meta:
        model = Group
        fields = [
            'id', 'name', 'description', 'owner', 'owner_details', 'invite_code',
            'currency', 'image_url', 'is_active', 'created_at', 'updated_at',
            'memberships', 'member_count', 'total_expenses'
        ]
        read_only_fields = ['id', 'owner', 'invite_code', 'created_at', 'updated_at']

    def get_member_count(self, obj):
        return obj.members.count()

    def get_total_expenses(self, obj):
        from django.db.models import Sum
        result = obj.expenses.filter(is_deleted=False).aggregate(Sum('amount'))
        return float(result['amount__sum'] or 0)


class GroupListSerializer(serializers.ModelSerializer):
    """Lightweight group serializer for list views."""
    member_count = serializers.SerializerMethodField()

    class Meta:
        model = Group
        fields = ['id', 'name', 'currency', 'image_url', 'member_count', 'updated_at']

    def get_member_count(self, obj):
        return obj.members.count()


class GroupCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating a group."""

    class Meta:
        model = Group
        fields = ['name', 'description', 'currency', 'image_url']

    def create(self, validated_data):
        """Create group and add owner as member."""
        user = self.context['request'].user
        validated_data['owner'] = user
        group = Group.objects.create(**validated_data)

        # Add owner as member with owner role
        GroupMembership.objects.create(
            user=user,
            group=group,
            role='owner'
        )

        return group


class JoinGroupSerializer(serializers.Serializer):
    """Serializer for joining a group."""
    invite_code = serializers.CharField(max_length=20)

    def validate_invite_code(self, value):
        """Check if invite code is valid."""
        try:
            group = Group.objects.get(invite_code=value, is_active=True)
            self.group = group
            return value
        except Group.DoesNotExist:
            raise serializers.ValidationError("Invalid invite code.")

    def create(self, validated_data):
        """Add user to group."""
        user = self.context['request'].user
        
        # Check if already a member
        if GroupMembership.objects.filter(user=user, group=self.group).exists():
            raise serializers.ValidationError({"invite_code": "Already a member of this group."})

        GroupMembership.objects.create(
            user=user,
            group=self.group,
            role='member'
        )

        return self.group


class SettlementSerializer(serializers.ModelSerializer):
    """Settlement serializer."""
    from_user_details = UserMinimalSerializer(source='from_user', read_only=True)
    to_user_details = UserMinimalSerializer(source='to_user', read_only=True)

    class Meta:
        model = Settlement
        fields = [
            'id', 'group', 'from_user', 'from_user_details', 'to_user', 'to_user_details',
            'amount', 'notes', 'settled_at', 'created_by'
        ]
        read_only_fields = ['id', 'settled_at', 'created_by']


class BalanceSerializer(serializers.Serializer):
    """Serializer for balance summary."""
    user = UserMinimalSerializer()
    balance = serializers.DecimalField(max_digits=12, decimal_places=2)
    owes = serializers.ListField(child=serializers.DictField())
    owed_by = serializers.ListField(child=serializers.DictField())


class SyncPushSerializer(serializers.Serializer):
    """Serializer for sync push operation."""
    entity_type = serializers.ChoiceField(choices=['expense', 'group', 'settlement'])
    operation = serializers.ChoiceField(choices=['create', 'update', 'delete'])
    entity_id = serializers.CharField()
    local_id = serializers.CharField(required=False)
    data = serializers.DictField()
    client_timestamp = serializers.DateTimeField()


class SyncPullSerializer(serializers.Serializer):
    """Serializer for sync pull request."""
    last_sync = serializers.DateTimeField(required=False, allow_null=True)
    group_ids = serializers.ListField(child=serializers.UUIDField(), required=False)
