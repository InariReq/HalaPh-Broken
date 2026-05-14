import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:halaph/models/sponsored_ad.dart';

class UserAdsService {
  static const Duration _readTimeout = Duration(seconds: 4);

  final FirebaseFirestore _firestore;

  UserAdsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(SponsoredAd.collectionPath);

  Stream<List<SponsoredAd>> watchSponsoredCards() {
    return _collection
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return _filterAndSortSponsoredAds(snapshot.docs);
    }).handleError((error) {
      debugPrint('Sponsored ads watch failed: $error');
      return const <SponsoredAd>[];
    });
  }

  List<SponsoredAd> _filterAndSortSponsoredAds(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return _filterAndSortAds(docs, SponsoredAd.sponsoredCardPlacement);
  }

  List<SponsoredAd> _filterAndSortFullscreenAds(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return _filterAndSortAds(docs, SponsoredAd.fullscreenPlacement);
  }

  List<SponsoredAd> _filterAndSortAds(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String placement,
  ) {
    final now = DateTime.now();
    final ads = <SponsoredAd>[];

    for (final doc in docs) {
      try {
        final ad = SponsoredAd.fromSnapshot(doc);
        if (ad.isActiveForPlacement(placement, now)) {
          ads.add(ad);
        }
      } catch (error) {
        debugPrint('Skipping invalid admin ad ${doc.id}: $error');
      }
    }

    ads.sort((a, b) {
      final priorityCompare = a.priority.compareTo(b.priority);
      if (priorityCompare != 0) return priorityCompare;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    return ads;
  }

  Future<List<SponsoredAd>> loadFullscreenAds() async {
    try {
      final snapshot = await _collection
          .where('isActive', isEqualTo: true)
          .get(const GetOptions(source: Source.server))
          .timeout(_readTimeout);
      final ads = _filterAndSortFullscreenAds(snapshot.docs);
      debugPrint('Fullscreen ads loaded: ${ads.length}');
      return ads;
    } on TimeoutException catch (error) {
      debugPrint('Fullscreen ads read timed out: $error');
      return const [];
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        debugPrint('Fullscreen ads read denied; hiding ads.');
      } else {
        debugPrint('Fullscreen ads read failed: ${error.code}');
      }
      return const [];
    } on FormatException catch (error) {
      debugPrint('Fullscreen ads data invalid; hiding ads: $error');
      return const [];
    } catch (error) {
      debugPrint('Fullscreen ads read failed: $error');
      return const [];
    }
  }

  Future<List<SponsoredAd>> loadSponsoredCards() async {
    try {
      final snapshot = await _collection
          .where('isActive', isEqualTo: true)
          .get(const GetOptions(source: Source.server))
          .timeout(_readTimeout);
      return _filterAndSortSponsoredAds(snapshot.docs);
    } on TimeoutException catch (error) {
      debugPrint('Sponsored ads read timed out: $error');
      return const [];
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        debugPrint('Sponsored ads read denied; hiding ads.');
      } else {
        debugPrint('Sponsored ads read failed: ${error.code}');
      }
      return const [];
    } on FormatException catch (error) {
      debugPrint('Sponsored ads data invalid; hiding ads: $error');
      return const [];
    } catch (error) {
      debugPrint('Sponsored ads read failed: $error');
      return const [];
    }
  }
}
