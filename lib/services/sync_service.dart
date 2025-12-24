import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../local_db/database_helper.dart';
import '../local_db/repositories/group_repository.dart';
import '../local_db/repositories/expense_repository.dart';
import '../models/group.dart';
import '../models/expense.dart';
import 'api_service.dart';

/// Sync status enum.
enum SyncStatus {
  idle,
  syncing,
  success,
  error,
  offline,
}

/// Sync service for offline-first data synchronization.
class SyncService {
  final ApiService _apiService;
  final GroupRepository _groupRepo;
  final ExpenseRepository _expenseRepo;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  SyncStatus _status = SyncStatus.idle;
  String? _lastError;

  SyncService({
    required ApiService apiService,
    required GroupRepository groupRepo,
    required ExpenseRepository expenseRepo,
  })  : _apiService = apiService,
        _groupRepo = groupRepo,
        _expenseRepo = expenseRepo;

  SyncStatus get status => _status;
  String? get lastError => _lastError;

  /// Check if device is online
  Future<bool> isOnline() async {
    final connectivityResults = await Connectivity().checkConnectivity();
    // connectivityResults is List<ConnectivityResult> in newer versions
    if (connectivityResults is List) {
      return !(connectivityResults as List).contains(ConnectivityResult.none);
    }
    // For older versions where it returns single value
    return connectivityResults != ConnectivityResult.none;
  }

  /// Full sync - push local changes then pull server updates
  Future<void> fullSync(String userId) async {
    if (!await isOnline()) {
      _status = SyncStatus.offline;
      return;
    }

    _status = SyncStatus.syncing;
    _lastError = null;

    try {
      // 1. Push pending local changes
      await _pushPendingChanges();

      // 2. Pull server updates
      await _pullServerUpdates(userId);

      _status = SyncStatus.success;
      await _dbHelper.setLastSyncTime(DateTime.now());
    } catch (e) {
      _status = SyncStatus.error;
      _lastError = e.toString();
      debugPrint('Sync error: $e');
    }
  }

  /// Push only pending local changes
  Future<void> _pushPendingChanges() async {
    final pendingOps = await _dbHelper.getPendingSyncOperations();
    if (pendingOps.isEmpty) return;

    final changes = pendingOps.map((op) {
      // Parse the data string back to map
      Map<String, dynamic> data;
      try {
        // Simple parsing - in production use json.decode
        data = {'raw': op['data']};
      } catch (e) {
        data = {};
      }

      return {
        'entity_type': op['entity_type'],
        'operation': op['operation'],
        'entity_id': op['entity_id'],
        'data': data,
        'client_timestamp': op['created_at'],
      };
    }).toList();

    try {
      final response = await _apiService.syncPush(changes);
      final results = response['results'] as List<dynamic>? ?? [];

      // Process results and remove successful sync ops
      for (var i = 0; i < results.length && i < pendingOps.length; i++) {
        final result = results[i] as Map<String, dynamic>;
        if (result['success'] == true) {
          await _dbHelper.removePendingSync(pendingOps[i]['id'] as int);
        }
      }
    } catch (e) {
      debugPrint('Push sync error: $e');
      rethrow;
    }
  }

  /// Pull updates from server
  Future<void> _pullServerUpdates(String userId) async {
    final lastSync = await _dbHelper.getLastSyncTime();

    try {
      final response = await _apiService.syncPull(lastSync: lastSync);

      // Process groups
      final groups = (response['groups'] as List<dynamic>? ?? [])
          .map((g) => Group.fromJson(g))
          .toList();
      await _groupRepo.syncGroups(groups, userId);

      // Process expenses
      final expenses = (response['expenses'] as List<dynamic>? ?? [])
          .map((e) => Expense.fromJson(e))
          .toList();
      await _expenseRepo.syncExpenses(expenses);

      debugPrint('Synced ${groups.length} groups, ${expenses.length} expenses');
    } catch (e) {
      debugPrint('Pull sync error: $e');
      rethrow;
    }
  }

  /// Sync specific group
  Future<Group?> syncGroup(String groupId) async {
    if (!await isOnline()) return null;

    try {
      final response = await _apiService.getGroup(groupId);
      final group = Group.fromJson(response);
      
      // Update local database
      final db = await _dbHelper.database;
      await db.insert(
        'groups',
        group.copyWith(synced: true).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      return group;
    } catch (e) {
      debugPrint('Group sync error: $e');
      return null;
    }
  }

  /// Sync expenses for a group
  Future<List<Expense>> syncGroupExpenses(String groupId) async {
    if (!await isOnline()) return [];

    try {
      final response = await _apiService.getExpenses(groupId: groupId);
      final expenses = (response as List<dynamic>)
          .map((e) => Expense.fromJson(e))
          .toList();
      
      await _expenseRepo.syncExpenses(expenses);
      return expenses;
    } catch (e) {
      debugPrint('Expenses sync error: $e');
      return [];
    }
  }

  /// Check for conflicts between local and server data
  Future<List<Map<String, dynamic>>> checkConflicts(String groupId) async {
    // Get local unsynced changes
    final pendingOps = await _dbHelper.getPendingSyncOperations();
    final localChanges = pendingOps
        .where((op) => op['entity_type'] == 'expense')
        .toList();

    if (localChanges.isEmpty) return [];

    // Compare with server
    final conflicts = <Map<String, dynamic>>[];
    
    for (final change in localChanges) {
      try {
        final serverData = await _apiService.getExpense(change['entity_id'] as String);
        final serverUpdated = DateTime.parse(serverData['updated_at'] as String);
        final localUpdated = DateTime.parse(change['created_at'] as String);

        if (serverUpdated.isAfter(localUpdated)) {
          conflicts.add({
            'type': 'expense',
            'local': change,
            'server': serverData,
          });
        }
      } catch (e) {
        // Expense doesn't exist on server (might be new)
        continue;
      }
    }

    return conflicts;
  }

  /// Resolve conflict by keeping server version
  Future<void> resolveConflictKeepServer(String entityType, String entityId) async {
    // Remove pending sync operation
    final pendingOps = await _dbHelper.getPendingSyncOperations();
    for (final op in pendingOps) {
      if (op['entity_type'] == entityType && op['entity_id'] == entityId) {
        await _dbHelper.removePendingSync(op['id'] as int);
      }
    }

    // Pull server version
    if (entityType == 'expense') {
      try {
        final response = await _apiService.getExpense(entityId);
        final expense = Expense.fromJson(response);
        await _expenseRepo.syncExpenses([expense]);
      } catch (e) {
        debugPrint('Failed to fetch server version: $e');
      }
    }
  }

  /// Resolve conflict by keeping local version (force push)
  Future<void> resolveConflictKeepLocal(String entityType, String entityId) async {
    // The pending sync operation will be pushed on next sync
    // This is handled automatically
  }

  /// Get pending sync count
  Future<int> getPendingSyncCount() async {
    final pendingOps = await _dbHelper.getPendingSyncOperations();
    return pendingOps.length;
  }

  /// Clear all pending sync operations
  Future<void> clearPendingSync() async {
    final db = await _dbHelper.database;
    await db.delete('pending_sync');
  }
}

