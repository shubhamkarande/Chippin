import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../database_helper.dart';
import '../../models/expense.dart';
import '../../models/balance.dart';

/// Repository for Expense CRUD operations in local SQLite database.
class ExpenseRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final _uuid = const Uuid();

  /// Get all expenses for a group
  Future<List<Expense>> getExpenses(String groupId, {bool includeDeleted = false}) async {
    final db = await _dbHelper.database;

    String where = 'group_id = ?';
    if (!includeDeleted) {
      where += ' AND is_deleted = 0';
    }

    final results = await db.query(
      'expenses',
      where: where,
      whereArgs: [groupId],
      orderBy: 'expense_date DESC, created_at DESC',
    );

    final expenses = <Expense>[];
    for (final row in results) {
      final splits = await _getExpenseSplits(row['id'] as String);
      expenses.add(Expense.fromMap(row).copyWith(splits: splits));
    }

    return expenses;
  }

  /// Get single expense by ID
  Future<Expense?> getExpense(String expenseId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'expenses',
      where: 'id = ?',
      whereArgs: [expenseId],
    );

    if (results.isEmpty) return null;

    final splits = await _getExpenseSplits(expenseId);
    return Expense.fromMap(results.first).copyWith(splits: splits);
  }

  /// Create new expense
  Future<Expense> createExpense({
    required String groupId,
    required String description,
    required double amount,
    required String paidById,
    required String createdById,
    String currency = 'INR',
    String? categoryId,
    SplitType splitType = SplitType.equal,
    List<ExpenseSplit>? splits,
    String? receiptUrl,
    String notes = '',
    DateTime? expenseDate,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final expenseId = _uuid.v4();
    final localId = _uuid.v4();

    final expense = Expense(
      id: expenseId,
      groupId: groupId,
      description: description,
      amount: amount,
      currency: currency,
      categoryId: categoryId,
      paidById: paidById,
      splitType: splitType,
      splits: splits ?? [],
      receiptUrl: receiptUrl,
      notes: notes,
      expenseDate: expenseDate ?? now,
      createdById: createdById,
      createdAt: now,
      updatedAt: now,
      localId: localId,
      synced: false,
    );

    await db.insert('expenses', expense.toMap());

    // Create splits
    if (splits != null && splits.isNotEmpty) {
      for (final split in splits) {
        await _createExpenseSplit(expenseId, split);
      }
    }

    // Add pending sync
    await _dbHelper.addPendingSync(
      entityType: 'expense',
      entityId: expenseId,
      operation: 'create',
      data: expense.toJson(),
    );

    return expense.copyWith(splits: await _getExpenseSplits(expenseId));
  }

  /// Create equal splits for all members of a group
  Future<List<ExpenseSplit>> createEqualSplits({
    required String expenseId,
    required double totalAmount,
    required List<String> memberIds,
  }) async {
    final splits = <ExpenseSplit>[];
    final perPerson = totalAmount / memberIds.length;
    final remainder = totalAmount - (perPerson * memberIds.length);

    for (var i = 0; i < memberIds.length; i++) {
      var amount = perPerson;
      if (i == 0) {
        amount += remainder; // Give remainder to first person for clean math
      }

      final split = ExpenseSplit(
        id: _uuid.v4(),
        expenseId: expenseId,
        userId: memberIds[i],
        amount: double.parse(amount.toStringAsFixed(2)),
      );
      
      await _createExpenseSplit(expenseId, split);
      splits.add(split);
    }

    return splits;
  }

  Future<void> _createExpenseSplit(String expenseId, ExpenseSplit split) async {
    final db = await _dbHelper.database;
    await db.insert(
      'expense_splits',
      {
        'id': split.id.isEmpty ? _uuid.v4() : split.id,
        'expense_id': expenseId,
        'user_id': split.userId,
        'amount': split.amount,
        'percentage': split.percentage,
        'shares': split.shares,
        'is_settled': split.isSettled ? 1 : 0,
        'settled_at': split.settledAt?.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ExpenseSplit>> _getExpenseSplits(String expenseId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'expense_splits',
      where: 'expense_id = ?',
      whereArgs: [expenseId],
    );

    return results.map((row) => ExpenseSplit.fromMap(row)).toList();
  }

  /// Update expense
  Future<Expense> updateExpense(Expense expense) async {
    final db = await _dbHelper.database;
    final updatedExpense = expense.copyWith(
      updatedAt: DateTime.now(),
      syncVersion: expense.syncVersion + 1,
      synced: false,
    );

    await db.update(
      'expenses',
      updatedExpense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );

    // Update splits
    await db.delete('expense_splits', where: 'expense_id = ?', whereArgs: [expense.id]);
    for (final split in expense.splits) {
      await _createExpenseSplit(expense.id, split);
    }

    // Add pending sync
    await _dbHelper.addPendingSync(
      entityType: 'expense',
      entityId: expense.id,
      operation: 'update',
      data: updatedExpense.toJson(),
    );

    return updatedExpense;
  }

  /// Delete expense (soft delete)
  Future<void> deleteExpense(String expenseId) async {
    final db = await _dbHelper.database;
    await db.update(
      'expenses',
      {
        'is_deleted': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [expenseId],
    );

    // Add pending sync
    await _dbHelper.addPendingSync(
      entityType: 'expense',
      entityId: expenseId,
      operation: 'delete',
      data: {'id': expenseId},
    );
  }

  /// Mark expense as settled
  Future<void> settleExpense(String expenseId) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();

    await db.update(
      'expenses',
      {
        'is_settled': 1,
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [expenseId],
    );

    await db.update(
      'expense_splits',
      {
        'is_settled': 1,
        'settled_at': now.toIso8601String(),
      },
      where: 'expense_id = ?',
      whereArgs: [expenseId],
    );
  }

  /// Calculate balances for a group
  Future<Map<String, dynamic>> calculateBalances(String groupId) async {
    final db = await _dbHelper.database;

    // Get all unsettled expenses
    final expenses = await getExpenses(groupId);
    final unsettledExpenses = expenses.where((e) => !e.isSettled).toList();

    // Get settlements
    final settlements = await db.query(
      'settlements',
      where: 'group_id = ?',
      whereArgs: [groupId],
    );

    // Calculate what each person has paid and owes
    final Map<String, double> paid = {};
    final Map<String, double> owes = {};

    for (final expense in unsettledExpenses) {
      paid[expense.paidById] = (paid[expense.paidById] ?? 0) + expense.amount;
      for (final split in expense.splits) {
        owes[split.userId] = (owes[split.userId] ?? 0) + split.amount;
      }
    }

    // Apply settlements
    for (final settlement in settlements) {
      final fromUser = settlement['from_user_id'] as String;
      final toUser = settlement['to_user_id'] as String;
      final amount = (settlement['amount'] as num).toDouble();

      paid[fromUser] = (paid[fromUser] ?? 0) + amount;
      owes[fromUser] = (owes[fromUser] ?? 0) - amount;
      paid[toUser] = (paid[toUser] ?? 0) - amount;
      owes[toUser] = (owes[toUser] ?? 0) + amount;
    }

    // Get all unique user IDs
    final allUsers = {...paid.keys, ...owes.keys};

    // Calculate net balance for each user
    final List<Balance> balances = [];
    for (final userId in allUsers) {
      final netPaid = paid[userId] ?? 0;
      final netOwed = owes[userId] ?? 0;
      final balance = netPaid - netOwed;

      // Get user info
      final userResults = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
      );

      final displayName = userResults.isNotEmpty
          ? userResults.first['display_name'] as String? ?? 'Unknown'
          : 'Unknown';

      balances.add(Balance(
        userId: userId,
        displayName: displayName,
        paid: netPaid,
        owes: netOwed,
        balance: balance,
      ));
    }

    // Sort by balance
    balances.sort((a, b) => a.balance.compareTo(b.balance));

    // Calculate simplified debts
    final simplifiedDebts = _simplifyDebts(balances);

    return {
      'balances': balances,
      'simplified_debts': simplifiedDebts,
    };
  }

  List<SimplifiedDebt> _simplifyDebts(List<Balance> balances) {
    final debtors = <Map<String, dynamic>>[];
    final creditors = <Map<String, dynamic>>[];

    for (final b in balances) {
      if (b.balance < -0.01) {
        debtors.add({
          'userId': b.userId,
          'displayName': b.displayName,
          'amount': b.balance.abs(),
        });
      } else if (b.balance > 0.01) {
        creditors.add({
          'userId': b.userId,
          'displayName': b.displayName,
          'amount': b.balance,
        });
      }
    }

    debtors.sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));
    creditors.sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));

    final transactions = <SimplifiedDebt>[];
    var i = 0, j = 0;

    while (i < debtors.length && j < creditors.length) {
      final debtor = debtors[i];
      final creditor = creditors[j];

      final amount = (debtor['amount'] as double) < (creditor['amount'] as double)
          ? debtor['amount'] as double
          : creditor['amount'] as double;

      if (amount > 0.01) {
        transactions.add(SimplifiedDebt(
          fromUserId: debtor['userId'] as String,
          fromUserName: debtor['displayName'] as String,
          toUserId: creditor['userId'] as String,
          toUserName: creditor['displayName'] as String,
          amount: double.parse(amount.toStringAsFixed(2)),
        ));
      }

      debtor['amount'] = (debtor['amount'] as double) - amount;
      creditor['amount'] = (creditor['amount'] as double) - amount;

      if ((debtor['amount'] as double) < 0.01) i++;
      if ((creditor['amount'] as double) < 0.01) j++;
    }

    return transactions;
  }

  /// Get expense summary for a group
  Future<Map<String, dynamic>> getExpenseSummary(String groupId) async {
    final db = await _dbHelper.database;

    final totalResult = await db.rawQuery('''
      SELECT 
        SUM(amount) as total_amount,
        COUNT(*) as total_count
      FROM expenses 
      WHERE group_id = ? AND is_deleted = 0
    ''', [groupId]);

    final categoryResult = await db.rawQuery('''
      SELECT 
        category_id,
        SUM(amount) as total,
        COUNT(*) as count
      FROM expenses 
      WHERE group_id = ? AND is_deleted = 0
      GROUP BY category_id
      ORDER BY total DESC
    ''', [groupId]);

    return {
      'total_amount': totalResult.first['total_amount'] ?? 0.0,
      'total_count': totalResult.first['total_count'] ?? 0,
      'by_category': categoryResult,
    };
  }

  /// Sync expenses from server
  Future<void> syncExpenses(List<Expense> expenses) async {
    final db = await _dbHelper.database;

    for (final expense in expenses) {
      await db.insert(
        'expenses',
        expense.copyWith(synced: true).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Sync splits
      await db.delete(
        'expense_splits',
        where: 'expense_id = ?',
        whereArgs: [expense.id],
      );
      for (final split in expense.splits) {
        await _createExpenseSplit(expense.id, split);
      }
    }
  }

  /// Create settlement
  Future<Settlement> createSettlement({
    required String groupId,
    required String fromUserId,
    required String toUserId,
    required double amount,
    required String createdById,
    String notes = '',
  }) async {
    final db = await _dbHelper.database;
    final settlementId = _uuid.v4();
    final now = DateTime.now();

    final settlement = Settlement(
      id: settlementId,
      groupId: groupId,
      fromUserId: fromUserId,
      toUserId: toUserId,
      amount: amount,
      notes: notes,
      settledAt: now,
      createdById: createdById,
    );

    await db.insert('settlements', {
      ...settlement.toMap(),
      'synced': 0,
    });

    // Add pending sync
    await _dbHelper.addPendingSync(
      entityType: 'settlement',
      entityId: settlementId,
      operation: 'create',
      data: settlement.toJson(),
    );

    return settlement;
  }

  /// Get settlements for a group
  Future<List<Settlement>> getSettlements(String groupId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'settlements',
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: 'settled_at DESC',
    );

    return results.map((row) => Settlement.fromMap(row)).toList();
  }
}
