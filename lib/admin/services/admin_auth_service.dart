import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../models/admin_user.dart';

class AdminAuthState {
  final firebase_auth.User? firebaseUser;
  final AdminUser? adminUser;
  final bool loading;
  final String? error;

  const AdminAuthState({
    required this.firebaseUser,
    required this.adminUser,
    this.loading = false,
    this.error,
  });

  bool get isSignedIn => firebaseUser != null;
  bool get isActiveAdmin => adminUser != null && adminUser!.isActive;
}

class AdminAuthService {
  final firebase_auth.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AdminAuthService({
    firebase_auth.FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? firebase_auth.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<AdminAuthState> watchAdminState() {
    return _auth.authStateChanges().asyncMap((user) async {
      if (user == null) {
        return const AdminAuthState(firebaseUser: null, adminUser: null);
      }
      try {
        final doc =
            await _firestore.collection('admin_users').doc(user.uid).get();
        if (!doc.exists) {
          return AdminAuthState(
            firebaseUser: user,
            adminUser: null,
            error: 'access-denied',
          );
        }
        return AdminAuthState(
          firebaseUser: user,
          adminUser: AdminUser.fromSnapshot(doc),
        );
      } catch (_) {
        return AdminAuthState(
          firebaseUser: user,
          adminUser: null,
          error: 'admin-check-failed',
        );
      }
    });
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();
}
