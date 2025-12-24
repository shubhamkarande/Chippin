import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../models/group.dart';
import '../models/expense.dart';
import '../models/balance.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../services/ocr_service.dart';
import '../services/export_service.dart';
import '../local_db/repositories/group_repository.dart';
import '../local_db/repositories/expense_repository.dart';

// ============ SERVICES ============

/// API Service provider
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

/// Auth Service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(apiService: ref.watch(apiServiceProvider));
});

/// Group Repository provider
final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepository();
});

/// Expense Repository provider
final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository();
});

/// Sync Service provider
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    apiService: ref.watch(apiServiceProvider),
    groupRepo: ref.watch(groupRepositoryProvider),
    expenseRepo: ref.watch(expenseRepositoryProvider),
  );
});

/// OCR Service provider
final ocrServiceProvider = Provider<OcrService>((ref) {
  return OcrService();
});

/// Export Service provider
final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService();
});

// ============ THEME ============

/// Theme mode provider
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString('theme_mode');
    if (theme != null) {
      state = ThemeMode.values.firstWhere(
        (m) => m.name == theme,
        orElse: () => ThemeMode.system,
      );
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
  }

  void toggleTheme() {
    if (state == ThemeMode.dark) {
      setThemeMode(ThemeMode.light);
    } else {
      setThemeMode(ThemeMode.dark);
    }
  }
}

// ============ AUTH STATE ============

/// Auth state
class AuthState {
  final User? user;
  final bool isLoading;
  final bool isAuthenticated;
  final String? error;

  AuthState({
    this.user,
    this.isLoading = false,
    this.isAuthenticated = false,
    this.error,
  });

  AuthState copyWith({
    User? user,
    bool? isLoading,
    bool? isAuthenticated,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      error: error,
    );
  }
}

final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((ref) {
  return AuthStateNotifier(ref.watch(authServiceProvider));
});

class AuthStateNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthStateNotifier(this._authService) : super(AuthState());

  Future<void> checkAuthStatus() async {
    state = state.copyWith(isLoading: true);
    try {
      final isLoggedIn = await _authService.isLoggedIn();
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: isLoggedIn,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _authService.signIn(email: email, password: password);
      state = state.copyWith(
        user: user,
        isLoading: false,
        isAuthenticated: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> signUp(String email, String password, String displayName) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _authService.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );
      state = state.copyWith(
        user: user,
        isLoading: false,
        isAuthenticated: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> continueAsGuest({String? displayName}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _authService.continueAsGuest(displayName: displayName);
      state = state.copyWith(
        user: user,
        isLoading: false,
        isAuthenticated: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    state = AuthState();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// ============ GROUPS STATE ============

/// Groups state
class GroupsState {
  final List<Group> groups;
  final Group? selectedGroup;
  final bool isLoading;
  final String? error;

  GroupsState({
    this.groups = const [],
    this.selectedGroup,
    this.isLoading = false,
    this.error,
  });

  GroupsState copyWith({
    List<Group>? groups,
    Group? selectedGroup,
    bool? isLoading,
    String? error,
  }) {
    return GroupsState(
      groups: groups ?? this.groups,
      selectedGroup: selectedGroup ?? this.selectedGroup,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final groupsStateProvider = StateNotifierProvider<GroupsStateNotifier, GroupsState>((ref) {
  return GroupsStateNotifier(
    ref.watch(groupRepositoryProvider),
    ref.watch(syncServiceProvider),
  );
});

class GroupsStateNotifier extends StateNotifier<GroupsState> {
  final GroupRepository _groupRepo;
  final SyncService _syncService;

  GroupsStateNotifier(this._groupRepo, this._syncService) : super(GroupsState());

  Future<void> loadGroups(String userId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Load from local database first with timeout
      final groups = await _groupRepo.getGroups(userId)
          .timeout(const Duration(seconds: 5), onTimeout: () => <Group>[]);
      state = state.copyWith(groups: groups, isLoading: false);

      // Sync in background (don't wait for it)
      _syncService.fullSync(userId).catchError((_) {});
    } catch (e) {
      // If loading fails, just show empty state
      state = state.copyWith(groups: [], isLoading: false);
    }
  }

  Future<void> createGroup({
    required String name,
    required String ownerId,
    String description = '',
    String currency = 'INR',
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final group = await _groupRepo.createGroup(
        name: name,
        ownerId: ownerId,
        description: description,
        currency: currency,
      ).timeout(const Duration(seconds: 10));
      state = state.copyWith(
        groups: [...state.groups, group],
        selectedGroup: group,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> joinGroup(String inviteCode, String userId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Try to find locally first
      var group = await _groupRepo.getGroupByInviteCode(inviteCode)
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      
      if (group == null) {
        // Try to join via API
        if (await _syncService.isOnline()) {
          // This would need to be implemented
          throw Exception('Group not found');
        }
        throw Exception('Cannot join group while offline');
      }

      // Add user as member
      await _groupRepo.addMember(groupId: group.id, userId: userId);

      // Reload groups
      await loadGroups(userId);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void selectGroup(Group group) {
    state = state.copyWith(selectedGroup: group);
  }

  void clearSelection() {
    state = state.copyWith(selectedGroup: null);
  }

  void clearError() {
    state = state.copyWith(error: null, isLoading: false);
  }
}

// ============ EXPENSES STATE ============

/// Expenses state
class ExpensesState {
  final List<Expense> expenses;
  final Map<String, dynamic>? balances;
  final bool isLoading;
  final String? error;

  ExpensesState({
    this.expenses = const [],
    this.balances,
    this.isLoading = false,
    this.error,
  });

  ExpensesState copyWith({
    List<Expense>? expenses,
    Map<String, dynamic>? balances,
    bool? isLoading,
    String? error,
  }) {
    return ExpensesState(
      expenses: expenses ?? this.expenses,
      balances: balances ?? this.balances,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  List<Balance> get balanceList {
    final list = balances?['balances'] as List<dynamic>? ?? [];
    return list.map((b) {
      if (b is Balance) return b;
      return Balance.fromJson(b as Map<String, dynamic>);
    }).toList();
  }

  List<SimplifiedDebt> get debtList {
    final list = balances?['simplified_debts'] as List<dynamic>? ?? [];
    return list.map((d) {
      if (d is SimplifiedDebt) return d;
      return SimplifiedDebt.fromJson(d as Map<String, dynamic>);
    }).toList();
  }
}

final expensesStateProvider = StateNotifierProvider<ExpensesStateNotifier, ExpensesState>((ref) {
  return ExpensesStateNotifier(ref.watch(expenseRepositoryProvider));
});

class ExpensesStateNotifier extends StateNotifier<ExpensesState> {
  final ExpenseRepository _expenseRepo;

  ExpensesStateNotifier(this._expenseRepo) : super(ExpensesState());

  Future<void> loadExpenses(String groupId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final expenses = await _expenseRepo.getExpenses(groupId)
          .timeout(const Duration(seconds: 5), onTimeout: () => <Expense>[]);
      final balances = await _expenseRepo.calculateBalances(groupId)
          .timeout(const Duration(seconds: 5), onTimeout: () => <String, dynamic>{});
      state = state.copyWith(
        expenses: expenses,
        balances: balances,
        isLoading: false,
      );
    } catch (e) {
      // On error, just show empty state
      state = state.copyWith(expenses: [], balances: {}, isLoading: false);
    }
  }

  Future<void> createExpense({
    required String groupId,
    required String description,
    required double amount,
    required String paidById,
    required String createdById,
    String? categoryId,
    SplitType splitType = SplitType.equal,
    List<ExpenseSplit>? splits,
    DateTime? expenseDate,
    String notes = '',
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final expense = await _expenseRepo.createExpense(
        groupId: groupId,
        description: description,
        amount: amount,
        paidById: paidById,
        createdById: createdById,
        categoryId: categoryId,
        splitType: splitType,
        splits: splits,
        expenseDate: expenseDate,
        notes: notes,
      );

      // If equal split and no splits provided, create them
      if (splitType == SplitType.equal && splits == null) {
        // This would need member IDs - simplified for now
      }

      await loadExpenses(groupId);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> deleteExpense(String expenseId, String groupId) async {
    try {
      await _expenseRepo.deleteExpense(expenseId);
      await loadExpenses(groupId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> createSettlement({
    required String groupId,
    required String fromUserId,
    required String toUserId,
    required double amount,
    required String createdById,
    String notes = '',
  }) async {
    try {
      await _expenseRepo.createSettlement(
        groupId: groupId,
        fromUserId: fromUserId,
        toUserId: toUserId,
        amount: amount,
        createdById: createdById,
        notes: notes,
      );
      await loadExpenses(groupId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// ============ SYNC STATE ============

final syncStatusProvider = StateProvider<SyncStatus>((ref) {
  return SyncStatus.idle;
});

final pendingSyncCountProvider = FutureProvider<int>((ref) async {
  final syncService = ref.watch(syncServiceProvider);
  return await syncService.getPendingSyncCount();
});
