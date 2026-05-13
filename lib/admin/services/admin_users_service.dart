import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin_user.dart';

class AdminUsersService {
  final FirebaseFirestore _firestore;

  AdminUsersService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('admin_users');

  Stream<List<AdminUser>> watchAdminUsers() {
    return _collection.orderBy('email').snapshots().map(
          (snapshot) =>
              snapshot.docs.map(AdminUser.fromSnapshot).toList(growable: false),
        );
  }

  Future<void> createAdminUser({
    required AdminUser adminUser,
    required String actorUid,
  }) async {
    await _collection
        .doc(adminUser.uid)
        .set(adminUser.toCreateMap(actorUid: actorUid));
  }

  Future<void> updateAdminUser({
    required AdminUser adminUser,
    required String actorUid,
  }) async {
    await _collection
        .doc(adminUser.uid)
        .update(adminUser.toUpdateMap(actorUid: actorUid));
  }

  Future<void> setActive({
    required String uid,
    required bool isActive,
    required String actorUid,
  }) async {
    await _collection.doc(uid).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actorUid,
    });
  }
}
