// FIRESTORE RULES NOTE (Phase 1):
// Collection: admin_terminal_routes
// Rules needed (apply separately after admin review, do not add now):
//   Admin read/write: allow read, write: if request.auth != null && isAdmin();
//   Public read (Phase 2+ only): allow read: if true;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/admin_terminal_route.dart';

class AdminTerminalRouteService {
  final FirebaseFirestore _firestore;

  AdminTerminalRouteService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('admin_terminal_routes');

  Stream<List<AdminTerminalRoute>> streamAll() {
    return _collection.orderBy('updatedAt', descending: true).snapshots().map(
        (snapshot) => snapshot.docs
            .map(AdminTerminalRoute.fromSnapshot)
            .toList(growable: false));
  }

  Future<void> addRoute(AdminTerminalRoute route) async {
    await _collection.add(route.toCreateMap());
  }

  Future<void> updateRoute(AdminTerminalRoute route) async {
    await _collection.doc(route.id).update(route.toUpdateMap());
  }

  Future<void> deleteRoute(String id) async {
    debugPrint('Admin delete requested: admin_terminal_routes/$id');
    debugPrint('Admin delete confirmed: admin_terminal_routes/$id');
    try {
      await _collection.doc(id).delete();
      debugPrint('Admin delete succeeded: admin_terminal_routes/$id');
    } catch (error) {
      debugPrint('Admin delete failed: admin_terminal_routes/$id $error');
      rethrow;
    }
  }

  Future<AdminTerminalRoute?> fetchById(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return AdminTerminalRoute.fromSnapshot(doc);
  }
}
