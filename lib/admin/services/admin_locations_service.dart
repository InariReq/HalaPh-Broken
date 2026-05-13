import 'package:cloud_firestore/cloud_firestore.dart';

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
    await _collection.add(location.toCreateMap(actorUid: actorUid));
  }

  Future<void> updateLocation({
    required AdminLocation location,
    required String actorUid,
  }) async {
    await _collection
        .doc(location.id)
        .update(location.toUpdateMap(actorUid: actorUid));
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
}
