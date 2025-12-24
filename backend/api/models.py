"""
Database models for Chippin API.
"""
import uuid
from django.db import models
from django.contrib.auth.models import AbstractUser


class User(AbstractUser):
    """Extended user model with Firebase integration."""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    firebase_uid = models.CharField(max_length=128, unique=True, null=True, blank=True)
    display_name = models.CharField(max_length=255, blank=True)
    avatar_url = models.URLField(blank=True, null=True)
    is_guest = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'users'

    def __str__(self):
        return self.display_name or self.email or str(self.id)


class Group(models.Model):
    """Expense sharing group."""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    owner = models.ForeignKey(User, on_delete=models.CASCADE, related_name='owned_groups')
    members = models.ManyToManyField(User, through='GroupMembership', related_name='member_groups')
    invite_code = models.CharField(max_length=20, unique=True)
    currency = models.CharField(max_length=3, default='INR')
    image_url = models.URLField(blank=True, null=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'groups'
        ordering = ['-created_at']

    def __str__(self):
        return self.name

    def save(self, *args, **kwargs):
        if not self.invite_code:
            self.invite_code = self._generate_invite_code()
        super().save(*args, **kwargs)

    def _generate_invite_code(self):
        """Generate a unique invite code."""
        import random
        import string
        code = ''.join(random.choices(string.ascii_uppercase + string.digits, k=8))
        while Group.objects.filter(invite_code=code).exists():
            code = ''.join(random.choices(string.ascii_uppercase + string.digits, k=8))
        return code


class GroupMembership(models.Model):
    """Group membership with role."""
    ROLE_CHOICES = [
        ('owner', 'Owner'),
        ('admin', 'Admin'),
        ('member', 'Member'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    group = models.ForeignKey(Group, on_delete=models.CASCADE)
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='member')
    joined_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'group_memberships'
        unique_together = ['user', 'group']

    def __str__(self):
        return f"{self.user} in {self.group}"


class Category(models.Model):
    """Expense category."""
    PRESET_CATEGORIES = [
        ('food', 'Food & Dining', '🍔'),
        ('transport', 'Transport', '🚗'),
        ('entertainment', 'Entertainment', '🎬'),
        ('shopping', 'Shopping', '🛍️'),
        ('utilities', 'Utilities', '💡'),
        ('rent', 'Rent', '🏠'),
        ('travel', 'Travel', '✈️'),
        ('healthcare', 'Healthcare', '🏥'),
        ('other', 'Other', '📦'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=100)
    icon = models.CharField(max_length=10, default='📦')
    color = models.CharField(max_length=7, default='#6366F1')
    is_preset = models.BooleanField(default=False)
    group = models.ForeignKey(Group, on_delete=models.CASCADE, null=True, blank=True, related_name='custom_categories')

    class Meta:
        db_table = 'categories'

    def __str__(self):
        return f"{self.icon} {self.name}"


class Expense(models.Model):
    """Expense record."""
    SPLIT_TYPE_CHOICES = [
        ('equal', 'Equal Split'),
        ('percentage', 'Percentage Split'),
        ('exact', 'Exact Amounts'),
        ('shares', 'By Shares'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    group = models.ForeignKey(Group, on_delete=models.CASCADE, related_name='expenses')
    description = models.CharField(max_length=500)
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    currency = models.CharField(max_length=3, default='INR')
    category = models.ForeignKey(Category, on_delete=models.SET_NULL, null=True, blank=True)
    paid_by = models.ForeignKey(User, on_delete=models.CASCADE, related_name='paid_expenses')
    split_type = models.CharField(max_length=20, choices=SPLIT_TYPE_CHOICES, default='equal')
    receipt_url = models.URLField(blank=True, null=True)
    notes = models.TextField(blank=True)
    expense_date = models.DateField()
    is_settled = models.BooleanField(default=False)
    is_deleted = models.BooleanField(default=False)
    created_by = models.ForeignKey(User, on_delete=models.CASCADE, related_name='created_expenses')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    # Sync metadata
    local_id = models.CharField(max_length=100, blank=True, null=True)
    sync_version = models.IntegerField(default=1)
    last_synced_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = 'expenses'
        ordering = ['-expense_date', '-created_at']

    def __str__(self):
        return f"{self.description} - {self.amount}"


class ExpenseSplit(models.Model):
    """Individual split for an expense."""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    expense = models.ForeignKey(Expense, on_delete=models.CASCADE, related_name='splits')
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='expense_splits')
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    percentage = models.DecimalField(max_digits=5, decimal_places=2, null=True, blank=True)
    shares = models.IntegerField(default=1)
    is_settled = models.BooleanField(default=False)
    settled_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = 'expense_splits'
        unique_together = ['expense', 'user']

    def __str__(self):
        return f"{self.user} owes {self.amount}"


class Settlement(models.Model):
    """Settlement between two users."""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    group = models.ForeignKey(Group, on_delete=models.CASCADE, related_name='settlements')
    from_user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='settlements_made')
    to_user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='settlements_received')
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    notes = models.TextField(blank=True)
    settled_at = models.DateTimeField(auto_now_add=True)
    created_by = models.ForeignKey(User, on_delete=models.CASCADE, related_name='created_settlements')

    class Meta:
        db_table = 'settlements'
        ordering = ['-settled_at']

    def __str__(self):
        return f"{self.from_user} paid {self.to_user} {self.amount}"


class SyncLog(models.Model):
    """Sync operation log for conflict resolution."""
    OPERATION_CHOICES = [
        ('create', 'Create'),
        ('update', 'Update'),
        ('delete', 'Delete'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    entity_type = models.CharField(max_length=50)  # 'expense', 'group', etc.
    entity_id = models.UUIDField()
    operation = models.CharField(max_length=20, choices=OPERATION_CHOICES)
    data = models.JSONField(default=dict)
    client_timestamp = models.DateTimeField()
    server_timestamp = models.DateTimeField(auto_now_add=True)
    is_resolved = models.BooleanField(default=True)

    class Meta:
        db_table = 'sync_logs'
        ordering = ['-server_timestamp']

    def __str__(self):
        return f"{self.operation} {self.entity_type} {self.entity_id}"
