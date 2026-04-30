import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/services/place_cache_service.dart';
import 'package:http/http.dart' as http;

class GooglePlacesService {
  static const _placesBase = 'https://places.googleapis.com/v1';
  static const _dartPlacesKey = String.fromEnvironment('GOOGLE_PLACES_API_KEY');
  static const _dartMapsKey = String.fromEnvironment('MAPS_API_KEY');
  static const _fieldMask =
      'places.id,places.displayName,places.formattedAddress,places.location,'
      'places.types,places.rating,places.userRatingCount,places.photos,'
      'places.priceLevel,places.googleMapsUri';
  static const _detailsFieldMask =
      'id,displayName,formattedAddress,location,types,rating,userRatingCount,'
      'photos,priceLevel,googleMapsUri';

  static bool _temporarilyDisabled = false;
  static String? _lastFailureMessage;

  static bool get isConfigured => _apiKey().isNotEmpty;
  static bool get canAttemptRequests => isConfigured && !_temporarilyDisabled;
  static String? get lastFailureMessage => _lastFailureMessage;

  static Future<List<Destination>> searchText({
    required String query,
    LatLng? location,
    int limit = 12,
    double radiusMeters = 25000,
  }) async {
    final key = _apiKey();
    if (key.isEmpty || query.trim().isEmpty || _temporarilyDisabled) {
      return const <Destination>[];
    }

    // Try cache first
    final locationKey = location != null
        ? PlaceCacheService.generateLocationKey(
            location.latitude, location.longitude)
        : 'no_location';
    final cached = await PlaceCacheService.getCachedSearch(query, locationKey);
    if (cached.isNotEmpty) {
      debugPrint('Google Places: Using cached results for "$query"');
      return cached
          .map((item) => Destination.fromJson(item))
          .toList();
    }

    try {
      final body = <String, dynamic>{
        'textQuery': query,
        'pageSize': limit.clamp(1, 20),
        'regionCode': 'PH',
        'languageCode': 'en',
        if (location != null)
          'locationBias': {
            'circle': {
              'center': {
                'latitude': location.latitude,
                'longitude': location.longitude,
              },
              'radius': radiusMeters,
            },
          },
      };

      final response = await http
          .post(
            Uri.parse('$_placesBase/places:searchText'),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': key,
              'X-Goog-FieldMask': _fieldMask,
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        _recordFailure('Text Search', response);
        return const <Destination>[];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final places = data['places'] as List? ?? const [];
      final results = places
          .whereType<Map>()
          .map((place) => _placeToDestination(Map<String, dynamic>.from(place)))
          .toList(growable: false);

      // Cache the results
      final jsonResults = results.map((d) => d.toJson()).toList();
      await PlaceCacheService.cacheSearch(
          query, locationKey, jsonResults);

      return results;
    } catch (error) {
      debugPrint('Google Places Text Search error: $error');
      return const <Destination>[];
    }
  }

  static Future<List<Destination>> searchNearby({
    required LatLng location,
    required String includedType,
    int limit = 12,
    double radiusMeters = 15000,
  }) async {
    final key = _apiKey();
    if (key.isEmpty || includedType.trim().isEmpty || _temporarilyDisabled) {
      return const <Destination>[];
    }

    // Try cache first
    final locationKey = PlaceCacheService.generateLocationKey(
        location.latitude, location.longitude);
    final cacheKey = 'nearby_${includedType}_$locationKey';
    final cached = await PlaceCacheService.getCachedSearch(cacheKey, locationKey);
    if (cached.isNotEmpty) {
      debugPrint('Google Places: Using cached nearby results for "$includedType"');
      return cached
          .map((item) => Destination.fromJson(item))
          .toList();
    }

    try {
      final body = <String, dynamic>{
        'includedTypes': [includedType],
        'maxResultCount': limit.clamp(1, 20),
        'rankPreference': 'POPULARITY',
        'regionCode': 'PH',
        'languageCode': 'en',
        'locationRestriction': {
          'circle': {
            'center': {
              'latitude': location.latitude,
              'longitude': location.longitude,
            },
            'radius': radiusMeters,
          },
        },
      };

      final response = await http
          .post(
            Uri.parse('$_placesBase/places:searchNearby'),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': key,
              'X-Goog-FieldMask': _fieldMask,
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        _recordFailure('Nearby Search', response);
        return const <Destination>[];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final places = data['places'] as List? ?? const [];
      final results = places
          .whereType<Map>()
          .map((place) => _placeToDestination(Map<String, dynamic>.from(place)))
          .toList(growable: false);

      // Cache the results
      final jsonResults = results.map((d) => d.toJson()).toList();
      await PlaceCacheService.cacheSearch(
          cacheKey, locationKey, jsonResults);

      return results;
    } catch (error) {
      debugPrint('Google Places Nearby Search error: $error');
      return const <Destination>[];
    }
  }

  static Future<Destination?> getPlaceById(String placeId) async {
    final key = _apiKey();
    final id = placeId.trim();
    if (key.isEmpty || id.isEmpty || _temporarilyDisabled) return null;

    try {
      final response = await http
          .get(
            Uri.parse('$_placesBase/places/$id'),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': key,
              'X-Goog-FieldMask': _detailsFieldMask,
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        _recordFailure('Place Details', response);
        return null;
      }

      return _placeToDestination(jsonDecode(response.body));
    } catch (error) {
      debugPrint('Google Place Details error: $error');
      return null;
    }
  }

  static Destination _placeToDestination(Map<String, dynamic> place) {
    final id = (place['id'] ?? '').toString();
    final displayName = place['displayName'] as Map<String, dynamic>? ?? {};
    final name = (displayName['text'] ?? 'Unknown Place').toString();
    final formattedAddress = (place['formattedAddress'] ?? 'Philippines')
        .toString();
    final location = place['location'] as Map<String, dynamic>? ?? {};
    final latitude = (location['latitude'] as num?)?.toDouble();
    final longitude = (location['longitude'] as num?)?.toDouble();
    final types = (place['types'] as List? ?? const [])
        .whereType<String>()
        .toList(growable: false);
    final category = _categoryFromTypes(types);
    final rating = (place['rating'] as num?)?.toDouble() ?? 4.0;
    final reviewCount = (place['userRatingCount'] as num?)?.toInt() ?? 0;
    final photos = place['photos'] as List? ?? const [];
    final photo = photos.whereType<Map>().firstOrNull;
    final photoName = photo?['name']?.toString();

    return Destination(
      id: id.isNotEmpty ? 'google_$id' : 'google_${name.hashCode}',
      name: name,
      description: _description(name, category, rating, reviewCount),
      location: formattedAddress,
      coordinates: latitude != null && longitude != null
          ? LatLng(latitude, longitude)
          : null,
      imageUrl: _photoUrl(photoName) ?? '',
      category: category,
      rating: rating,
      tags: [
        'google_place',
        ...types,
        if (reviewCount > 0) 'reviews:$reviewCount',
        if (place['googleMapsUri'] != null) 'maps:${place['googleMapsUri']}',
      ],
      budget: BudgetInfo(minCost: 0, maxCost: 1000, currency: 'PHP'),
    );
  }

  static String? _photoUrl(String? photoName) {
    final key = _apiKey();
    if (key.isEmpty || photoName == null || photoName.trim().isEmpty) {
      return null;
    }

    return '$_placesBase/${Uri.encodeFull(photoName)}/media'
        '?maxWidthPx=900&key=${Uri.encodeQueryComponent(key)}';
  }

  static DestinationCategory _categoryFromTypes(List<String> types) {
    if (types.any(
      (type) =>
          type.contains('restaurant') ||
          type.contains('food') ||
          type.contains('cafe') ||
          type.contains('bakery') ||
          type.contains('meal'),
    )) {
      return DestinationCategory.food;
    }
    if (types.any(
      (type) =>
          type.contains('shopping_mall') ||
          type.contains('store') ||
          type.contains('market'),
    )) {
      return DestinationCategory.market;
    }
    if (types.any((type) => type.contains('park'))) {
      return DestinationCategory.park;
    }
    if (types.any(
      (type) => type.contains('museum') || type.contains('art_gallery'),
    )) {
      return DestinationCategory.museum;
    }
    if (types.any(
      (type) =>
          type.contains('tourist_attraction') ||
          type.contains('landmark') ||
          type.contains('place_of_worship'),
    )) {
      return DestinationCategory.landmark;
    }
    return DestinationCategory.activities;
  }

  static String _description(
    String name,
    DestinationCategory category,
    double rating,
    int reviewCount,
  ) {
    final kind = switch (category) {
      DestinationCategory.food => 'food and cafe spot',
      DestinationCategory.market => 'shopping destination',
      DestinationCategory.park => 'park and outdoor spot',
      DestinationCategory.museum => 'museum and culture spot',
      DestinationCategory.landmark => 'local landmark',
      DestinationCategory.activities => 'activity spot',
    };
    final reviewText = reviewCount > 0
        ? '${rating.toStringAsFixed(1)} rating from $reviewCount Google reviews'
        : 'listed on Google Maps';
    return '$name is a $kind, $reviewText.';
  }

  static String _apiKey() {
    if (_dartPlacesKey.isNotEmpty) return _dartPlacesKey;
    if (_dartMapsKey.isNotEmpty) return _dartMapsKey;
    try {
      return (dotenv.env['GOOGLE_PLACES_API_KEY'] ??
              dotenv.env['MAPS_API_KEY'] ??
              '')
          .trim();
    } catch (_) {
      return '';
    }
  }

  static void _recordFailure(String operation, http.Response response) {
    final message = _failureMessage(response);
    _lastFailureMessage = '$operation failed: $message';
    debugPrint('Google Places $_lastFailureMessage');

    final lower = message.toLowerCase();
    if (response.statusCode == 403 &&
        (lower.contains('billing') ||
            lower.contains('permission_denied') ||
            lower.contains('api has not been used') ||
            lower.contains('disabled'))) {
      _temporarilyDisabled = true;
      debugPrint(
        'Google Places disabled for this app run; falling back to open data.',
      );
    }
  }

  static String _failureMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final error = data['error'] as Map<String, dynamic>?;
      final status = error?['status']?.toString();
      final message = error?['message']?.toString();
      return [
        response.statusCode.toString(),
        if (status != null && status.isNotEmpty) status,
        if (message != null && message.isNotEmpty) message,
      ].join(' ');
    } catch (_) {
      return response.statusCode.toString();
    }
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
