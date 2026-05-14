import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:halaph/models/destination.dart';

class UserFeaturedPlacesService {
  static const Duration _timeout = Duration(seconds: 4);

  static Future<List<Destination>> getActiveFeaturedPlaces({
    DestinationCategory? category,
    String query = '',
  }) async {
    try {
      debugPrint('Featured places query started');
      final snapshot = await FirebaseFirestore.instance
          .collection('admin_featured_places')
          .get(const GetOptions(source: Source.server))
          .timeout(_timeout);

      final docs = [...snapshot.docs]..sort((a, b) {
          final priorityCompare = _readPriority(a.data()['priority']).compareTo(
            _readPriority(b.data()['priority']),
          );
          if (priorityCompare != 0) return priorityCompare;

          final aName = ((a.data()['name'] as String?) ?? '').toLowerCase();
          final bName = ((b.data()['name'] as String?) ?? '').toLowerCase();
          return aName.compareTo(bName);
        });

      final queryLower = query.trim().toLowerCase();
      final now = DateTime.now();
      final places = <Destination>[];

      for (final doc in docs) {
        final skipReason = _skipReason(doc, now);
        if (skipReason != null) {
          debugPrint('Skipping featured place ${doc.id}: $skipReason');
          continue;
        }

        final destination = _toDestination(doc);
        if (destination == null) {
          debugPrint(
            'Skipping featured place ${doc.id}: missing name, city/location, or category',
          );
          continue;
        }

        if (category != null && destination.category != category) {
          debugPrint(
            'Skipping featured place ${doc.id}: category does not match selected filter',
          );
          continue;
        }

        if (queryLower.isNotEmpty) {
          final searchable = [
            destination.name,
            destination.location,
            destination.description,
            destination.tags.join(' '),
          ].join(' ').toLowerCase();

          if (!searchable.contains(queryLower)) {
            debugPrint(
              'Skipping featured place ${doc.id}: query "$query" did not match',
            );
            continue;
          }
        }

        places.add(destination);
      }

      debugPrint('Featured places loaded: ${places.length}');
      return places.toList(growable: false);
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        debugPrint('Featured places permission-denied: ${error.message}');
        return const <Destination>[];
      }
      debugPrint('Featured places read failed: ${error.code}');
      return const <Destination>[];
    } catch (error) {
      debugPrint('Featured places read failed: $error');
      return const <Destination>[];
    }
  }

  static Destination? _toDestination(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    final name = (data['name'] as String?)?.trim() ?? '';
    final city = _stringValue(
      data['city'] ?? data['location'] ?? data['address'],
    );
    final categoryLabel = _stringValue(data['category'] ?? data['type']);
    final description = (data['description'] as String?)?.trim() ?? '';
    final imageUrl = (data['imageUrl'] as String?)?.trim() ?? '';
    final priority = _readPriority(data['priority']);

    if (name.isEmpty || city.isEmpty || categoryLabel.isEmpty) {
      return null;
    }

    return Destination(
      id: 'admin-featured-${doc.id}',
      name: name,
      description: description,
      location: city,
      coordinates: null,
      imageUrl: imageUrl,
      category: _mapCategory(categoryLabel),
      rating: 0.0,
      tags: [
        'Featured',
        'Admin Featured',
        categoryLabel,
        city,
        'priority:$priority',
      ].where((tag) => tag.trim().isNotEmpty).toList(growable: false),
    );
  }

  static int _readPriority(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return 10;
  }

  static String? _skipReason(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    DateTime now,
  ) {
    final data = doc.data();
    if (!_isActive(data)) {
      return 'inactive or status is not active';
    }

    final startsAt = _timestampToDate(data['startsAt']);
    if (startsAt != null && startsAt.isAfter(now)) {
      return 'startsAt is in the future';
    }

    final endsAt = _timestampToDate(data['endsAt']);
    if (endsAt != null && endsAt.isBefore(now)) {
      return 'endsAt is in the past';
    }

    return null;
  }

  static bool _isActive(Map<String, dynamic> data) {
    final isActive = data['isActive'];
    if (isActive is bool) return isActive;

    final active = data['active'];
    if (active is bool) return active;

    final status = data['status'];
    if (status is String) {
      final normalized = status.trim().toLowerCase();
      if (normalized == 'active' ||
          normalized == 'enabled' ||
          normalized == 'live' ||
          normalized == 'published') {
        return true;
      }
      if (normalized == 'inactive' ||
          normalized == 'disabled' ||
          normalized == 'draft' ||
          normalized == 'expired') {
        return false;
      }
    }

    return false;
  }

  static String _stringValue(Object? value) {
    if (value is! String) return '';
    return value.trim();
  }

  static DateTime? _timestampToDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static DestinationCategory _mapCategory(String value) {
    final normalized = value.trim().toLowerCase();
    return switch (normalized) {
      'malls' || 'mall' => DestinationCategory.malls,
      'food' || 'restaurant' || 'cafe' => DestinationCategory.food,
      'park' || 'parks' => DestinationCategory.park,
      'museum' || 'museums' => DestinationCategory.museum,
      'activity' || 'activities' => DestinationCategory.activities,
      'landmark' ||
      'destination' ||
      'tourist spot' ||
      'other' =>
        DestinationCategory.landmark,
      _ => DestinationCategory.landmark,
    };
  }
}
