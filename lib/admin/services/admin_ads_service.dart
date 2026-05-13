import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin_ad.dart';

class AdminAdsService {
  final FirebaseFirestore _firestore;

  AdminAdsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('admin_ads');

  Stream<List<AdminAd>> watchAds() {
    return _collection.orderBy('priority').snapshots().map((snapshot) {
      final ads =
          snapshot.docs.map(AdminAd.fromSnapshot).toList(growable: false);
      final sorted = [...ads]..sort((a, b) {
          final priorityCompare = a.priority.compareTo(b.priority);
          if (priorityCompare != 0) return priorityCompare;
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
      return sorted;
    });
  }

  Future<void> createAd({
    required AdminAd ad,
    required String actorUid,
  }) async {
    await _collection.add(ad.toCreateMap(actorUid: actorUid));
  }

  Future<void> updateAd({
    required AdminAd ad,
    required String actorUid,
  }) async {
    await _collection.doc(ad.id).update(ad.toUpdateMap(actorUid: actorUid));
  }

  Future<void> setActive({
    required String adId,
    required bool isActive,
    required String actorUid,
  }) async {
    await _collection.doc(adId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actorUid,
    });
  }
}
