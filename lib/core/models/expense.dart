class Expense {
  final String id;
  final String groupId;
  final String description;
  final double amount;
  final String paidBy;
  final List<ExpenseSplit> splits;
  final DateTime createdAt;
  final String? receiptImagePath;
  final String? merchantName;

  Expense({
    required this.id,
    required this.groupId,
    required this.description,
    required this.amount,
    required this.paidBy,
    required this.splits,
    required this.createdAt,
    this.receiptImagePath,
    this.merchantName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'description': description,
      'amount': amount,
      'paidBy': paidBy,
      'splits': splits.map((s) => s.toMap()).toList(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'receiptImagePath': receiptImagePath,
      'merchantName': merchantName,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      groupId: map['groupId'],
      description: map['description'],
      amount: map['amount'].toDouble(),
      paidBy: map['paidBy'],
      splits: (map['splits'] as List)
          .map((s) => ExpenseSplit.fromMap(s))
          .toList(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      receiptImagePath: map['receiptImagePath'],
      merchantName: map['merchantName'],
    );
  }
}

class ExpenseSplit {
  final String memberId;
  final double amount;
  final bool isPaid;

  ExpenseSplit({
    required this.memberId,
    required this.amount,
    this.isPaid = false,
  });

  Map<String, dynamic> toMap() {
    return {'memberId': memberId, 'amount': amount, 'isPaid': isPaid};
  }

  factory ExpenseSplit.fromMap(Map<String, dynamic> map) {
    return ExpenseSplit(
      memberId: map['memberId'],
      amount: map['amount'].toDouble(),
      isPaid: map['isPaid'] ?? false,
    );
  }
}
