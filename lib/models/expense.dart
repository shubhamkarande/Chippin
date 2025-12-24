import 'user.dart';

/// Split type for expense division.
enum SplitType {
  equal,
  percentage,
  exact,
  shares;

  String get displayName {
    switch (this) {
      case SplitType.equal:
        return 'Equal Split';
      case SplitType.percentage:
        return 'By Percentage';
      case SplitType.exact:
        return 'Exact Amounts';
      case SplitType.shares:
        return 'By Shares';
    }
  }

  static SplitType fromString(String? value) {
    switch (value) {
      case 'percentage':
        return SplitType.percentage;
      case 'exact':
        return SplitType.exact;
      case 'shares':
        return SplitType.shares;
      default:
        return SplitType.equal;
    }
  }
}

/// Expense model.
class Expense {
  final String id;
  final String groupId;
  final String description;
  final double amount;
  final String currency;
  final String? categoryId;
  final ExpenseCategory? category;
  final String paidById;
  final User? paidBy;
  final SplitType splitType;
  final List<ExpenseSplit> splits;
  final String? receiptUrl;
  final String notes;
  final DateTime expenseDate;
  final bool isSettled;
  final bool isDeleted;
  final String createdById;
  final User? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? localId;
  final int syncVersion;
  final bool synced;

  Expense({
    required this.id,
    required this.groupId,
    required this.description,
    required this.amount,
    this.currency = 'INR',
    this.categoryId,
    this.category,
    required this.paidById,
    this.paidBy,
    this.splitType = SplitType.equal,
    this.splits = const [],
    this.receiptUrl,
    this.notes = '',
    required this.expenseDate,
    this.isSettled = false,
    this.isDeleted = false,
    required this.createdById,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.localId,
    this.syncVersion = 1,
    this.synced = false,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] ?? '',
      groupId: json['group'] ?? json['group_id'] ?? '',
      description: json['description'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'INR',
      categoryId: json['category'],
      category: json['category_details'] != null
          ? ExpenseCategory.fromJson(json['category_details'])
          : null,
      paidById: json['paid_by'] ?? json['paid_by_id'] ?? '',
      paidBy: json['paid_by_user'] != null
          ? User.fromJson(json['paid_by_user'])
          : null,
      splitType: SplitType.fromString(json['split_type']),
      splits: (json['splits'] as List<dynamic>?)
              ?.map((s) => ExpenseSplit.fromJson(s))
              .toList() ??
          [],
      receiptUrl: json['receipt_url'],
      notes: json['notes'] ?? '',
      expenseDate: json['expense_date'] != null
          ? DateTime.parse(json['expense_date'])
          : DateTime.now(),
      isSettled: json['is_settled'] ?? false,
      isDeleted: json['is_deleted'] ?? false,
      createdById: json['created_by'] ?? json['created_by_id'] ?? '',
      createdBy: json['created_by_user'] != null
          ? User.fromJson(json['created_by_user'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      localId: json['local_id'],
      syncVersion: json['sync_version'] ?? 1,
      synced: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group': groupId,
      'description': description,
      'amount': amount,
      'currency': currency,
      'category': categoryId,
      'paid_by': paidById,
      'split_type': splitType.name,
      'splits': splits.map((s) => s.toJson()).toList(),
      'receipt_url': receiptUrl,
      'notes': notes,
      'expense_date': expenseDate.toIso8601String().split('T')[0],
      'is_settled': isSettled,
      'is_deleted': isDeleted,
      'local_id': localId,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'description': description,
      'amount': amount,
      'currency': currency,
      'category_id': categoryId,
      'paid_by': paidById,
      'split_type': splitType.name,
      'receipt_url': receiptUrl,
      'notes': notes,
      'expense_date': expenseDate.toIso8601String(),
      'is_settled': isSettled ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
      'created_by': createdById,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'local_id': localId,
      'sync_version': syncVersion,
      'synced': synced ? 1 : 0,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      groupId: map['group_id'],
      description: map['description'] ?? '',
      amount: map['amount']?.toDouble() ?? 0.0,
      currency: map['currency'] ?? 'INR',
      categoryId: map['category_id'],
      paidById: map['paid_by'],
      splitType: SplitType.fromString(map['split_type']),
      receiptUrl: map['receipt_url'],
      notes: map['notes'] ?? '',
      expenseDate: DateTime.parse(map['expense_date']),
      isSettled: map['is_settled'] == 1,
      isDeleted: map['is_deleted'] == 1,
      createdById: map['created_by'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      localId: map['local_id'],
      syncVersion: map['sync_version'] ?? 1,
      synced: map['synced'] == 1,
    );
  }

  Expense copyWith({
    String? id,
    String? groupId,
    String? description,
    double? amount,
    String? currency,
    String? categoryId,
    ExpenseCategory? category,
    String? paidById,
    User? paidBy,
    SplitType? splitType,
    List<ExpenseSplit>? splits,
    String? receiptUrl,
    String? notes,
    DateTime? expenseDate,
    bool? isSettled,
    bool? isDeleted,
    String? createdById,
    User? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? localId,
    int? syncVersion,
    bool? synced,
  }) {
    return Expense(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      categoryId: categoryId ?? this.categoryId,
      category: category ?? this.category,
      paidById: paidById ?? this.paidById,
      paidBy: paidBy ?? this.paidBy,
      splitType: splitType ?? this.splitType,
      splits: splits ?? this.splits,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      notes: notes ?? this.notes,
      expenseDate: expenseDate ?? this.expenseDate,
      isSettled: isSettled ?? this.isSettled,
      isDeleted: isDeleted ?? this.isDeleted,
      createdById: createdById ?? this.createdById,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      localId: localId ?? this.localId,
      syncVersion: syncVersion ?? this.syncVersion,
      synced: synced ?? this.synced,
    );
  }
}

/// Individual expense split.
class ExpenseSplit {
  final String id;
  final String expenseId;
  final String userId;
  final User? user;
  final double amount;
  final double? percentage;
  final int shares;
  final bool isSettled;
  final DateTime? settledAt;

  ExpenseSplit({
    required this.id,
    required this.expenseId,
    required this.userId,
    this.user,
    required this.amount,
    this.percentage,
    this.shares = 1,
    this.isSettled = false,
    this.settledAt,
  });

  factory ExpenseSplit.fromJson(Map<String, dynamic> json) {
    return ExpenseSplit(
      id: json['id'] ?? '',
      expenseId: json['expense_id'] ?? '',
      userId: json['user']?['id'] ?? json['user_id'] ?? '',
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      percentage: (json['percentage'] as num?)?.toDouble(),
      shares: json['shares'] ?? 1,
      isSettled: json['is_settled'] ?? false,
      settledAt: json['settled_at'] != null
          ? DateTime.parse(json['settled_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'amount': amount,
      'percentage': percentage,
      'shares': shares,
      'is_settled': isSettled,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'expense_id': expenseId,
      'user_id': userId,
      'amount': amount,
      'percentage': percentage,
      'shares': shares,
      'is_settled': isSettled ? 1 : 0,
      'settled_at': settledAt?.toIso8601String(),
    };
  }

  factory ExpenseSplit.fromMap(Map<String, dynamic> map) {
    return ExpenseSplit(
      id: map['id'],
      expenseId: map['expense_id'],
      userId: map['user_id'],
      amount: map['amount']?.toDouble() ?? 0.0,
      percentage: map['percentage']?.toDouble(),
      shares: map['shares'] ?? 1,
      isSettled: map['is_settled'] == 1,
      settledAt: map['settled_at'] != null
          ? DateTime.parse(map['settled_at'])
          : null,
    );
  }
}

/// Expense category.
class ExpenseCategory {
  final String id;
  final String name;
  final String icon;
  final String color;
  final bool isPreset;

  ExpenseCategory({
    required this.id,
    required this.name,
    required this.icon,
    this.color = '#6366F1',
    this.isPreset = false,
  });

  /// Get color as int value for Color() constructor
  int get colorValue {
    String hex = color.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex'; // Add alpha
    }
    return int.parse(hex, radix: 16);
  }

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) {
    return ExpenseCategory(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      icon: json['icon'] ?? '📦',
      color: json['color'] ?? '#6366F1',
      isPreset: json['is_preset'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
      'is_preset': isPreset,
    };
  }

  static List<ExpenseCategory> get presets => [
        ExpenseCategory(id: 'food', name: 'Food & Dining', icon: '🍔', color: '#FF6B6B', isPreset: true),
        ExpenseCategory(id: 'transport', name: 'Transport', icon: '🚗', color: '#4ECDC4', isPreset: true),
        ExpenseCategory(id: 'entertainment', name: 'Entertainment', icon: '🎬', color: '#FFE66D', isPreset: true),
        ExpenseCategory(id: 'shopping', name: 'Shopping', icon: '🛍️', color: '#FF8C42', isPreset: true),
        ExpenseCategory(id: 'utilities', name: 'Utilities', icon: '💡', color: '#95E1D3', isPreset: true),
        ExpenseCategory(id: 'rent', name: 'Rent', icon: '🏠', color: '#7B68EE', isPreset: true),
        ExpenseCategory(id: 'travel', name: 'Travel', icon: '✈️', color: '#45B7D1', isPreset: true),
        ExpenseCategory(id: 'healthcare', name: 'Healthcare', icon: '🏥', color: '#FF69B4', isPreset: true),
        ExpenseCategory(id: 'other', name: 'Other', icon: '📦', color: '#9CA3AF', isPreset: true),
      ];
}
