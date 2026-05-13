import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:halaph/models/destination.dart';

class UserFeaturedPlacesService {
  static const Duration _timeout = Duration(seconds: 4);

  static Future<List<Destination>> getActiveFeaturedPlaces({
    DestinationCategory? category,
    String query = '',
  }) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('admin_featured_places')
          .where('isActive', isEqualTo: true)
          .get()
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

      return docs
          .map(_toDestination)
          .whereType<Destination>()
          .where((destination) {
        if (category != null && destination.category != category) {
          return false;
        }

        if (queryLower.isEmpty) return true;

        final searchable = [
          destination.name,
          destination.location,
          destination.description,
          destination.tags.join(' '),
        ].join(' ').toLowerCase();

        return searchable.contains(queryLower);
      }).toList(growable: false);
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        return const <Destination>[];
      }
      return const <Destination>[];
    } catch (_) {
      return const <Destination>[];
    }
  }

  static Destination? _toDestination(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    final name = (data['name'] as String?)?.trim() ?? '';
    final city = (data['city'] as String?)?.trim() ?? '';
    final categoryLabel = (data['category'] as String?)?.trim() ?? '';
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
