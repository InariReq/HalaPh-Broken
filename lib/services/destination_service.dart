import 'dart:math';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:halaph/models/destination.dart';

class DestinationService {
  static const LatLng _defaultSearchLocation = LatLng(14.5995, 120.9842);
  static const Duration _locationSearchTimeout = Duration(seconds: 4);
  static const Duration _placesSearchTimeout = Duration(seconds: 10);
  static String get _googleApiKey => (dotenv.env['MAPS_API_KEY'] ?? '').trim();

  static LatLng? _cachedLocation;
  static DateTime? _locationCacheTime;
  static const _cacheValidity = Duration(minutes: 30);
  static bool _useTestLocation = false;
  static LatLng? _manualTestLocation;

  // Popular malls in the Philippines with their coordinates
  static final List<Destination> _popularMalls = [
    Destination(
      id: 'sm_trinoma',
      name: 'SM City Trinoma',
      description: 'Major shopping mall in Quezon City with over 300 shops, restaurants, and a cinema.',
      location: 'EDSA corner North Avenue, Quezon City',
      coordinates: const LatLng(14.6536, 121.0334),
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/7f/Trinoma.jpg/1200px-Trinoma.jpg',
      category: DestinationCategory.malls,
      rating: 4.5,
      tags: ['shopping', 'dining', 'cinema', 'SM Supermalls'],
      
    ),
    Destination(
      id: 'sm_moa',
      name: 'SM Mall of Asia',
      description: 'One of the largest malls in Asia with shopping, dining, entertainment, and an ice skating rink.',
      location: 'Seaside Blvd, Pasay City, Metro Manila',
      coordinates: const LatLng(14.5352, 120.9829),
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4d/SM_Mall_of_Asia.jpg/1200px-SM_Mall_of_Asia.jpg',
      category: DestinationCategory.malls,
      rating: 4.6,
      tags: ['shopping', 'dining', 'entertainment', 'SM Supermalls', 'ice skating'],
      
    ),
    Destination(
      id: 'sm_megamall',
      name: 'SM Megamall',
      description: 'Large shopping mall in Ortigas Center with diverse retail stores and restaurants.',
      location: 'EDSA corner Julia Vargas Avenue, Mandaluyong City',
      coordinates: const LatLng(14.5842, 121.0564),
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3a/SM_Megamall.jpg/1200px-SM_Megamall.jpg',
      category: DestinationCategory.malls,
      rating: 4.5,
      tags: ['shopping', 'dining', 'SM Supermalls'],
      
    ),
    Destination(
      id: 'ayala_glorietta',
      name: 'Ayala Malls Glorietta',
      description: 'Upscale shopping mall complex in Makati with luxury brands and fine dining.',
      location: 'Ayala Center, Makati City',
      coordinates: const LatLng(14.5518, 121.0244),
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e0/Glorietta.jpg/1200px-Glorietta.jpg',
      category: DestinationCategory.malls,
      rating: 4.6,
      tags: ['luxury shopping', 'fine dining', 'Ayala Malls'],
      
    ),
    Destination(
      id: 'robinsons_manila',
      name: 'Robinsons Place Manila',
      description: 'Major shopping mall in Manila with a wide variety of retail and dining options.',
      location: 'Pedro Gil corner Adriatico Street, Manila',
      coordinates: const LatLng(14.5726, 120.9943),
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8d/Robinsons_Place_Manila.jpg/1200px-Robinsons_Place_Manila.jpg',
      category: DestinationCategory.malls,
      rating: 4.4,
      tags: ['shopping', 'dining', 'Robinsons Malls'],
      
    ),
    Destination(
      id: 'sm_north',
      name: 'SM North EDSA',
      description: 'One of the oldest and largest malls in the Philippines located in Quezon City.',
      location: 'EDSA, Quezon City, Metro Manila',
      coordinates: const LatLng(14.6554, 121.0289),
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/f2/SM_North_EDSA.JPG/1200px-SM_North_EDSA.JPG',
      category: DestinationCategory.malls,
      rating: 4.5,
      tags: ['shopping', 'dining', 'cinema', 'SM Supermalls'],
      
    ),
    Destination(
      id: 'greenbelt',
      name: 'Greenbelt Mall',
      description: 'Premium shopping and dining destination in Makati with landscaped gardens.',
      location: 'Ayala Center, Makati City',
      coordinates: const LatLng(14.5500, 121.0255),
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/7c/Greenbelt%2C_Ayala_Center%2C_Makati.jpg/1200px-Greenbelt%2C_Ayala_Center%2C_Makati.jpg',
      category: DestinationCategory.malls,
      rating: 4.7,
      tags: ['luxury shopping', 'fine dining', 'Ayala Malls', 'gardens'],
      
    ),
    Destination(
      id: 'sm_aura',
      name: 'SM Aura Premier',
      description: 'Upscale shopping mall in Taguig with high-end brands and dining options.',
      location: '26th Street corner McKinley Parkway, Bonifacio Global City, Taguig',
      coordinates: const LatLng(14.5493, 121.0505),
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3b/SM_Aura_Premier.jpg/1200px-SM_Aura_Premier.jpg',
      category: DestinationCategory.malls,
      rating: 4.6,
      tags: ['luxury shopping', 'dining', 'SM Supermalls', 'BGC'],
      
    ),
  ];

  static String? get placesProviderError => null;

  static Future<LatLng> getCurrentLocation() async {
    try {
      if (_useTestLocation && _manualTestLocation != null) {
        return _manualTestLocation!;
      }
      final cachedAt = _locationCacheTime;
      if (_cachedLocation != null &&
          cachedAt != null &&
          DateTime.now().difference(cachedAt) < _cacheValidity) {
        return _cachedLocation!;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) return _defaultSearchLocation;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return _defaultSearchLocation;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return _defaultSearchLocation;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      ).timeout(const Duration(seconds: 10));

      _cachedLocation = LatLng(position.latitude, position.longitude);
      _locationCacheTime = DateTime.now();
      return _cachedLocation!;
    } catch (_) {
      return _cachedLocation ?? _defaultSearchLocation;
    }
  }

  static void setTestLocation(double lat, double lng) {
    _useTestLocation = true;
    _manualTestLocation = LatLng(lat, lng);
    debugPrint('Test location set: $lat, $lng');
  }

  static void clearTestLocation() {
    _useTestLocation = false;
    _manualTestLocation = null;
    _cachedLocation = null;
    _locationCacheTime = null;
    debugPrint('Test location cleared');
  }

  static Future<List<Destination>> searchDestinations(String? query) async {
    final trimmed = query?.trim() ?? '';
    final queryLower = trimmed.toLowerCase();
    final hasTypedQuery = trimmed.isNotEmpty;
    final location = await _getSearchLocation();

    // Typed searches should come from Google Places, not hardcoded fallback data.
    // Keep hardcoded malls only for empty/default discovery.
    final List<Destination> allDestinations =
        hasTypedQuery ? <Destination>[] : [..._popularMalls];

    final isMallQuery = queryLower.contains('mall') ||
        queryLower.contains('shopping') ||
        queryLower.contains('sm ') ||
        queryLower.contains('ayala') ||
        queryLower.contains('robinsons') ||
        queryLower.contains('trinoma') ||
        queryLower.contains('megamall') ||
        queryLower.contains('glorietta') ||
        queryLower.contains('greenbelt') ||
        queryLower.contains('aura');

    try {
      final googleResults = await _searchPlaces(
        query: hasTypedQuery ? trimmed : 'tourist attractions in Manila',
        location: location,
        limit: 24,
      ).timeout(_placesSearchTimeout, onTimeout: () => <Destination>[]);

      allDestinations.addAll(googleResults);
    } catch (e) {
      debugPrint('Google search error: $e');
    }

    if (isMallQuery) {
      allDestinations.sort((a, b) {
        if (a.category == DestinationCategory.malls &&
            b.category != DestinationCategory.malls) {
          return -1;
        }
        if (a.category != DestinationCategory.malls &&
            b.category == DestinationCategory.malls) {
          return 1;
        }
        return 0;
      });
    }

    return _rankAndLimit(allDestinations, location, limit: 24);
  }

  static Future<List<Destination>> getTrendingDestinations() async {
    try {
      // Start with popular malls
      final List<Destination> trending = [..._popularMalls];

      final location = await _getSearchLocation();
      final places = await _discoverPlaces(location);
      trending.addAll(places);

      return _rankAndLimit(trending, location, limit: 20);
    } catch (e) {
      debugPrint('Error fetching trending destinations: $e');
      return _popularMalls; // Fallback to malls
    }
  }

  static Future<List<Destination>> searchRealPlaces({
    required String query,
    LatLng? location,
    DestinationCategory? category,
  }) async {
    final searchLocation = location ?? await _getSearchLocation();
    final searchQuery = _queryFor(query, category);
    final places = await _searchPlaces(
      query: searchQuery,
      location: searchLocation,
      limit: 24,
    );
    final filtered = category == null
        ? places
        : places.where((place) => place.category == category).toList();
    return _rankAndLimit(filtered, searchLocation, limit: 24);
  }

  static Future<List<String>> getAutocompleteSuggestions(
    String input, {
    LatLng? location,
  }) async {
    try {
      final trimmed = input.trim();
      if (trimmed.length < 2) return [];
      final searchLocation = location ?? await _getSearchLocation();
      final places = await _searchPlaces(
        query: trimmed,
        location: searchLocation,
        limit: 8,
      );
      final labels = <String>[];
      final seen = <String>{};
      for (final place in places) {
        final label = place.location.trim().isEmpty
            ? place.name
            : '${place.name}, ${place.location}';
        if (seen.add(label.toLowerCase())) {
          labels.add(label);
        }
      }
      return labels.take(6).toList(growable: false);
    } catch (e) {
      debugPrint('Error getting autocomplete: $e');
      return <String>[];
    }
  }

  static List<Destination> deduplicateDestinationsById(List<Destination> list) {
    final seen = <String>{};
    final out = <Destination>[];
    for (final destination in list) {
      if (seen.add(destination.id)) {
        out.add(destination);
      }
    }
    return out;
  }

  static double calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371;
    final lat1Rad = point1.latitude * (pi / 180);
    final lat2Rad = point2.latitude * (pi / 180);
    final deltaLatRad = (point2.latitude - point1.latitude) * (pi / 180);
    final deltaLngRad = (point2.longitude - point1.longitude) * (pi / 180);

    final a =
        sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
            cos(lat1Rad) *
                cos(lat2Rad) *
                sin(deltaLngRad / 2) *
                sin(deltaLngRad / 2);
    final c = 2 * asin(sqrt(a).clamp(0.0, 1.0));
    return earthRadius * c;
  }

  static bool isInvalidLocation(LatLng location) {
    return location.latitude == 0 && location.longitude == 0;
  }

  static String getCategoryName(DestinationCategory category) {
    return switch (category) {
      DestinationCategory.park => 'Parks',
      DestinationCategory.landmark => 'Landmarks',
      DestinationCategory.food => 'Food',
      DestinationCategory.activities => 'Activities',
      DestinationCategory.museum => 'Museums',
      DestinationCategory.malls => 'Malls',
    };
  }

  static Future<List<Destination>> _discoverPlaces(LatLng location) async {
    final isRealLocation = !isInvalidLocation(location);
    final searchLocation = isRealLocation ? location : _defaultSearchLocation;
    final results = <Destination>[];

    // Query for each category to ensure all types appear
    final categoryQueries = [
      'tourist attractions landmarks',
      'restaurants cafes food',
      'parks gardens',
      'museums galleries',
      'shopping malls',
      'activities entertainment',
    ];

    for (final query in categoryQueries) {
      try {
        final places = await _searchPlaces(
          query: query,
          location: searchLocation,
          limit: 8,
        ).timeout(_placesSearchTimeout, onTimeout: () => const <Destination>[]);
        results.addAll(places);
      } catch (e) {
        debugPrint('Error discovering places for query "$query": $e');
      }
    }

    return results;
  }

  static Future<List<Destination>> _searchPlaces({
    required String query,
    required LatLng location,
    required int limit,
  }) async {
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/textsearch/json',
      ).replace(queryParameters: {
        'query': query,
        'location': '${location.latitude},${location.longitude}',
        'radius': '3000',
        'key': _googleApiKey,
        'maxheight': '300',
        'maxwidth': '300',
      });

      final response = await http
          .get(uri)
          .timeout(_placesSearchTimeout, onTimeout: () => throw TimeoutException(''));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          return results
              .map((item) => _convertGooglePlaceToDestination(item, null))
              .whereType<Destination>()
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Google Places search error: $e');
    }
    return <Destination>[];
  }

  static List<Destination> _rankAndLimit(
    List<Destination> places,
    LatLng origin, {
    required int limit,
  }) {
    final deduped = deduplicateDestinationsById(places)
      ..sort(
        (a, b) =>
            _trendingScore(b, origin).compareTo(_trendingScore(a, origin)),
      );
    return deduped.take(limit).toList(growable: false);
  }

  static double _trendingScore(Destination destination, LatLng origin) {
    final reviews =
        destination.tags.contains('popular') ? 500.0 : 50.0;
    final distance = destination.coordinates == null
        ? 12.0
        : calculateDistance(origin, destination.coordinates!);
    final categoryBoost = switch (destination.category) {
      DestinationCategory.malls => 12.0,
      DestinationCategory.food => 12.0,
      DestinationCategory.park => 10.0,
      DestinationCategory.activities => 6.0,
      DestinationCategory.museum => 4.0,
      DestinationCategory.landmark => 4.0,
    };
    return destination.rating * 20.0 +
        log(reviews + 1) * 8.0 +
        categoryBoost -
        distance.clamp(0.0, 50.0);
  }

  static Future<LatLng> _getSearchLocation() async {
    try {
      final location = await getCurrentLocation().timeout(
        _locationSearchTimeout,
        onTimeout: () {
          debugPrint('Location fetch timed out, using default search location');
          return _cachedLocation ?? _defaultSearchLocation;
        },
      );
      if (isInvalidLocation(location)) {
        debugPrint('Invalid location detected, using default search location');
        return _cachedLocation ?? _defaultSearchLocation;
      }
      return location;
    } catch (e) {
      debugPrint('Error getting search location: $e');
      return _cachedLocation ?? _defaultSearchLocation;
    }
  }

  static String _queryFor(String query, DestinationCategory? category) {
    final trimmed = query.trim();
    if (trimmed.isNotEmpty) return trimmed;
    if (category == null) return 'tourist attractions';
    return switch (category) {
      DestinationCategory.food => 'restaurants cafes',
      DestinationCategory.park => 'parks',
      DestinationCategory.museum => 'museums',
      DestinationCategory.malls => 'shopping malls',
      DestinationCategory.activities => 'activities entertainment',
      DestinationCategory.landmark => 'tourist attractions landmarks',
    };
  }

  static Destination? _convertGooglePlaceToDestination(
    Map<String, dynamic> item,
    String? placeId,
  ) {
    final id = placeId ?? item['place_id'] ?? 'google_${DateTime.now().millisecondsSinceEpoch}';
    final name = item['name'] as String? ?? 'Unknown Place';
    final formattedAddress =
        item['formatted_address'] as String? ?? 'Philippines';
    final geometry = item['geometry'] as Map<String, dynamic>?;
    final location = geometry?['location'] as Map<String, dynamic>?;
    final lat = (location?['lat'] as num?)?.toDouble();
    final lng = (location?['lng'] as num?)?.toDouble();
    final rating = (item['rating'] as num?)?.toDouble() ?? 4.0;

    DestinationCategory category = DestinationCategory.landmark;
    final types = item['types'] as List?;
    if (types != null) {
      final typesStr = types.join(' ').toLowerCase();
      if (typesStr.contains('restaurant') || typesStr.contains('food') || typesStr.contains('cafe')) {
        category = DestinationCategory.food;
      } else if (typesStr.contains('park') || typesStr.contains('garden')) {
        category = DestinationCategory.park;
      } else if (typesStr.contains('museum') || typesStr.contains('gallery')) {
        category = DestinationCategory.museum;
      } else if (typesStr.contains('shopping') || typesStr.contains('mall') || typesStr.contains('store')) {
        category = DestinationCategory.malls;
      } else if (typesStr.contains('tourist') || typesStr.contains('attraction') || typesStr.contains('landmark')) {
        category = DestinationCategory.landmark;
      }
    }

    String? imageUrl;
    final photos = item['photos'] as List?;
    if (photos != null && photos.isNotEmpty) {
      final photoRef = photos[0]['photo_reference'] as String?;
      if (photoRef != null) {
        imageUrl = 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=300&photoreference=$photoRef&key=$_googleApiKey';
      }
    }

    return Destination(
      id: id,
      name: name,
      description: formattedAddress,
      location: formattedAddress,
      coordinates: (lat != null && lng != null) ? LatLng(lat, lng) : null,
      imageUrl: imageUrl ?? '',
      category: category,
      rating: rating,
      tags: types?.cast<String>() ?? [],
      
    );
  }
}

class TimeoutException implements Exception {
  final String message;
  const TimeoutException(this.message);
}
