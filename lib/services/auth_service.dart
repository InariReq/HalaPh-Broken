import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:halaph/models/user.dart';
import 'package:halaph/services/favorites_service.dart';
import 'package:halaph/services/firebase_app_service.dart';
import 'package:halaph/services/firestore_service.dart';
import 'package:halaph/services/friend_service.dart';
import 'package:halaph/services/commuter_type_service.dart';
import 'package:halaph/services/simple_plan_service.dart';
import 'package:halaph/services/saved_accounts_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  String? _lastAuthError;
  String? get lastAuthError => _lastAuthError;

  Future<User?> getCurrentUser() async {
    final firebaseUser = await _getFirebaseUser();
    if (firebaseUser != null) return _toAppUser(firebaseUser);
    return null;
  }

  Future<bool> isLoggedIn() async {
    final firebaseUser = await _getFirebaseUser();
    return firebaseUser != null;
  }

  Future<User?> login(String email, String password) async {
    _lastAuthError = null;
    if (email.isEmpty || password.isEmpty) {
      _lastAuthError = 'Enter your email and password.';
      return null;
    }

    final firebaseUser = await _signInWithFirebase(email, password);
    if (firebaseUser != null) {
      CommuterTypeService().clearCache();
      SimplePlanService.resetCache();
      FavoritesService().clearCache();
      await _ensureFriendIdentity();
      await SavedAccountsService().saveFirebaseUser(firebaseUser);
      return _toAppUser(firebaseUser);
    }
    return null;
  }

  Future<User?> register(String email, String password, {String? name}) async {
    _lastAuthError = null;
    if (email.isEmpty || password.isEmpty) {
      _lastAuthError = 'Enter an email and password.';
      return null;
    }

    final firebaseUser = await _registerWithFirebase(email, password, name);
    if (firebaseUser != null) {
      CommuterTypeService().clearCache();
      SimplePlanService.resetCache();
      FavoritesService().clearCache();
      await _ensureFriendIdentity();
      await SavedAccountsService().saveFirebaseUser(firebaseUser);
      return _toAppUser(firebaseUser, fallbackName: name);
    }
    return null;
  }

  Future<void> _ensureFriendIdentity() async {
    try {
      await FriendService().ensureFriendCodeExists();
    } catch (error) {
      debugPrint('Friend identity setup failed: $error');
    }
  }

  Future<String> getCurrentUserIdentifier() async {
    final firebaseUser = await _getFirebaseUser();
    if (firebaseUser != null && firebaseUser.uid.isNotEmpty) {
      return firebaseUser.uid;
    }

    final user = await getCurrentUser();
    if (user != null && user.email.isNotEmpty) return user.email;
    return 'current_user';
  }

  Future<void> logout({bool removeSavedAccount = false}) async {
    try {
      final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
      if (removeSavedAccount && uid != null && uid.trim().isNotEmpty) {
        await SavedAccountsService().removeSavedAccount(uid.trim());
      }
      await firebase_auth.FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('Logout failed: $e');
    }
  }

  Future<firebase_auth.User?> _getFirebaseUser() async {
    if (!await FirebaseAppService.initialize()) return null;
    return firebase_auth.FirebaseAuth.instance.currentUser;
  }

  Future<firebase_auth.User?> _signInWithFirebase(
    String email,
    String password,
  ) async {
    if (!await FirebaseAppService.initialize(forceRetry: true)) {
      _lastAuthError = 'Firebase is not configured for this platform.';
      return null;
    }
    try {
      final credential = await firebase_auth.FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      return credential.user;
    } on firebase_auth.FirebaseAuthException catch (error) {
      _lastAuthError = _messageForAuthException(error, isRegistration: false);
      debugPrint('Firebase login failed: ${error.code} ${error.message ?? ''}');
      return null;
    } catch (error) {
      _lastAuthError = 'Login failed. Check your connection and try again.';
      debugPrint('Firebase login failed: $error');
      return null;
    }
  }

  Future<firebase_auth.User?> _registerWithFirebase(
    String email,
    String password,
    String? name,
  ) async {
    if (!await FirebaseAppService.initialize(forceRetry: true)) {
      _lastAuthError = 'Firebase is not configured for this platform.';
      return null;
    }
    try {
      final credential = await firebase_auth.FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      final user = credential.user;
      final displayName = name?.trim();
      if (user != null && displayName != null && displayName.isNotEmpty) {
        await user.updateDisplayName(displayName);
        await user.reload();
      }
      return firebase_auth.FirebaseAuth.instance.currentUser ?? user;
    } on firebase_auth.FirebaseAuthException catch (error) {
      _lastAuthError = _messageForAuthException(error, isRegistration: true);
      debugPrint(
        'Firebase registration failed: ${error.code} ${error.message ?? ''}',
      );
      return null;
    } catch (error) {
      _lastAuthError =
          'Account creation failed. Check your connection and try again.';
      debugPrint('Firebase registration failed: $error');
      return null;
    }
  }

  String _messageForAuthException(
    firebase_auth.FirebaseAuthException error, {
    required bool isRegistration,
  }) {
    switch (error.code) {
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account exists for that email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Password is incorrect.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Use a stronger password.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase Authentication.';
      case 'invalid-api-key':
      case 'api-key-not-valid':
      case 'app-not-authorized':
      case 'configuration-not-found':
        return 'Firebase Authentication is not configured for this app.';
      default:
        return isRegistration
            ? 'Could not create the account. ${error.message ?? 'Please try again.'}'
            : 'Could not log in. ${error.message ?? 'Please try again.'}';
    }
  }

  User _toAppUser(firebase_auth.User firebaseUser, {String? fallbackName}) {
    final email = firebaseUser.email ?? '';
    final name = firebaseUser.displayName?.trim();
    return User(
      email: email,
      name: (name != null && name.isNotEmpty)
          ? name
          : fallbackName ?? email.split('@').first,
      avatarUrl: firebaseUser.photoURL,
    );
  }

  Future<User?> updateProfile({String? name, String? avatarUrl}) async {
    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      if (name != null && name.trim().isNotEmpty) {
        await user.updateDisplayName(name.trim());
      }

      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        await user.updatePhotoURL(avatarUrl);
      }

      await user.reload();
      final refreshedUser =
          firebase_auth.FirebaseAuth.instance.currentUser ?? user;
      await SavedAccountsService().saveFirebaseUser(refreshedUser);
      return _toAppUser(refreshedUser);
    } catch (e) {
      debugPrint('Failed to update profile: $e');
      return null;
    }
  }

  Future<bool> deleteCurrentAccount({required String password}) async {
    _lastAuthError = null;

    if (!await FirebaseAppService.initialize(forceRetry: true)) {
      _lastAuthError = 'Firebase is not configured for this platform.';
      return false;
    }

    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.trim().isEmpty) {
      _lastAuthError = 'No signed-in account found.';
      return false;
    }

    if (password.trim().isEmpty) {
      _lastAuthError = 'Enter your password to delete this account.';
      return false;
    }

    try {
      final credential = firebase_auth.EmailAuthProvider.credential(
        email: email,
        password: password.trim(),
      );
      await user.reauthenticateWithCredential(credential);

      final uid = user.uid;
      String? friendCode;
      try {
        friendCode = await FriendService().getMyCode();
      } catch (error) {
        debugPrint('Could not load friend code before account cleanup: $error');
      }

      try {
        await SimplePlanService.cleanupAccountPlans(
          uid: uid,
          friendCode: friendCode,
        );
        await FirestoreService.cleanupAccountData(
          uid: uid,
          friendCode: friendCode,
        );
      } catch (error) {
        _lastAuthError =
            'Could not clean up account data. Please check your connection and try again.';
        debugPrint('Delete account cleanup failed: $error');
        return false;
      }

      await user.delete();
      try {
        await SavedAccountsService().removeSavedAccount(uid);
        await firebase_auth.FirebaseAuth.instance.signOut();
      } catch (error) {
        debugPrint('Post-delete local account cleanup skipped: $error');
      }
      SimplePlanService.resetCache();
      FavoritesService().clearCache();
      FriendService().clearCache();
      CommuterTypeService().clearCache();
      return true;
    } on firebase_auth.FirebaseAuthException catch (error) {
      if (error.code == 'requires-recent-login') {
        _lastAuthError =
            'Please sign in again, then retry deleting your account.';
      } else {
        _lastAuthError = _messageForAuthException(error, isRegistration: false);
      }
      debugPrint('Delete account failed: ${error.code} ${error.message ?? ''}');
      return false;
    } catch (error) {
      _lastAuthError = 'Could not delete account. Check your connection.';
      debugPrint('Delete account failed: $error');
      return false;
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    _lastAuthError = null;
    final trimmedEmail = email.trim();

    if (trimmedEmail.isEmpty) {
      _lastAuthError = 'Enter your email address.';
      return false;
    }

    if (!await FirebaseAppService.initialize(forceRetry: true)) {
      _lastAuthError = 'Firebase is not configured for this platform.';
      return false;
    }

    try {
      await firebase_auth.FirebaseAuth.instance
          .sendPasswordResetEmail(email: trimmedEmail)
          .timeout(const Duration(seconds: 12));
      return true;
    } on firebase_auth.FirebaseAuthException catch (error) {
      _lastAuthError = _messageForPasswordResetException(error);
      debugPrint('Password reset failed: ${error.code} ${error.message ?? ''}');
      return false;
    } on TimeoutException catch (error) {
      _lastAuthError =
          'Could not send reset email. Check your connection and try again.';
      debugPrint('Password reset timed out: $error');
      return false;
    } catch (error) {
      _lastAuthError =
          'Could not send reset email. Check your connection and try again.';
      debugPrint('Password reset failed: $error');
      return false;
    }
  }

  String _messageForPasswordResetException(
    firebase_auth.FirebaseAuthException error,
  ) {
    switch (error.code) {
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'user-not-found':
      case 'invalid-recipient-email':
      case 'missing-email':
        return 'If this email exists, a reset link has been sent.';
      case 'network-request-failed':
      case 'too-many-requests':
        return 'Could not send reset email. Check your connection and try again.';
      default:
        return 'Could not send reset email. Check your connection and try again.';
    }
  }
}
