from django.contrib import admin
from .models import User, Group, GroupMembership, Category, Expense, ExpenseSplit, Settlement, SyncLog


@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = ['id', 'email', 'display_name', 'firebase_uid', 'is_guest', 'created_at']
    search_fields = ['email', 'display_name', 'firebase_uid']
    list_filter = ['is_guest', 'created_at']


@admin.register(Group)
class GroupAdmin(admin.ModelAdmin):
    list_display = ['id', 'name', 'owner', 'invite_code', 'currency', 'is_active', 'created_at']
    search_fields = ['name', 'invite_code']
    list_filter = ['is_active', 'currency', 'created_at']


@admin.register(GroupMembership)
class GroupMembershipAdmin(admin.ModelAdmin):
    list_display = ['id', 'user', 'group', 'role', 'joined_at']
    list_filter = ['role', 'joined_at']


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ['id', 'name', 'icon', 'color', 'is_preset']
    list_filter = ['is_preset']


@admin.register(Expense)
class ExpenseAdmin(admin.ModelAdmin):
    list_display = ['id', 'description', 'amount', 'group', 'paid_by', 'expense_date', 'is_settled', 'is_deleted']
    search_fields = ['description']
    list_filter = ['is_settled', 'is_deleted', 'split_type', 'expense_date']
    date_hierarchy = 'expense_date'


@admin.register(ExpenseSplit)
class ExpenseSplitAdmin(admin.ModelAdmin):
    list_display = ['id', 'expense', 'user', 'amount', 'is_settled']
    list_filter = ['is_settled']


@admin.register(Settlement)
class SettlementAdmin(admin.ModelAdmin):
    list_display = ['id', 'group', 'from_user', 'to_user', 'amount', 'settled_at']
    list_filter = ['settled_at']
    date_hierarchy = 'settled_at'


@admin.register(SyncLog)
class SyncLogAdmin(admin.ModelAdmin):
    list_display = ['id', 'user', 'entity_type', 'operation', 'is_resolved', 'server_timestamp']
    list_filter = ['entity_type', 'operation', 'is_resolved']
    date_hierarchy = 'server_timestamp'
