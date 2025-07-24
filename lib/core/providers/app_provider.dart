import 'package:flutter/foundation.dart';
import '../models/group.dart';
import '../models/member.dart';
import '../models/expense.dart';
import '../database/database_helper.dart';

class AppProvider with ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();

  List<Group> _groups = [];
  List<Member> _members = [];
  Group? _selectedGroup;
  List<Expense> _selectedGroupExpenses = [];

  List<Group> get groups => _groups;
  List<Member> get members => _members;
  Group? get selectedGroup => _selectedGroup;
  List<Expense> get selectedGroupExpenses => _selectedGroupExpenses;

  Future<void> loadGroups() async {
    _groups = await _db.getGroups();
    notifyListeners();
  }

  Future<void> loadMembers() async {
    _members = await _db.getMembers();
    notifyListeners();
  }

  Future<void> createGroup(Group group) async {
    await _db.insertGroup(group);
    await loadGroups();
  }

  Future<void> addMember(Member member) async {
    await _db.insertMember(member);
    await loadMembers();
  }

  Future<void> selectGroup(String groupId) async {
    _selectedGroup = await _db.getGroup(groupId);
    if (_selectedGroup != null) {
      _selectedGroupExpenses = await _db.getGroupExpenses(groupId);
    }
    notifyListeners();
  }

  Future<void> addExpense(Expense expense) async {
    await _db.insertExpense(expense);
    if (_selectedGroup?.id == expense.groupId) {
      _selectedGroupExpenses = await _db.getGroupExpenses(expense.groupId);
      notifyListeners();
    }
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
