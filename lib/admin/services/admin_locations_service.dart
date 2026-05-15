import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/admin_location.dart';

class AdminLocationsService {
  final FirebaseFirestore _firestore;

  AdminLocationsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('admin_locations');

  Stream<List<AdminLocation>> watchLocations() {
    return _collection.orderBy('priority').snapshots().map((snapshot) {
      final locations =
          snapshot.docs.map(AdminLocation.fromSnapshot).toList(growable: false);
      final sorted = [...locations]..sort((a, b) {
          final priorityCompare = a.priority.compareTo(b.priority);
          if (priorityCompare != 0) return priorityCompare;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      return sorted;
    });
  }

  Future<void> createLocation({
    required AdminLocation location,
    required String actorUid,
  }) async {
    final doc = await _collection.add(location.toCreateMap(actorUid: actorUid));
    debugPrint(
        'Admin featured toggle changed: ${doc.id} ${location.isFeatured}');
    debugPrint(
      'Admin existing place featured fields saved: ${doc.id}',
    );
    debugPrint(
      'Admin featured priority saved: ${doc.id} ${location.featuredPriority}',
    );
  }

  Future<void> updateLocation({
    required AdminLocation location,
    required String actorUid,
  }) async {
    await _collection
        .doc(location.id)
        .update(location.toUpdateMap(actorUid: actorUid));
    debugPrint(
      'Admin featured toggle changed: ${location.id} ${location.isFeatured}',
    );
    debugPrint(
      'Admin existing place featured fields saved: ${location.id}',
    );
    debugPrint(
      'Admin featured priority saved: ${location.id} ${location.featuredPriority}',
    );
  }

  Future<void> setActive({
    required String locationId,
    required bool isActive,
    required String actorUid,
  }) async {
    await _collection.doc(locationId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actorUid,
    });
  }

  Future<void> setFeatured({
    required String locationId,
    required bool isFeatured,
    required int featuredPriority,
    required String actorUid,
  }) async {
    await _collection.doc(locationId).update({
      'isFeatured': isFeatured,
      'featuredPriority': featuredPriority,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actorUid,
    });
    debugPrint('Admin featured toggle changed: $locationId $isFeatured');
    debugPrint('Admin featured priority saved: $locationId $featuredPriority');
    debugPrint('Admin existing place featured fields saved: $locationId');
  }

  Future<void> deleteLocation({required String locationId}) async {
    debugPrint('Admin delete requested: admin_locations/$locationId');
    debugPrint('Admin delete confirmed: admin_locations/$locationId');
    try {
      await _collection.doc(locationId).delete();
      debugPrint('Admin delete succeeded: admin_locations/$locationId');
    } catch (error) {
      debugPrint('Admin delete failed: admin_locations/$locationId $error');
      rethrow;
    }
  }
}
