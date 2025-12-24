import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user.dart';
import 'api_service.dart';

/// Authentication service for Firebase and guest auth.
class AuthService {
  final fb.FirebaseAuth _firebaseAuth;
  final ApiService _apiService;
  final _uuid = const Uuid();

  AuthService({
    fb.FirebaseAuth? firebaseAuth,
    required ApiService apiService,
  })  : _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance,
        _apiService = apiService;

  /// Current Firebase user
  fb.User? get currentFirebaseUser => _firebaseAuth.currentUser;

  /// Stream of auth state changes
  Stream<fb.User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    if (_firebaseAuth.currentUser != null) {
      return true;
    }
    // Check for guest token
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('guest_token') != null;
  }

  /// Sign up with email and password
  Future<User> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      await credential.user?.updateDisplayName(displayName);

      // Verify with backend
      final token = await credential.user?.getIdToken();
      if (token != null) {
        _apiService.setAuthToken(token);
        try {
          final response = await _apiService.verifyToken(token, displayName: displayName);
          return User.fromJson(response['user']);
        } catch (e) {
          // Backend not available, create local user from Firebase data
          debugPrint('Backend verification failed: $e');
          return User(
            id: credential.user!.uid,
            email: email,
            displayName: displayName,
            isGuest: false,
            createdAt: DateTime.now(),
          );
        }
      }

      throw Exception('Failed to get authentication token');
    } on fb.FirebaseAuthException catch (e) {
      throw _handleFirebaseError(e);
    } catch (e) {
      debugPrint('Sign up error: $e');
      // Handle Pigeon type cast errors and other unexpected errors
      if (e.toString().contains('PigeonUserDetails') || 
          e.toString().contains('type cast')) {
        throw Exception('Authentication service error. Please try again.');
      }
      rethrow;
    }
  }

  /// Sign in with email and password
  Future<User> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Verify with backend
      final token = await credential.user?.getIdToken();
      if (token != null) {
        _apiService.setAuthToken(token);
        try {
          final response = await _apiService.verifyToken(token);
          return User.fromJson(response['user']);
        } catch (e) {
          // Backend not available, create local user from Firebase data
          debugPrint('Backend verification failed: $e');
          return User(
            id: credential.user!.uid,
            email: email,
            displayName: credential.user?.displayName ?? email.split('@')[0],
            isGuest: false,
            createdAt: DateTime.now(),
          );
        }
      }

      throw Exception('Failed to get authentication token');
    } on fb.FirebaseAuthException catch (e) {
      throw _handleFirebaseError(e);
    } catch (e) {
      debugPrint('Sign in error: $e');
      // Handle Pigeon type cast errors and other unexpected errors
      if (e.toString().contains('PigeonUserDetails') || 
          e.toString().contains('type cast')) {
        throw Exception('Authentication service error. Please try again.');
      }
      rethrow;
    }
  }

  /// Continue as guest
  Future<User> continueAsGuest({String? displayName}) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get or create device ID
    String? deviceId = prefs.getString('device_id');
    if (deviceId == null) {
      deviceId = _uuid.v4();
      await prefs.setString('device_id', deviceId);
    }

    try {
      final response = await _apiService.guestLogin(
        deviceId,
        displayName: displayName ?? 'Guest User',
      );

      // Store guest token
      final guestToken = response['guest_token'] as String;
      await prefs.setString('guest_token', guestToken);
      _apiService.setAuthToken(guestToken);

      return User.fromJson(response['user']);
    } catch (e) {
      // Create offline guest user
      final offlineUser = User(
        id: _uuid.v4(),
        email: '',
        displayName: displayName ?? 'Guest User',
        isGuest: true,
        createdAt: DateTime.now(),
      );
      
      await prefs.setString('offline_user', offlineUser.id);
      return offlineUser;
    }
  }

  /// Refresh Firebase token
  Future<String?> refreshToken() async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      final token = await user.getIdToken(true);
      _apiService.setAuthToken(token);
      return token;
    }
    return null;
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      debugPrint('Firebase sign out error: $e');
    }

    // Clear guest token
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('guest_token');
    await prefs.remove('offline_user');
    
    _apiService.setAuthToken(null);
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on fb.FirebaseAuthException catch (e) {
      throw _handleFirebaseError(e);
    }
  }

  /// Update user profile
  Future<void> updateProfile({String? displayName, String? photoUrl}) async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }
      if (photoUrl != null) {
        await user.updatePhotoURL(photoUrl);
      }
    }
  }

  /// Convert guest to full account
  Future<User> convertGuestToAccount({
    required String email,
    required String password,
    required String displayName,
  }) async {
    // Sign out of guest
    await signOut();
    
    // Create new account
    return await signUp(
      email: email,
      password: password,
      displayName: displayName,
    );
  }

  /// Handle Firebase auth errors
  Exception _handleFirebaseError(fb.FirebaseAuthException e) {
    String message;
    switch (e.code) {
      case 'user-not-found':
        message = 'No account found with this email.';
        break;
      case 'wrong-password':
        message = 'Incorrect password.';
        break;
      case 'email-already-in-use':
        message = 'An account already exists with this email.';
        break;
      case 'weak-password':
        message = 'Password is too weak. Use at least 6 characters.';
        break;
      case 'invalid-email':
        message = 'Invalid email address.';
        break;
      case 'user-disabled':
        message = 'This account has been disabled.';
        break;
      case 'too-many-requests':
        message = 'Too many attempts. Please try again later.';
        break;
      case 'network-request-failed':
        message = 'Network error. Check your connection.';
        break;
      default:
        message = e.message ?? 'Authentication failed.';
    }
    return Exception(message);
  }
}
