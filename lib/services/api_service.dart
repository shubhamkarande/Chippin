import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// API Service for backend communication.
class ApiService {
  static const String _baseUrl = 'http://localhost:8000/api';
  
  late final Dio _dio;
  String? _authToken;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Add logging interceptor in debug mode
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
      ));
    }

    // Add auth interceptor
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_authToken != null) {
          options.headers['Authorization'] = 'Bearer $_authToken';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          // Token expired - trigger re-auth
          debugPrint('Auth token expired');
        }
        return handler.next(error);
      },
    ));
  }

  /// Set authentication token
  void setAuthToken(String? token) {
    _authToken = token;
  }

  /// Update base URL (for different environments)
  void setBaseUrl(String url) {
    _dio.options.baseUrl = url;
  }

  // ============ AUTH ENDPOINTS ============

  /// Verify Firebase token with backend
  Future<Map<String, dynamic>> verifyToken(String firebaseToken, {String? displayName}) async {
    final response = await _dio.post('/auth/verify', data: {
      'token': firebaseToken,
      'display_name': displayName,
    });
    return response.data;
  }

  /// Guest login
  Future<Map<String, dynamic>> guestLogin(String deviceId, {String? displayName}) async {
    final response = await _dio.post('/auth/guest', data: {
      'device_id': deviceId,
      'display_name': displayName,
    });
    return response.data;
  }

  /// Get current user
  Future<Map<String, dynamic>> getCurrentUser() async {
    final response = await _dio.get('/auth/me');
    return response.data;
  }

  // ============ GROUP ENDPOINTS ============

  /// Get all groups
  Future<List<dynamic>> getGroups() async {
    final response = await _dio.get('/groups/');
    return response.data['results'] ?? response.data;
  }

  /// Get single group
  Future<Map<String, dynamic>> getGroup(String groupId) async {
    final response = await _dio.get('/groups/$groupId/');
    return response.data;
  }

  /// Create group
  Future<Map<String, dynamic>> createGroup({
    required String name,
    String description = '',
    String currency = 'INR',
    String? imageUrl,
  }) async {
    final response = await _dio.post('/groups/', data: {
      'name': name,
      'description': description,
      'currency': currency,
      'image_url': imageUrl,
    });
    return response.data;
  }

  /// Join group
  Future<Map<String, dynamic>> joinGroup(String inviteCode) async {
    final response = await _dio.post('/groups/join/', data: {
      'invite_code': inviteCode,
    });
    return response.data;
  }

  /// Leave group
  Future<void> leaveGroup(String groupId) async {
    await _dio.post('/groups/$groupId/leave/');
  }

  /// Get group balances
  Future<Map<String, dynamic>> getGroupBalances(String groupId) async {
    final response = await _dio.get('/groups/$groupId/balances/');
    return response.data;
  }

  /// Regenerate invite code
  Future<String> regenerateInviteCode(String groupId) async {
    final response = await _dio.post('/groups/$groupId/regenerate_invite/');
    return response.data['invite_code'];
  }

  // ============ EXPENSE ENDPOINTS ============

  /// Get expenses for a group
  Future<List<dynamic>> getExpenses({
    String? groupId,
    String? category,
    String? startDate,
    String? endDate,
    bool? isSettled,
  }) async {
    final queryParams = <String, dynamic>{};
    if (groupId != null) queryParams['group'] = groupId;
    if (category != null) queryParams['category'] = category;
    if (startDate != null) queryParams['start_date'] = startDate;
    if (endDate != null) queryParams['end_date'] = endDate;
    if (isSettled != null) queryParams['is_settled'] = isSettled.toString();

    final response = await _dio.get('/expenses/', queryParameters: queryParams);
    return response.data['results'] ?? response.data;
  }

  /// Get single expense
  Future<Map<String, dynamic>> getExpense(String expenseId) async {
    final response = await _dio.get('/expenses/$expenseId/');
    return response.data;
  }

  /// Create expense
  Future<Map<String, dynamic>> createExpense(Map<String, dynamic> data) async {
    final response = await _dio.post('/expenses/', data: data);
    return response.data;
  }

  /// Update expense
  Future<Map<String, dynamic>> updateExpense(String expenseId, Map<String, dynamic> data) async {
    final response = await _dio.patch('/expenses/$expenseId/', data: data);
    return response.data;
  }

  /// Delete expense
  Future<void> deleteExpense(String expenseId) async {
    await _dio.delete('/expenses/$expenseId/');
  }

  /// Settle expense
  Future<void> settleExpense(String expenseId) async {
    await _dio.post('/expenses/$expenseId/settle/');
  }

  /// Get expense summary
  Future<Map<String, dynamic>> getExpenseSummary(String groupId) async {
    final response = await _dio.get('/expenses/summary/', queryParameters: {
      'group': groupId,
    });
    return response.data;
  }

  // ============ SETTLEMENT ENDPOINTS ============

  /// Create settlement
  Future<Map<String, dynamic>> createSettlement(Map<String, dynamic> data) async {
    final response = await _dio.post('/settlements/', data: data);
    return response.data;
  }

  /// Get settlements
  Future<List<dynamic>> getSettlements(String groupId) async {
    final response = await _dio.get('/settlements/', queryParameters: {
      'group': groupId,
    });
    return response.data['results'] ?? response.data;
  }

  // ============ SYNC ENDPOINTS ============

  /// Push local changes to server
  Future<Map<String, dynamic>> syncPush(List<Map<String, dynamic>> changes) async {
    final response = await _dio.post('/sync/push', data: {
      'changes': changes,
    });
    return response.data;
  }

  /// Pull changes from server
  Future<Map<String, dynamic>> syncPull({DateTime? lastSync, List<String>? groupIds}) async {
    final queryParams = <String, dynamic>{};
    if (lastSync != null) queryParams['last_sync'] = lastSync.toIso8601String();
    if (groupIds != null) queryParams['group_ids'] = groupIds.join(',');

    final response = await _dio.get('/sync/pull', queryParameters: queryParams);
    return response.data;
  }

  // ============ CATEGORY ENDPOINTS ============

  /// Get categories
  Future<Map<String, dynamic>> getCategories() async {
    final response = await _dio.get('/categories/');
    return response.data;
  }
}
