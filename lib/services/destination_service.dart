import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/services/osm_service.dart';
import 'package:halaph/services/place_cache_service.dart';
import 'package:halaph/config/app_config.dart';

class DestinationService {
  static const LatLng _defaultSearchLocation = LatLng(14.5995, 120.9842);
  static const Duration _locationSearchTimeout = Duration(seconds: 4);
  static const Duration _placesSearchTimeout = Duration(seconds: 10);

  static LatLng? _cachedLocation;
  static DateTime? _locationCacheTime;
  static const _cacheValidity = Duration(minutes: 30);
  static bool _useTestLocation = false;
  static LatLng? _manualTestLocation;

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

  static Future<Destination?> getDestination(String id) async {
    if (id.startsWith('osm_')) {
      return null; // OSM doesn't have a direct place ID lookup
    }
    if (id.startsWith('nominatim_')) {
      return null; // Nominatim doesn't have a direct place ID lookup
    }
    return null;
  }

  static Future<List<Destination>> searchDestinations(String? query) async {
    if (AppConfig.disableAllApiCalls) {
      debugPrint('🧪 Test Mode: Skipping searchDestinations()');
      return <Destination>[];
    }
    final trimmed = query?.trim() ?? '';
    final location = await _getSearchLocation();
    final results = trimmed.isEmpty
        ? await _discoverPlaces(location)
        : await _searchPlaces(query: trimmed, location: location, limit: 24);

    return _rankAndLimit(results, location, limit: 24);
  }

  static Future<List<Destination>> getTrendingDestinations() async {
    if (AppConfig.disableAllApiCalls) {
      debugPrint('🧪 Test Mode: Skipping getTrendingDestinations()');
      return <Destination>[];
    }
    try {
      final currentLocation = await _getSearchLocation();
      final places = await _discoverPlaces(currentLocation);
      return _rankAndLimit(places, currentLocation, limit: 20);
    } catch (e) {
      debugPrint('Error fetching trending destinations: $e');
      return <Destination>[];
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

  static Future<List<Destination>> searchDestinationsEnhanced({
    String? query,
    DestinationCategory? category,
  }) async {
    final currentLocation = await _getSearchLocation();
    final searchQuery = _queryFor(query ?? '', category);
    final places = await _searchPlaces(
      query: searchQuery,
      location: currentLocation,
      limit: 30,
    );
    final filtered = category == null
        ? places
        : places.where((place) => place.category == category).toList();
    return _rankAndLimit(filtered, currentLocation, limit: 24);
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
    switch (category) {
      case DestinationCategory.park:
        return 'Parks';
      case DestinationCategory.landmark:
        return 'Landmarks';
      case DestinationCategory.food:
        return 'Food';
      case DestinationCategory.activities:
        return 'Activities';
      case DestinationCategory.museum:
        return 'Museums';
      case DestinationCategory.market:
        return 'Markets';
    }
  }

  static Future<List<Destination>> _discoverPlaces(LatLng location) async {
    final isRealLocation = !isInvalidLocation(location);

    // Try cache first
    final locationKey = PlaceCacheService.generateLocationKey(
        location.latitude, location.longitude);
    final cached = await PlaceCacheService.getCachedSearch(
        'discover', locationKey);
    if (cached.isNotEmpty) {
      debugPrint('DestinationService: Using cached discover results');
      return cached
          .map((item) => Destination.fromJson(item))
          .toList();
    }

    final searchLocation = isRealLocation ? location : _defaultSearchLocation;
    final results = <Destination>[];

    // Use OSM Overpass API to search for nearby places
    results.addAll(
      await OSMService.searchNearbyPlaces(
        lat: searchLocation.latitude,
        lon: searchLocation.longitude,
        radius: 15000,
        limit: 20,
      ).timeout(_placesSearchTimeout, onTimeout: () => const <Destination>[]),
    );

    // Also search by text queries using Nominatim
    final queries = const [
      'tourist attractions',
      'restaurants',
      'parks',
    ];

    for (final query in queries) {
      results.addAll(
        await OSMService.searchPlacesByText(
          query: query,
          lat: searchLocation.latitude,
          lon: searchLocation.longitude,
          limit: 8,
        ).timeout(_placesSearchTimeout, onTimeout: () => const <Destination>[]),
      );
    }

    // Cache the results
    final jsonResults = results.map((d) => d.toJson()).toList();
    await PlaceCacheService.cacheSearch(
        'discover', locationKey, jsonResults);

    return results;
  }

  static Future<List<Destination>> _searchPlaces({
    required String query,
    required LatLng location,
    required int limit,
  }) async {
    return OSMService.searchPlacesByText(
      query: query,
      lat: location.latitude,
      lon: location.longitude,
      limit: limit,
    ).timeout(_placesSearchTimeout, onTimeout: () => const <Destination>[]);
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
    String? reviewsTag;
    for (final tag in destination.tags) {
      if (tag.startsWith('reviews:')) {
        reviewsTag = tag;
        break;
      }
    }
    final reviews =
        double.tryParse(reviewsTag?.split(':').last ?? '') ??
        (destination.tags.contains('popular') ? 500.0 : 50.0);
    final distance = destination.coordinates == null
        ? 12.0
        : calculateDistance(origin, destination.coordinates!);
    final categoryBoost = switch (destination.category) {
      DestinationCategory.market => 12.0,
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
      DestinationCategory.market => 'shopping malls markets',
      DestinationCategory.activities => 'activities entertainment',
      DestinationCategory.landmark => 'tourist attractions landmarks',
    };
  }
}
