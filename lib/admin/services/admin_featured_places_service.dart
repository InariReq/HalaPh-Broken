import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin_featured_place.dart';

class AdminFeaturedPlacesService {
  final FirebaseFirestore _firestore;

  AdminFeaturedPlacesService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('admin_featured_places');

  Stream<List<AdminFeaturedPlace>> watchFeaturedPlaces() {
    return _collection.orderBy('priority').snapshots().map((snapshot) {
      final places = snapshot.docs
          .map(AdminFeaturedPlace.fromSnapshot)
          .toList(growable: false);
      final sorted = [...places]..sort((a, b) {
          final priorityCompare = a.priority.compareTo(b.priority);
          if (priorityCompare != 0) return priorityCompare;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      return sorted;
    });
  }

  Future<void> createFeaturedPlace({
    required AdminFeaturedPlace place,
    required String actorUid,
  }) async {
    await _collection.add(place.toCreateMap(actorUid: actorUid));
  }

  Future<void> updateFeaturedPlace({
    required AdminFeaturedPlace place,
    required String actorUid,
  }) async {
    await _collection
        .doc(place.id)
        .update(place.toUpdateMap(actorUid: actorUid));
  }

  Future<void> setActive({
    required String placeId,
    required bool isActive,
    required String actorUid,
  }) async {
    await _collection.doc(placeId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actorUid,
    });
  }
}
