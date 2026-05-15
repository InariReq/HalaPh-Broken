import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/services/google_maps_service.dart';
import 'package:halaph/utils/place_display_name_utils.dart';

class UserAdminLocationsService {
  static const Duration _timeout = Duration(seconds: 4);

  static Future<List<Destination>> getActiveLocations({
    DestinationCategory? category,
    String query = '',
  }) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('admin_locations')
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
    } on FirebaseException {
      return const <Destination>[];
    } catch (_) {
      return const <Destination>[];
    }
  }

  static Destination? _toDestination(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    final source = ((data['source'] as String?) ?? '').trim().toLowerCase();
    final name = PlaceDisplayNameUtils.resolveDisplayName(
      data,
      cleanRawName: source == 'google',
    );
    final city = (data['city'] as String?)?.trim() ?? '';
    final province = (data['province'] as String?)?.trim() ?? '';
    final categoryLabel = (data['category'] as String?)?.trim() ?? '';
    final description = (data['description'] as String?)?.trim() ?? '';
    final priority = _readPriority(data['priority']);

    if (name.isEmpty || city.isEmpty || categoryLabel.isEmpty) return null;

    final locationLabel = province.isEmpty ? city : '$city, $province';
    final fallbackDescription = province.isEmpty ? city : '$city, $province';
    final latitude = _readDouble(data['latitude']);
    final longitude = _readDouble(data['longitude']);
    final imageUrl = _resolveImageUrl(data, name);

    return Destination(
      id: 'admin-location-${doc.id}',
      name: name,
      description: description.isEmpty ? fallbackDescription : description,
      location: locationLabel,
      coordinates: latitude == null || longitude == null
          ? null
          : LatLng(latitude, longitude),
      imageUrl: imageUrl,
      category: _mapCategory(categoryLabel),
      rating: 0.0,
      tags: [
        'Admin Location',
        categoryLabel,
        city,
        province,
        'priority:$priority',
      ].where((tag) => tag.trim().isNotEmpty).toList(growable: false),
    );
  }

  static int _readPriority(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return 10;
  }

  static double? _readDouble(Object? value) {
    if (value is num) return value.toDouble();
    return null;
  }

  static String _resolveImageUrl(Map<String, dynamic> data, String name) {
    for (final entry in <String, Object?>{
      'imageUrl': data['imageUrl'],
      'image': data['image'],
      'image_url': data['image_url'],
      'photoUrl': data['photoUrl'],
      'photoURL': data['photoURL'],
      'thumbnailUrl': data['thumbnailUrl'],
      'thumbnail': data['thumbnail'],
      'coverImageUrl': data['coverImageUrl'],
      'bannerImage': data['bannerImage'],
      'googlePhotoUrl': data['googlePhotoUrl'],
    }.entries) {
      final value = entry.value;
      if (value is String && value.trim().startsWith('http')) {
        debugPrint('Featured place image resolved from field: ${entry.key}');
        return value.trim();
      }
    }

    final reference = _readPhotoReference(data);
    if (reference.isNotEmpty) {
      final imageUrl = GoogleMapsService.buildPhotoUrl(reference);
      if (imageUrl.isNotEmpty) {
        debugPrint('Google photo URL built: ${data['googlePlaceId'] ?? name}');
        return imageUrl;
      }
    }

    debugPrint('Featured place image missing: $name');
    return '';
  }

  static String _readPhotoReference(Map<String, dynamic> data) {
    for (final field in const [
      'googlePhotoReference',
      'photoReference',
      'photo_reference',
      'google_photo_reference',
    ]) {
      final value = data[field];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }

    final photos = data['photos'];
    if (photos is List && photos.isNotEmpty) {
      final first = photos.first;
      if (first is Map) {
        final value = first['photoReference'] ?? first['photo_reference'];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
    }
    return '';
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
