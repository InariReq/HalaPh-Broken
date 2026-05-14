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
    debugPrint('Sponsored ads query started');
    return _collection.snapshots().map((snapshot) {
      return _filterAndSortSponsoredAds(snapshot.docs);
    }).handleError((error) {
      if (error is FirebaseException && error.code == 'permission-denied') {
        debugPrint('Sponsored ads permission-denied: ${error.message}');
      } else {
        debugPrint('Sponsored ads watch failed: $error');
      }
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
        final skipReason = _skipReason(ad, placement, now);
        if (skipReason == null) {
          ads.add(ad);
        } else {
          debugPrint('Skipping admin ad ${doc.id}: $skipReason');
        }
      } catch (error) {
        debugPrint('Skipping admin ad ${doc.id}: invalid data: $error');
      }
    }

    ads.sort((a, b) {
      final priorityCompare = a.priority.compareTo(b.priority);
      if (priorityCompare != 0) return priorityCompare;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    debugPrint('Sponsored ads loaded: ${ads.length}');
    return ads;
  }

  String? _skipReason(SponsoredAd ad, String placement, DateTime now) {
    if (!ad.isActive) {
      return 'inactive or status is not active';
    }
    if (!ad.matchesPlacement(placement)) {
      return 'placement "${ad.placement}" does not match $placement';
    }
    final starts = ad.startsAt;
    if (starts != null && starts.isAfter(now)) {
      return 'startsAt is in the future';
    }
    final ends = ad.endsAt;
    if (ends != null && ends.isBefore(now)) {
      return 'endsAt is in the past';
    }
    return null;
  }

  Future<List<SponsoredAd>> loadFullscreenAds() async {
    try {
      debugPrint('Sponsored ads query started');
      final snapshot = await _collection
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
        debugPrint('Fullscreen ads permission-denied: ${error.message}');
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
      debugPrint('Sponsored ads query started');
      final snapshot = await _collection
          .get(const GetOptions(source: Source.server))
          .timeout(_readTimeout);
      return _filterAndSortSponsoredAds(snapshot.docs);
    } on TimeoutException catch (error) {
      debugPrint('Sponsored ads read timed out: $error');
      return const [];
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        debugPrint('Sponsored ads permission-denied: ${error.message}');
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
