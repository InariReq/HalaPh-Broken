// FIRESTORE RULES TO ADD (apply manually after review):
//
// Replace existing admin_terminal_routes rule with:
// match /admin_terminal_routes/{routeId} {
//   allow get, list: if true;
//   allow create, update, delete: if isContentAdmin();
// }
//
// Add new collection rule:
// match /route_correction_reports/{reportId} {
//   allow create: if true;
//   allow read, update, delete: if isAdminUid(request.auth.uid);
// }

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../admin/models/admin_terminal_route.dart';

class UserTerminalRouteService {
  final FirebaseFirestore _firestore;

  UserTerminalRouteService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('admin_terminal_routes');

  CollectionReference<Map<String, dynamic>> get _correctionReportsCollection =>
      _firestore.collection('route_correction_reports');

  Stream<List<AdminTerminalRoute>> streamActiveRoutes() {
    return _collection
        .where('status', isEqualTo: 'active')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(AdminTerminalRoute.fromSnapshot)
              .toList(growable: false),
        )
        .transform(
      StreamTransformer<List<AdminTerminalRoute>,
          List<AdminTerminalRoute>>.fromHandlers(
        handleError: (error, stackTrace, sink) {
          if (error is FirebaseException) {
            debugPrint(
              'Terminal routes read failed: ${error.code} ${error.message}',
            );
          } else {
            debugPrint('Terminal routes watch failed: $error');
          }
          sink.add(const <AdminTerminalRoute>[]);
        },
      ),
    );
  }

  Future<List<AdminTerminalRoute>> routesForPlace(String placeName) async {
    final query = placeName.trim().toLowerCase();
    if (query.isEmpty) return const <AdminTerminalRoute>[];

    try {
      final snapshot = await _collection
          .where('status', isEqualTo: 'active')
          .orderBy('updatedAt', descending: true)
          .get();
      return snapshot.docs.map(AdminTerminalRoute.fromSnapshot).where((route) {
        return route.terminalName.toLowerCase().contains(query) ||
            route.destination.toLowerCase().contains(query);
      }).toList(growable: false);
    } on FirebaseException catch (error) {
      debugPrint(
        'Terminal routes place read failed: ${error.code} ${error.message}',
      );
      return const <AdminTerminalRoute>[];
    } catch (error) {
      debugPrint('Terminal routes place read failed: $error');
      return const <AdminTerminalRoute>[];
    }
  }

  Future<void> submitCorrection({
    required String routeId,
    required String routeName,
    required String terminalName,
    required String destination,
    required String correctionNote,
    String? submittedByUid,
  }) async {
    try {
      await _correctionReportsCollection.add({
        'routeId': routeId,
        'routeName': routeName,
        'terminalName': terminalName,
        'destination': destination,
        'correctionNote': correctionNote,
        'submittedByUid': submittedByUid?.trim().isNotEmpty == true
            ? submittedByUid!.trim()
            : 'anonymous',
        'submittedAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      debugPrint('Terminal route correction submit failed: $error');
      rethrow;
    }
  }
}
