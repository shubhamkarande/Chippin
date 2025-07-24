import 'package:flutter/foundation.dart';
import '../models/group.dart';
import '../models/member.dart';
import '../models/expense.dart';

class SimpleProvider with ChangeNotifier {
  List<Group> _groups = [];
  List<Member> _members = [];
  Group? _selectedGroup;
  List<Expense> _selectedGroupExpenses = [];

  List<Group> get groups => _groups;
  List<Member> get members => _members;
  Group? get selectedGroup => _selectedGroup;
  List<Expense> get selectedGroupExpenses => _selectedGroupExpenses;

  void loadGroups() {
    // Mock data for demo
    _groups = [
      Group(
        id: '1',
        name: 'Goa Trip',
        description: 'Beach vacation with friends',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        createdBy: 'user1',
        memberIds: ['member1', 'member2', 'member3'],
        inviteCode: 'GOA2024',
      ),
      Group(
        id: '2',
        name: 'Roommates',
        description: 'Monthly expenses',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        createdBy: 'user1',
        memberIds: ['member1', 'member4'],
        inviteCode: 'ROOM123',
      ),
    ];

    _members = [
      Member(
        id: 'member1',
        name: 'John Doe',
        email: 'john@example.com',
        joinedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Member(
        id: 'member2',
        name: 'Jane Smith',
        email: 'jane@example.com',
        joinedAt: DateTime.now().subtract(const Duration(days: 25)),
      ),
      Member(
        id: 'member3',
        name: 'Bob Wilson',
        email: 'bob@example.com',
        joinedAt: DateTime.now().subtract(const Duration(days: 20)),
      ),
      Member(
        id: 'member4',
        name: 'Alice Brown',
        email: 'alice@example.com',
        joinedAt: DateTime.now().subtract(const Duration(days: 15)),
      ),
    ];

    notifyListeners();
  }

  void createGroup(Group group) {
    _groups.add(group);
    notifyListeners();
  }

  void addMember(Member member) {
    _members.add(member);
    notifyListeners();
  }

  void selectGroup(String groupId) {
    _selectedGroup = _groups.firstWhere((g) => g.id == groupId);

    // Mock expenses for demo
    _selectedGroupExpenses = [
      Expense(
        id: 'exp1',
        groupId: groupId,
        description: 'Dinner at Beach Shack',
        amount: 2500.0,
        paidBy: 'member1',
        splits: [
          ExpenseSplit(memberId: 'member1', amount: 833.33),
          ExpenseSplit(memberId: 'member2', amount: 833.33),
          ExpenseSplit(memberId: 'member3', amount: 833.34),
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        merchantName: 'Sunset Beach Shack',
      ),
      Expense(
        id: 'exp2',
        groupId: groupId,
        description: 'Hotel Booking',
        amount: 8000.0,
        paidBy: 'member2',
        splits: [
          ExpenseSplit(memberId: 'member1', amount: 2666.67),
          ExpenseSplit(memberId: 'member2', amount: 2666.67),
          ExpenseSplit(memberId: 'member3', amount: 2666.66),
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        merchantName: 'Ocean View Resort',
      ),
    ];

    notifyListeners();
  }

  void addExpense(Expense expense) {
    _selectedGroupExpenses.add(expense);
    notifyListeners();
  }

  double getGroupTotal(String groupId) {
    return _selectedGroupExpenses
        .where((expense) => expense.groupId == groupId)
        .fold(0.0, (sum, expense) => sum + expense.amount);
  }

  Map<String, double> getMemberBalances(String groupId) {
    Map<String, double> balances = {};

    for (var expense in _selectedGroupExpenses) {
      // Person who paid gets positive balance
      balances[expense.paidBy] =
          (balances[expense.paidBy] ?? 0) + expense.amount;

      // People who owe get negative balance
      for (var split in expense.splits) {
        balances[split.memberId] =
            (balances[split.memberId] ?? 0) - split.amount;
      }
    }

    return balances;
  }
}
