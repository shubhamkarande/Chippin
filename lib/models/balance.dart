/// Balance model for user balances within a group.
class Balance {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final double paid;
  final double owes;
  final double balance; // Positive = owed money, Negative = owes money

  Balance({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.paid,
    required this.owes,
    required this.balance,
  });

  factory Balance.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return Balance(
      userId: user?['id'] ?? json['user_id'] ?? '',
      displayName: user?['display_name'] ?? json['display_name'] ?? '',
      avatarUrl: user?['avatar_url'],
      paid: (json['paid'] as num?)?.toDouble() ?? 0.0,
      owes: (json['owes'] as num?)?.toDouble() ?? 0.0,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  bool get isOwed => balance > 0.01;
  bool get owesOthers => balance < -0.01;
  bool get isSettled => balance.abs() < 0.01;

  String get formattedBalance {
    final absBalance = balance.abs();
    if (isSettled) return 'Settled up';
    if (isOwed) return 'gets back ₹${absBalance.toStringAsFixed(2)}';
    return 'owes ₹${absBalance.toStringAsFixed(2)}';
  }
}

/// Simplified debt transaction.
class SimplifiedDebt {
  final String fromUserId;
  final String fromUserName;
  final String? fromUserAvatar;
  final String toUserId;
  final String toUserName;
  final String? toUserAvatar;
  final double amount;

  SimplifiedDebt({
    required this.fromUserId,
    required this.fromUserName,
    this.fromUserAvatar,
    required this.toUserId,
    required this.toUserName,
    this.toUserAvatar,
    required this.amount,
  });

  factory SimplifiedDebt.fromJson(Map<String, dynamic> json) {
    final fromUser = json['from_user'] as Map<String, dynamic>?;
    final toUser = json['to_user'] as Map<String, dynamic>?;
    return SimplifiedDebt(
      fromUserId: fromUser?['id'] ?? json['from_user_id'] ?? '',
      fromUserName: fromUser?['display_name'] ?? '',
      fromUserAvatar: fromUser?['avatar_url'],
      toUserId: toUser?['id'] ?? json['to_user_id'] ?? '',
      toUserName: toUser?['display_name'] ?? '',
      toUserAvatar: toUser?['avatar_url'],
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  String get description => '$fromUserName owes $toUserName ₹${amount.toStringAsFixed(2)}';
}

/// Settlement model.
class Settlement {
  final String id;
  final String groupId;
  final String fromUserId;
  final String? fromUserName;
  final String toUserId;
  final String? toUserName;
  final double amount;
  final String notes;
  final DateTime settledAt;
  final String createdById;

  Settlement({
    required this.id,
    required this.groupId,
    required this.fromUserId,
    this.fromUserName,
    required this.toUserId,
    this.toUserName,
    required this.amount,
    this.notes = '',
    required this.settledAt,
    required this.createdById,
  });

  factory Settlement.fromJson(Map<String, dynamic> json) {
    return Settlement(
      id: json['id'] ?? '',
      groupId: json['group'] ?? json['group_id'] ?? '',
      fromUserId: json['from_user'] ?? json['from_user_id'] ?? '',
      fromUserName: json['from_user_details']?['display_name'],
      toUserId: json['to_user'] ?? json['to_user_id'] ?? '',
      toUserName: json['to_user_details']?['display_name'],
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] ?? '',
      settledAt: json['settled_at'] != null
          ? DateTime.parse(json['settled_at'])
          : DateTime.now(),
      createdById: json['created_by'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group': groupId,
      'from_user': fromUserId,
      'to_user': toUserId,
      'amount': amount,
      'notes': notes,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'amount': amount,
      'notes': notes,
      'settled_at': settledAt.toIso8601String(),
      'created_by': createdById,
    };
  }

  factory Settlement.fromMap(Map<String, dynamic> map) {
    return Settlement(
      id: map['id'],
      groupId: map['group_id'],
      fromUserId: map['from_user_id'],
      toUserId: map['to_user_id'],
      amount: map['amount']?.toDouble() ?? 0.0,
      notes: map['notes'] ?? '',
      settledAt: DateTime.parse(map['settled_at']),
      createdById: map['created_by'],
    );
  }
}
