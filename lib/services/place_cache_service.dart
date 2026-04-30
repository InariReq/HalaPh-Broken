import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class PlaceCacheService {
  static const cacheDuration = Duration(hours: 24); // Cache for 24 hours

  static Future<List<Map<String, dynamic>>> getCachedSearch(
    String query,
    String locationKey,
  ) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('places_cache')
          .doc('${query}_$locationKey')
          .get();
      if (!doc.exists) return [];
      final data = doc.data()!;
      final expiresAt = data['expiresAt'] as Timestamp?;
      if (expiresAt != null &&
          expiresAt.toDate().isBefore(DateTime.now())) {
        return []; // Cache expired
      }
      return List<Map<String, dynamic>>.from(data['results'] ?? []);
    } catch (e) {
      debugPrint('PlaceCache: Read error: $e');
      return [];
    }
  }

  static Future<void> cacheSearch(
    String query,
    String locationKey,
    List<Map<String, dynamic>> results,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('places_cache')
          .doc('${query}_$locationKey')
          .set({
        'query': query,
        'locationKey': locationKey,
        'results': results,
        'cachedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(cacheDuration),
        ),
      });
      debugPrint('PlaceCache: Cached "${query}_$locationKey" (${results.length} items)');
    } catch (e) {
      debugPrint('PlaceCache: Write error: $e');
    }
  }

  static String generateLocationKey(double lat, double lng) {
    return '${lat.toStringAsFixed(3)}_${lng.toStringAsFixed(3)}';
  }

  static Future<void> clearExpiredCache() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('places_cache')
          .where('expiresAt', isLessThan: Timestamp.now())
          .get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
      debugPrint('PlaceCache: Cleared ${snapshot.docs.length} expired entries');
    } catch (e) {
      debugPrint('PlaceCache: Clear error: $e');
    }
  }
}
