import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/group.dart';
import '../models/member.dart';
import '../models/expense.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'chippin.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    // Groups table
    await db.execute('''
      CREATE TABLE groups (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        createdAt INTEGER NOT NULL,
        createdBy TEXT NOT NULL,
        memberIds TEXT,
        inviteCode TEXT
      )
    ''');

    // Members table
    await db.execute('''
      CREATE TABLE members (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        avatarUrl TEXT,
        joinedAt INTEGER NOT NULL
      )
    ''');

    // Expenses table
    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        groupId TEXT NOT NULL,
        description TEXT NOT NULL,
        amount REAL NOT NULL,
        paidBy TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        receiptImagePath TEXT,
        merchantName TEXT,
        FOREIGN KEY (groupId) REFERENCES groups (id)
      )
    ''');

    // Expense splits table
    await db.execute('''
      CREATE TABLE expense_splits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        expenseId TEXT NOT NULL,
        memberId TEXT NOT NULL,
        amount REAL NOT NULL,
        isPaid INTEGER DEFAULT 0,
        FOREIGN KEY (expenseId) REFERENCES expenses (id),
        FOREIGN KEY (memberId) REFERENCES members (id)
      )
    ''');
  }

  // Group operations
  Future<int> insertGroup(Group group) async {
    final db = await database;
    return await db.insert('groups', group.toMap());
  }

  Future<List<Group>> getGroups() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('groups');
    return List.generate(maps.length, (i) => Group.fromMap(maps[i]));
  }

  Future<Group?> getGroup(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'groups',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Group.fromMap(maps.first);
    }
    return null;
  }

  // Member operations
  Future<int> insertMember(Member member) async {
    final db = await database;
    return await db.insert('members', member.toMap());
  }

  Future<List<Member>> getMembers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('members');
    return List.generate(maps.length, (i) => Member.fromMap(maps[i]));
  }

  // Expense operations
  Future<int> insertExpense(Expense expense) async {
    final db = await database;
    await db.insert('expenses', expense.toMap());

    // Insert splits
    for (var split in expense.splits) {
      await db.insert('expense_splits', {
        'expenseId': expense.id,
        'memberId': split.memberId,
        'amount': split.amount,
        'isPaid': split.isPaid ? 1 : 0,
      });
    }
    return 1;
  }

  Future<List<Expense>> getGroupExpenses(String groupId) async {
    final db = await database;
    final List<Map<String, dynamic>> expenseMaps = await db.query(
      'expenses',
      where: 'groupId = ?',
      whereArgs: [groupId],
      orderBy: 'createdAt DESC',
    );

    List<Expense> expenses = [];
    for (var expenseMap in expenseMaps) {
      final List<Map<String, dynamic>> splitMaps = await db.query(
        'expense_splits',
        where: 'expenseId = ?',
        whereArgs: [expenseMap['id']],
      );

      List<ExpenseSplit> splits = splitMaps
          .map(
            (splitMap) => ExpenseSplit(
              memberId: splitMap['memberId'],
              amount: splitMap['amount'].toDouble(),
              isPaid: splitMap['isPaid'] == 1,
            ),
          )
          .toList();

      expenses.add(
        Expense(
          id: expenseMap['id'],
          groupId: expenseMap['groupId'],
          description: expenseMap['description'],
          amount: expenseMap['amount'].toDouble(),
          paidBy: expenseMap['paidBy'],
          splits: splits,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            expenseMap['createdAt'],
          ),
          receiptImagePath: expenseMap['receiptImagePath'],
          merchantName: expenseMap['merchantName'],
        ),
      );
    }
    return expenses;
  }
}
