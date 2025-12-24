import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

/// SQLite database helper for offline-first storage.
class DatabaseHelper {
  static DatabaseHelper? _instance;
  static Database? _database;

  DatabaseHelper._();

  static DatabaseHelper get instance {
    _instance ??= DatabaseHelper._();
    return _instance!;
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'chippin.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        firebase_uid TEXT,
        email TEXT,
        display_name TEXT,
        avatar_url TEXT,
        is_guest INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // Groups table
    await db.execute('''
      CREATE TABLE groups (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        owner_id TEXT NOT NULL,
        invite_code TEXT UNIQUE,
        currency TEXT DEFAULT 'INR',
        image_url TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0
      )
    ''');

    // Group members junction table
    await db.execute('''
      CREATE TABLE group_members (
        id TEXT PRIMARY KEY,
        group_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        role TEXT DEFAULT 'member',
        joined_at TEXT NOT NULL,
        FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        UNIQUE(group_id, user_id)
      )
    ''');

    // Expenses table
    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        group_id TEXT NOT NULL,
        description TEXT,
        amount REAL NOT NULL,
        currency TEXT DEFAULT 'INR',
        category_id TEXT,
        paid_by TEXT NOT NULL,
        split_type TEXT DEFAULT 'equal',
        receipt_url TEXT,
        notes TEXT,
        expense_date TEXT NOT NULL,
        is_settled INTEGER DEFAULT 0,
        is_deleted INTEGER DEFAULT 0,
        created_by TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        local_id TEXT,
        sync_version INTEGER DEFAULT 1,
        synced INTEGER DEFAULT 0,
        FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE
      )
    ''');

    // Expense splits table
    await db.execute('''
      CREATE TABLE expense_splits (
        id TEXT PRIMARY KEY,
        expense_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        amount REAL NOT NULL,
        percentage REAL,
        shares INTEGER DEFAULT 1,
        is_settled INTEGER DEFAULT 0,
        settled_at TEXT,
        FOREIGN KEY (expense_id) REFERENCES expenses(id) ON DELETE CASCADE,
        UNIQUE(expense_id, user_id)
      )
    ''');

    // Settlements table
    await db.execute('''
      CREATE TABLE settlements (
        id TEXT PRIMARY KEY,
        group_id TEXT NOT NULL,
        from_user_id TEXT NOT NULL,
        to_user_id TEXT NOT NULL,
        amount REAL NOT NULL,
        notes TEXT,
        settled_at TEXT NOT NULL,
        created_by TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE
      )
    ''');

    // Sync metadata table
    await db.execute('''
      CREATE TABLE sync_meta (
        key TEXT PRIMARY KEY,
        value TEXT,
        updated_at TEXT NOT NULL
      )
    ''');

    // Pending sync operations table
    await db.execute('''
      CREATE TABLE pending_sync (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at TEXT NOT NULL,
        attempts INTEGER DEFAULT 0
      )
    ''');

    // Create indices for better query performance
    await db.execute('CREATE INDEX idx_expenses_group ON expenses(group_id)');
    await db.execute('CREATE INDEX idx_expenses_date ON expenses(expense_date)');
    await db.execute('CREATE INDEX idx_splits_expense ON expense_splits(expense_id)');
    await db.execute('CREATE INDEX idx_members_group ON group_members(group_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations here
    if (oldVersion < 2) {
      // Example: Add new columns for version 2
    }
  }

  /// Clear all data (for logout)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('expense_splits');
    await db.delete('expenses');
    await db.delete('settlements');
    await db.delete('group_members');
    await db.delete('groups');
    await db.delete('users');
    await db.delete('sync_meta');
    await db.delete('pending_sync');
  }

  /// Get last sync timestamp
  Future<DateTime?> getLastSyncTime() async {
    final db = await database;
    final result = await db.query(
      'sync_meta',
      where: 'key = ?',
      whereArgs: ['last_sync'],
    );
    if (result.isEmpty) return null;
    return DateTime.parse(result.first['value'] as String);
  }

  /// Set last sync timestamp
  Future<void> setLastSyncTime(DateTime time) async {
    final db = await database;
    await db.insert(
      'sync_meta',
      {
        'key': 'last_sync',
        'value': time.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Add pending sync operation
  Future<void> addPendingSync({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> data,
  }) async {
    final db = await database;
    await db.insert('pending_sync', {
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation,
      'data': data.toString(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Get pending sync operations
  Future<List<Map<String, dynamic>>> getPendingSyncOperations() async {
    final db = await database;
    return await db.query(
      'pending_sync',
      orderBy: 'created_at ASC',
    );
  }

  /// Remove pending sync operation
  Future<void> removePendingSync(int id) async {
    final db = await database;
    await db.delete('pending_sync', where: 'id = ?', whereArgs: [id]);
  }

  /// Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
