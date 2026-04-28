import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:halaph/models/user.dart';
import 'package:halaph/services/favorites_service.dart';
import 'package:halaph/services/firebase_app_service.dart';
import 'package:halaph/services/simple_plan_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

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
    if (email.isNotEmpty && password.isNotEmpty) {
      final firebaseUser = await _signInWithFirebase(email, password);
      if (firebaseUser != null) {
        return _toAppUser(firebaseUser);
      }
    }
    return null;
  }

  Future<User?> register(String email, String password, {String? name}) async {
    if (email.isEmpty || password.isEmpty) return null;
    final firebaseUser = await _registerWithFirebase(email, password, name);
    if (firebaseUser != null) {
      return _toAppUser(firebaseUser, fallbackName: name);
    }
    return null;
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

  Future<void> logout() async {
    if (await FirebaseAppService.initialize()) {
      await firebase_auth.FirebaseAuth.instance.signOut();
    }
    SimplePlanService.resetCache();
    FavoritesService().clearCache();
  }

  Future<firebase_auth.User?> _getFirebaseUser() async {
    if (!await FirebaseAppService.initialize()) return null;
    return firebase_auth.FirebaseAuth.instance.currentUser;
  }

  Future<firebase_auth.User?> _signInWithFirebase(
    String email,
    String password,
  ) async {
    if (!await FirebaseAppService.initialize()) return null;
    try {
      final credential = await firebase_auth.FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      return credential.user;
    } on firebase_auth.FirebaseAuthException catch (error) {
      debugPrint('Firebase login failed: ${error.code}');
      return null;
    } catch (error) {
      debugPrint('Firebase login failed: $error');
      return null;
    }
  }

  Future<firebase_auth.User?> _registerWithFirebase(
    String email,
    String password,
    String? name,
  ) async {
    if (!await FirebaseAppService.initialize()) return null;
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
      debugPrint('Firebase registration failed: ${error.code}');
      return null;
    } catch (error) {
      debugPrint('Firebase registration failed: $error');
      return null;
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
    );
  }
}
