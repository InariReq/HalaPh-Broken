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

  Future<List<SponsoredAd>> loadSponsoredCards() async {
    try {
      final snapshot = await _collection
          .where('isActive', isEqualTo: true)
          .get()
          .timeout(_readTimeout);
      final now = DateTime.now();
      final ads = snapshot.docs.map(SponsoredAd.fromSnapshot).where((ad) {
        return ad.isActiveFor(now);
      }).toList()
        ..sort((a, b) {
          final priorityCompare = a.priority.compareTo(b.priority);
          if (priorityCompare != 0) return priorityCompare;
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
      return ads;
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
