import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/services/google_maps_api_service.dart';
import 'package:halaph/services/osm_service.dart';

class DestinationService {
  static const LatLng _defaultSearchLocation = LatLng(14.5995, 120.9842); // Manila fallback only if location fails
  static const Duration _locationSearchTimeout = Duration(seconds: 4);
  static const Duration _placesSearchTimeout = Duration(seconds: 8);

  static LatLng? _cachedLocation;
  static DateTime? _locationCacheTime;
  static const _cacheValidity = Duration(minutes: 1); // Shorter cache to get fresh location
  static bool _useTestLocation = false;
  static LatLng? _manualTestLocation;

  // Get current location with aggressive retry - used throughout the app
  static Future<LatLng> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) return _defaultSearchLocation;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return _defaultSearchLocation;
      }
      
      if (permission == LocationPermission.deniedForever) return _defaultSearchLocation;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      ).timeout(Duration(seconds: 10));
      
      _cachedLocation = LatLng(position.latitude, position.longitude);
      _locationCacheTime = DateTime.now();
      return _cachedLocation!;
    } catch (e) {
      return _cachedLocation ?? _defaultSearchLocation;
    }
  }

  // FOR TESTING: Set a manual location (call this from UI or main)
  static void setTestLocation(double lat, double lng) {
    _useTestLocation = true;
    _manualTestLocation = LatLng(lat, lng);
    debugPrint('🧪 TEST LOCATION SET: $lat, $lng');
  }

  static void clearTestLocation() {
    _useTestLocation = false;
    _manualTestLocation = null;
    _cachedLocation = null;
    _locationCacheTime = null;
    debugPrint('🧪 Test location cleared');
  }

  // Get destination by ID using Google Places API
  static Future<Destination?> getDestination(String id) async {
    try {
      // Try to get details from Google Places API if it's a Google place ID
      if (id.startsWith('google_')) {
        final placeId = id.replaceFirst('google_', '');
        final details = await GoogleMapsApiService.getPlaceDetails(placeId);
        if (details != null) {
          return _convertPlaceDetailsToDestination(details);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Search destinations using Google Places API
  static Future<List<Destination>> searchDestinations(String? query) async {
    try {
      final location = await _getSearchLocation();
      debugPrint('🔍 Searching for "$query" using Google Places API');

      // Use Google Places Text Search for real destinations
      final places = await GoogleMapsApiService.searchPlaces(
        query: query ?? 'popular destinations in Philippines',
        location: location,
        radius: 100000, // 100km radius to cover more of Philippines
      );

      if (places.isNotEmpty) {
        debugPrint('✅ Got ${places.length} results from Google Places API');
        return places.map((place) => _convertGooglePlaceToDestination(place)).toList();
      }

      debugPrint('⚠️ No Google Places results for search');
      return <Destination>[];
    } catch (e) {
      debugPrint('❌ Google Places search error: $e');
      return <Destination>[];
    }
  }

  // Get trending destinations - Use Google Places API for real places
  static Future<List<Destination>> getTrendingDestinations() async {
    debugPrint('=== getTrendingDestinations called ===');
    try {
      final currentLocation = await _getSearchLocation();

      // Check if we're using a real location or default
      final isRealLocation = !isInvalidLocation(currentLocation);
      debugPrint(
        '📍 Searching from location: ${currentLocation.latitude}, ${currentLocation.longitude} (Real: $isRealLocation)',
      );

      // Use Google Places API to find popular destinations
      debugPrint('🔍 Using Google Places API for real destinations');

      List<Destination> places = [];

      // Search for popular place types people actually visit
      final searchQueries = [
        'tourist attractions in Philippines',
        'popular restaurants in Philippines',
        'parks in Philippines',
        'museums in Philippines',
        'shopping malls in Philippines',
      ];

      for (final query in searchQueries) {
        final results = await GoogleMapsApiService.searchPlaces(
          query: query,
          location: isRealLocation ? currentLocation : null,
          radius: isRealLocation ? 50000 : 500000, // Wider search if no real location
        );
        places.addAll(results.map((place) => _convertGooglePlaceToDestination(place)));
      }

      // Deduplicate by ID
      final deduped = deduplicateDestinationsById(places);

      if (deduped.isNotEmpty) {
        debugPrint('✅ Got ${deduped.length} real places from Google Places API');
        return deduped.take(20).toList();
      }

      debugPrint('⚠️ No Google Places results for trending');
      return <Destination>[];
    } catch (e) {
      debugPrint('❌ Error fetching trending destinations: $e');
      return <Destination>[];
    }
  }

  // Convert GooglePlace to Destination
  static Destination _convertGooglePlaceToDestination(GooglePlace place) {
    return Destination(
      id: 'google_${place.placeId}',
      name: place.name,
      description: place.vicinity ?? 'A popular destination in the Philippines',
      location: place.vicinity ?? 'Philippines',
      coordinates: place.location,
      imageUrl: place.photos.isNotEmpty
          ? GoogleMapsApiService.getPhotoUrl(
              place.photos.first.photoReference,
              maxWidth: 800,
              maxHeight: 600,
            )
          : '',
      category: _mapGoogleTypeToCategory(place.types),
      rating: 4.0,
      tags: place.types,
      budget: BudgetInfo(minCost: 0, maxCost: 1000, currency: 'PHP'),
    );
  }

  // Map Google Places types to our DestinationCategory
  static DestinationCategory _mapGoogleTypeToCategory(List<String> types) {
    if (types.any((t) => t.contains('restaurant') || t.contains('food') || t.contains('cafe'))) {
      return DestinationCategory.food;
    }
    if (types.any((t) => t.contains('park') || t.contains('natural'))) {
      return DestinationCategory.park;
    }
    if (types.any((t) => t.contains('museum') || t.contains('art_gallery'))) {
      return DestinationCategory.museum;
    }
    if (types.any((t) => t.contains('shopping_mall') || t.contains('store') || t.contains('market'))) {
      return DestinationCategory.market;
    }
    if (types.any((t) => t.contains('tourist_attraction') || t.contains('landmark') || t.contains('monument'))) {
      return DestinationCategory.landmark;
    }
    return DestinationCategory.activities;
  }

  // Public helper to deduplicate destinations by id
  static List<Destination> deduplicateDestinationsById(List<Destination> list) {
    final seen = <String>{};
    final out = <Destination>[];
    for (final d in list) {
      if (!seen.contains(d.id)) {
        seen.add(d.id);
        out.add(d);
      }
    }
    return out;
  }

  static Future<List<Destination>> _searchNearbyDestinations({
    required LatLng currentLocation,
    required String placeType,
    required double radiusMeters,
    required double maxDistanceKm,
  }) async {
    try {
      debugPrint('Searching for nearby "$placeType"...');
      final places = await GoogleMapsApiService.findNearbyPlaces(
        location: currentLocation,
        placeType: placeType,
        radius: radiusMeters,
      );
      debugPrint(
        'Google API returned ${places.length} raw results for "$placeType"',
      );

      final nearbyPlaces =
          places.where((place) {
            final hasName = place.name.trim().isNotEmpty;
            final isNearby =
                _calculateDistance(currentLocation, place.location) <=
                maxDistanceKm;
            final hasUsefulRating = place.rating == 0 || place.rating >= 3.8;
            return hasName && isNearby && hasUsefulRating;
          }).toList()..sort((a, b) {
            final ratingCompare = b.rating.compareTo(a.rating);
            if (ratingCompare != 0) return ratingCompare;
            final aDistance = _calculateDistance(currentLocation, a.location);
            final bDistance = _calculateDistance(currentLocation, b.location);
            return aDistance.compareTo(bDistance);
          });

      return nearbyPlaces
          .take(3)
          .map((place) => _convertGooglePlaceToDestination(place))
          .toList();
    } catch (e) {
      debugPrint('Error searching nearby "$placeType": $e');
      return const <Destination>[];
    }
  }

  // Calculate distance between two coordinates
  static double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371;
    double lat1Rad = point1.latitude * (pi / 180);
    double lat2Rad = point2.latitude * (pi / 180);
    double deltaLatRad = (point2.latitude - point1.latitude) * (pi / 180);
    double deltaLngRad = (point2.longitude - point1.longitude) * (pi / 180);

    double a =
        sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) *
            cos(lat2Rad) *
            sin(deltaLngRad / 2) *
            sin(deltaLngRad / 2);
    double c = 2 * asin(sqrt(a).clamp(0.0, 1.0));
    return earthRadius * c;
  }

  static bool isInvalidLocation(LatLng location) {
    return location.latitude == 0 && location.longitude == 0;
  }

  static DestinationCategory _parseCategory(List<String> types) {
    if (types.contains('shopping_mall') ||
        types.contains('market') ||
        types.contains('store') ||
        types.contains('supermarket')) {
      return DestinationCategory.market;
    } else if (types.contains('restaurant') ||
        types.contains('food') ||
        types.contains('cafe') ||
        types.contains('bakery')) {
      return DestinationCategory.food;
    } else if (types.contains('park') || types.contains('natural_feature')) {
      return DestinationCategory.park;
    } else if (types.contains('museum') || types.contains('art_gallery')) {
      return DestinationCategory.museum;
    } else if (types.contains('amusement_park') ||
        types.contains('zoo') ||
        types.contains('aquarium') ||
        types.contains('stadium') ||
        types.contains('entertainment')) {
      return DestinationCategory.activities;
    } else if (types.contains('landmark') ||
        types.contains('tourist_attraction') ||
        types.contains('historic_site')) {
      return DestinationCategory.landmark;
    }
    return DestinationCategory.landmark;
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

  static Destination _convertPlaceDetailsToDestination(
    GooglePlaceDetails details,
  ) {
    final category = _parseCategory(details.types);
    final description =
        (details.editorialSummary != null &&
            details.editorialSummary!.trim().isNotEmpty)
        ? details.editorialSummary!.trim()
        : _generateDescription(details.name, category);

    String imageUrl = '';
    if (details.photos.isNotEmpty) {
      imageUrl = GoogleMapsApiService.getPhotoUrl(
        details.photos.first.photoReference,
        maxWidth: 800,
        maxHeight: 600,
      );
    }

    return Destination(
      id: details.placeId.isNotEmpty ? details.placeId : details.name,
      name: details.name,
      description: description,
      location: details.formattedAddress,
      imageUrl: imageUrl,
      coordinates: details.location,
      category: category,
      rating: details.rating,
      budget: BudgetInfo(minCost: 0, maxCost: 0, currency: 'PHP'),
    );
  }

  static String _generateDescription(
    String name,
    DestinationCategory category,
  ) {
    return switch (category) {
      DestinationCategory.park =>
        'A beautiful $name perfect for relaxation, outdoor activities, and enjoying nature. Great for families and nature lovers.',
      DestinationCategory.landmark =>
        'An iconic $name and must-see historical attraction. Perfect for learning about local culture and taking memorable photos.',
      DestinationCategory.food =>
        'A popular dining destination at $name. Known for delicious cuisine and great atmosphere for meals with friends and family.',
      DestinationCategory.activities =>
        'An exciting $name offering fun activities and adventures. Perfect for thrill-seekers and creating unforgettable memories.',
      DestinationCategory.museum =>
        'A fascinating $name showcasing art, history, and culture. Ideal for learning and exploration with educational exhibits.',
      DestinationCategory.market =>
        'A vibrant $name offering local products, crafts, and authentic shopping experiences. Great for finding unique souvenirs.',
    };
  }

  // Search real places using Google Places API
  static Future<List<Destination>> searchRealPlaces({
    required String query,
    LatLng? location,
    DestinationCategory? category,
  }) async {
    try {
      final searchLocation = location ?? await _getSearchLocation();
      debugPrint(
        'Using location: ${searchLocation.latitude}, ${searchLocation.longitude}',
      );

      String searchQuery = query.isNotEmpty ? query : 'tourist attractions';
      if (category != null) {
        switch (category) {
          case DestinationCategory.food:
            searchQuery = query.isNotEmpty ? query : 'restaurants';
            break;
          case DestinationCategory.park:
            searchQuery = query.isNotEmpty ? query : 'parks';
            break;
          case DestinationCategory.museum:
            searchQuery = query.isNotEmpty ? query : 'museums';
            break;
          case DestinationCategory.market:
            searchQuery = query.isNotEmpty ? query : 'shopping malls';
            break;
          case DestinationCategory.activities:
            searchQuery = query.isNotEmpty ? query : 'activities';
            break;
          case DestinationCategory.landmark:
            searchQuery = query.isNotEmpty ? query : 'landmarks';
            break;
        }
      }

      searchQuery = '$searchQuery Philippines';
      debugPrint('Using text search with query: "$searchQuery"');

      final googlePlaces = await GoogleMapsApiService.searchPlaces(
        query: searchQuery,
        location: searchLocation,
      ).timeout(_placesSearchTimeout, onTimeout: () => const <GooglePlace>[]);
      final realPlaces = googlePlaces
          .map((place) => _convertGooglePlaceToDestination(place))
          .toList();
      return realPlaces.isNotEmpty
          ? realPlaces
          : <Destination>[];
    } catch (e) {
      debugPrint('Error searching real places: $e');
      return <Destination>[];
    }
  }

  // Get autocomplete suggestions
  static Future<List<String>> getAutocompleteSuggestions(
    String input, {
    LatLng? location,
  }) async {
    try {
      final trimmed = input.trim();
      if (trimmed.length < 2) return [];
      final searchLocation = location ?? await _getSearchLocation();
      final places = await GoogleMapsApiService.searchPlaces(
        query: '$trimmed Philippines',
        location: searchLocation,
        radius: 25000,
      );
      final names = <String>[];
      final seen = <String>{};
      for (final place in places.take(6)) {
        final label = place.vicinity.trim().isEmpty
            ? place.name
            : '${place.name}, ${place.vicinity}';
        if (seen.add(label.toLowerCase())) {
          names.add(label);
        }
      }
      return names;
    } catch (e) {
      debugPrint('Error getting autocomplete: $e');
      return [];
    }
  }

  // Enhanced search that prioritizes Google Places API
  static Future<List<Destination>> searchDestinationsEnhanced({
    String? query,
    DestinationCategory? category,
  }) async {
    try {
      final currentLocation = await _getSearchLocation();

      String searchQuery;
      if (query?.isNotEmpty == true) {
        searchQuery = query!;
      } else if (category != null) {
        searchQuery = _getCategoryQuery(category);
      } else {
        searchQuery = 'tourist attractions Philippines';
      }

      final googlePlaces = await GoogleMapsApiService.searchPlaces(
        query: searchQuery,
        location: currentLocation,
      ).timeout(_placesSearchTimeout, onTimeout: () => const <GooglePlace>[]);
      final realPlaces = googlePlaces
          .map((place) => _convertGooglePlaceToDestination(place))
          .toList();
      
      if (category != null && realPlaces.isNotEmpty) {
        final filtered = realPlaces
            .where((dest) => dest.category == category)
            .toList();
        return filtered.isNotEmpty
            ? filtered
            : <Destination>[];
      }

      return realPlaces.isNotEmpty
          ? realPlaces
          : <Destination>[];
    } catch (e) {
      debugPrint('Enhanced search failed: $e');
      return <Destination>[];
    }
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

  static String _getCategoryQuery(DestinationCategory category) {
    switch (category) {
      case DestinationCategory.food:
        return 'restaurants';
      case DestinationCategory.park:
        return 'parks';
      case DestinationCategory.museum:
        return 'museums';
      case DestinationCategory.market:
        return 'shopping malls';
      case DestinationCategory.activities:
        return 'activities';
      case DestinationCategory.landmark:
        return 'tourist attractions';
    }
  }
}
