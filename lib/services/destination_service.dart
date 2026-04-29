import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/services/google_maps_api_service.dart';

class DestinationService {
  static const LatLng _defaultSearchLocation = LatLng(14.5995, 120.9842);
  static const Duration _locationSearchTimeout = Duration(seconds: 4);
  static const Duration _placesSearchTimeout = Duration(seconds: 8);

  static final List<Destination> _fallbackDestinations = [
    Destination(
      id: 'fallback-rizal-park',
      name: 'Rizal Park',
      description:
          'A historic urban park in Manila with gardens, monuments, and open spaces for walks and photos.',
      location: 'Ermita, Manila',
      imageUrl: '',
      coordinates: const LatLng(14.5826, 120.9787),
      category: DestinationCategory.landmark,
      rating: 4.6,
      tags: const ['history', 'park', 'manila', 'landmark'],
      budget: BudgetInfo(minCost: 0, maxCost: 200, currency: 'PHP'),
    ),
    Destination(
      id: 'fallback-intramuros',
      name: 'Intramuros',
      description:
          'The walled city of Manila with heritage streets, churches, museums, and Spanish-era landmarks.',
      location: 'Intramuros, Manila',
      imageUrl: '',
      coordinates: const LatLng(14.5896, 120.9747),
      category: DestinationCategory.landmark,
      rating: 4.7,
      tags: const ['history', 'museum', 'manila', 'walking'],
      budget: BudgetInfo(minCost: 0, maxCost: 500, currency: 'PHP'),
    ),
    Destination(
      id: 'fallback-national-museum',
      name: 'National Museum Complex',
      description:
          'A museum district featuring Filipino art, anthropology, natural history, and cultural exhibits.',
      location: 'Padre Burgos Avenue, Manila',
      imageUrl: '',
      coordinates: const LatLng(14.5869, 120.9811),
      category: DestinationCategory.museum,
      rating: 4.7,
      tags: const ['museum', 'art', 'culture', 'history'],
      budget: BudgetInfo(minCost: 0, maxCost: 200, currency: 'PHP'),
    ),
    Destination(
      id: 'fallback-manila-ocean-park',
      name: 'Manila Ocean Park',
      description:
          'A family-friendly oceanarium and attraction beside Manila Bay with marine exhibits and shows.',
      location: 'Luneta, Manila',
      imageUrl: '',
      coordinates: const LatLng(14.5790, 120.9748),
      category: DestinationCategory.activities,
      rating: 4.2,
      tags: const ['aquarium', 'family', 'activity', 'manila'],
      budget: BudgetInfo(minCost: 500, maxCost: 1200, currency: 'PHP'),
    ),
    Destination(
      id: 'fallback-bgc-high-street',
      name: 'Bonifacio High Street',
      description:
          'An open-air lifestyle district in BGC with restaurants, shops, public art, and walkable plazas.',
      location: 'Bonifacio Global City, Taguig',
      imageUrl: '',
      coordinates: const LatLng(14.5507, 121.0510),
      category: DestinationCategory.market,
      rating: 4.6,
      tags: const ['shopping', 'food', 'bgc', 'taguig'],
      budget: BudgetInfo(minCost: 300, maxCost: 1500, currency: 'PHP'),
    ),
    Destination(
      id: 'fallback-ayala-triangle',
      name: 'Ayala Triangle Gardens',
      description:
          'A landscaped green space in Makati surrounded by cafes, restaurants, and city landmarks.',
      location: 'Makati Central Business District',
      imageUrl: '',
      coordinates: const LatLng(14.5560, 121.0230),
      category: DestinationCategory.park,
      rating: 4.5,
      tags: const ['park', 'makati', 'food', 'city'],
      budget: BudgetInfo(minCost: 0, maxCost: 800, currency: 'PHP'),
    ),
    Destination(
      id: 'fallback-venice-grand-canal',
      name: 'Venice Grand Canal Mall',
      description:
          'A themed shopping and dining destination in McKinley Hill with canal views and restaurants.',
      location: 'McKinley Hill, Taguig',
      imageUrl: '',
      coordinates: const LatLng(14.5349, 121.0506),
      category: DestinationCategory.market,
      rating: 4.4,
      tags: const ['shopping', 'food', 'taguig', 'photos'],
      budget: BudgetInfo(minCost: 300, maxCost: 1500, currency: 'PHP'),
    ),
    Destination(
      id: 'fallback-quezon-memorial-circle',
      name: 'Quezon Memorial Circle',
      description:
          'A large public park and national shrine with gardens, food stalls, museums, and biking areas.',
      location: 'Diliman, Quezon City',
      imageUrl: '',
      coordinates: const LatLng(14.6514, 121.0493),
      category: DestinationCategory.park,
      rating: 4.5,
      tags: const ['park', 'quezon city', 'food', 'family'],
      budget: BudgetInfo(minCost: 0, maxCost: 500, currency: 'PHP'),
    ),
    Destination(
      id: 'fallback-art-in-island',
      name: 'Art in Island',
      description:
          'An interactive art museum in Cubao known for immersive murals and photo-friendly exhibits.',
      location: 'Cubao, Quezon City',
      imageUrl: '',
      coordinates: const LatLng(14.6220, 121.0590),
      category: DestinationCategory.museum,
      rating: 4.4,
      tags: const ['museum', 'art', 'quezon city', 'activity'],
      budget: BudgetInfo(minCost: 500, maxCost: 900, currency: 'PHP'),
    ),
    Destination(
      id: 'fallback-binondo-food-crawl',
      name: 'Binondo Food Crawl',
      description:
          'A classic Manila food trip area with Chinese-Filipino restaurants, bakeries, and street snacks.',
      location: 'Binondo, Manila',
      imageUrl: '',
      coordinates: const LatLng(14.6006, 120.9745),
      category: DestinationCategory.food,
      rating: 4.6,
      tags: const ['food', 'manila', 'binondo', 'walking'],
      budget: BudgetInfo(minCost: 300, maxCost: 1200, currency: 'PHP'),
    ),
    Destination(
      id: 'fallback-maginhawa',
      name: 'Maginhawa Food Street',
      description:
          'A Quezon City food district with cafes, casual restaurants, desserts, and barkada-friendly eats.',
      location: 'Teacher Village, Quezon City',
      imageUrl: '',
      coordinates: const LatLng(14.6454, 121.0610),
      category: DestinationCategory.food,
      rating: 4.4,
      tags: const ['food', 'cafe', 'quezon city', 'restaurants'],
      budget: BudgetInfo(minCost: 250, maxCost: 1000, currency: 'PHP'),
    ),
    Destination(
      id: 'fallback-sm-moa',
      name: 'SM Mall of Asia',
      description:
          'A large bayside mall complex in Pasay with shopping, dining, entertainment, and sunset views nearby.',
      location: 'Bay City, Pasay',
      imageUrl: '',
      coordinates: const LatLng(14.5352, 120.9822),
      category: DestinationCategory.market,
      rating: 4.5,
      tags: const ['shopping', 'food', 'pasay', 'bay'],
      budget: BudgetInfo(minCost: 300, maxCost: 2000, currency: 'PHP'),
    ),
  ];

  // Get current city based on location (for display only)
  static String getCurrentCity(LatLng location) {
    final cities = {
      'Manila': LatLng(14.5995, 120.9842),
      'Quezon City': LatLng(14.6760, 121.0437),
      'Cebu City': LatLng(10.3157, 123.8854),
      'Davao City': LatLng(7.0731, 125.6128),
      'Makati': LatLng(14.5547, 121.0244),
      'Pasig': LatLng(14.5764, 121.0851),
      'Taguig': LatLng(14.5176, 121.0515),
      'Pasay': LatLng(14.5375, 121.0014),
      'Mandaluyong': LatLng(14.5794, 121.0359),
      'San Juan': LatLng(14.6018, 121.0366),
      'Caloocan': LatLng(14.6507, 120.9663),
      'Las Piñas': LatLng(14.4378, 120.9762),
      'Muntinlupa': LatLng(14.4090, 121.0258),
      'Parañaque': LatLng(14.4793, 121.0199),
      'Marikina': LatLng(14.6528, 121.1064),
      'Valenzuela': LatLng(14.6908, 120.9838),
      'Iloilo City': LatLng(10.7158, 122.5639),
      'Baguio City': LatLng(16.4023, 120.5960),
      'Bacolod City': LatLng(10.6718, 122.9510),
      'Cagayan de Oro': LatLng(8.4542, 124.6319),
      'General Santos': LatLng(6.1164, 125.1716),
      'Zamboanga City': LatLng(6.9214, 122.0790),
      'Angeles City': LatLng(15.1474, 120.5896),
      'Batangas City': LatLng(13.7567, 121.0584),
      'Lipa City': LatLng(13.9401, 121.1615),
      'Tuguegarao': LatLng(17.6147, 121.7310),
      'Legazpi': LatLng(13.1392, 123.7438),
      'Lucena': LatLng(13.9340, 121.6162),
      'Puerto Princesa': LatLng(9.8467, 118.7333),
    };

    String closestCity = 'Quezon City';
    double minDistance = double.infinity;

    cities.forEach((cityName, cityLocation) {
      double distance = _calculateDistance(location, cityLocation);
      if (distance < minDistance) {
        minDistance = distance;
        closestCity = cityName;
      }
    });

    debugPrint(
      'Detected city: $closestCity (distance: ${minDistance.toStringAsFixed(2)} km)',
    );
    return closestCity;
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

  static LatLng? _cachedLocation;
  static DateTime? _locationCacheTime;
  static const _cacheValidity = Duration(minutes: 5);

  static bool _useTestLocation = false;
  static LatLng? _manualTestLocation;

  // Get current location with retry logic and caching
  static Future<LatLng> getCurrentLocation() async {
    // MANUAL OVERRIDE FOR TESTING
    if (_useTestLocation && _manualTestLocation != null) {
      debugPrint(
        '🟢 USING MANUAL TEST LOCATION: ${_manualTestLocation!.latitude}, ${_manualTestLocation!.longitude}',
      );
      return _manualTestLocation!;
    }

    try {
      // Use cached location if recent
      if (_cachedLocation != null &&
          _locationCacheTime != null &&
          DateTime.now().difference(_locationCacheTime!) < _cacheValidity) {
        debugPrint(
          '🟢 Using cached location: ${_cachedLocation!.latitude}, ${_cachedLocation!.longitude}',
        );
        return _cachedLocation!;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      debugPrint('📍 Location service enabled: $serviceEnabled');
      if (!serviceEnabled) {
        debugPrint('🔴 Location services are disabled - using default');
        return _cachedLocation ?? _defaultSearchLocation;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint('📍 Current permission status: $permission');
      if (permission == LocationPermission.denied) {
        debugPrint('🟡 Requesting location permission...');
        permission = await Geolocator.requestPermission();
        debugPrint('📍 After request, permission: $permission');
        if (permission == LocationPermission.denied) {
          debugPrint('🔴 Location permission denied - using default');
          return _cachedLocation ?? _defaultSearchLocation;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('🔴 Location permission permanently denied - using default');
        return _cachedLocation ?? _defaultSearchLocation;
      }

      // Try to get current position with retries
      Position? position;
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          debugPrint('📍 Getting location, attempt $attempt...');
          final settings = LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 15),
          );
          position = await Geolocator.getCurrentPosition(
            locationSettings: settings,
          );
          debugPrint(
            '🟢 Got position: ${position.latitude}, ${position.longitude}',
          );
          break;
        } catch (e) {
          debugPrint('🔴 Location attempt $attempt failed: $e');
          if (attempt < 3) {
            await Future.delayed(Duration(seconds: attempt));
          }
        }
      }

      if (position == null) {
        // Try last known position
        try {
          debugPrint('📍 Trying last known position...');
          position = await Geolocator.getLastKnownPosition();
          if (position != null) {
            debugPrint(
              '🟢 Got last known: ${position.latitude}, ${position.longitude}',
            );
          }
        } catch (e) {
          debugPrint('🔴 Failed to get last known position: $e');
        }
      }

      if (position != null) {
        final location = LatLng(position.latitude, position.longitude);
        _cachedLocation = location;
        _locationCacheTime = DateTime.now();
        debugPrint(
          '🟢 CURRENT LOCATION SET: ${position.latitude}, ${position.longitude}',
        );
        return location;
      }

      debugPrint('🔴 ALL LOCATION METHODS FAILED - using default location');
      return _cachedLocation ?? _defaultSearchLocation;
    } catch (e) {
      debugPrint('🔴 Error getting location: $e');
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

  // Get destination by ID (Google Place ID)
  static Future<Destination?> getDestination(String id) async {
    try {
      return await getDestinationByPlaceId(id);
    } catch (e) {
      return null;
    }
  }

  static Future<Destination?> getDestinationByPlaceId(String placeId) async {
    try {
      final details = await GoogleMapsApiService.getPlaceDetails(placeId);
      if (details == null) return null;
      return _convertPlaceDetailsToDestination(details);
    } catch (e) {
      return null;
    }
  }

  // Search destinations using FREE OpenStreetMap APIs
  static Future<List<Destination>> searchDestinations(String? query) async {
    try {
      final location = await _getSearchLocation();
      debugPrint('🌍 OSM: Searching for "$query" (FREE)');

      // Use Nominatim text search (FREE, no billing)
      final results = await OSMService.searchPlacesByText(
        query: query ?? 'tourist attractions',
        lat: location.latitude,
        lon: location.longitude,
        limit: 20,
      );

      if (results.isNotEmpty) {
        debugPrint('🌍 Got ${results.length} results from OSM (FREE)');
        return results;
      }

      debugPrint('🌍 No OSM results, using fallback');
      return fallbackDestinations(query: query);
    } catch (e) {
      debugPrint('🌍 OSM search error: $e');
      return fallbackDestinations(query: query);
    }
  }

  // Get trending destinations - Use FREE OpenStreetMap APIs
  static Future<List<Destination>> getTrendingDestinations() async {
    debugPrint('=== getTrendingDestinations called ===');
    try {
      final currentLocation = await _getSearchLocation();

      // Check if we're using a real location or default
      final isRealLocation = !isInvalidLocation(currentLocation);
      debugPrint(
        '📍 Searching from location: ${currentLocation.latitude}, ${currentLocation.longitude} (Real: $isRealLocation)',
      );

      // If using default location, skip nearby search
      if (!isRealLocation) {
        debugPrint(
          '🔴 Using default location - using fallback destinations',
        );
        return fallbackDestinations(limit: 6);
      }

      debugPrint('🌍 Using OSM Overpass API (FREE, no billing)');

      // Search for real nearby places using OSM (FREE!)
      final osmPlaces = await OSMService.searchNearbyPlaces(
        lat: currentLocation.latitude,
        lon: currentLocation.longitude,
        radius: 5000,
        limit: 30,
      );

      if (osmPlaces.isNotEmpty) {
        debugPrint(
          '🌍 Returning ${osmPlaces.length} nearby places from OSM (FREE)',
        );
        return osmPlaces.take(6).toList();
      } else {
        debugPrint('🌍 No OSM results, trying Nominatim text search...');
        final textResults = await OSMService.searchPlacesByText(
          query: 'tourist attractions',
          lat: currentLocation.latitude,
          lon: currentLocation.longitude,
          limit: 6,
        );

        if (textResults.isNotEmpty) {
          debugPrint(
            '🌍 Returning ${textResults.length} places from Nominatim (FREE)',
          );
          return textResults;
        }
      }

      debugPrint('🌍 All OSM methods failed, using fallback places');
      return fallbackDestinations(limit: 6, near: currentLocation);
    } catch (e) {
      debugPrint('🌍 OSM error: $e');
      return fallbackDestinations(limit: 6);
    }
  }

      // Search for real nearby places people can actually visit now.
      const nearbyPlaceTypes = [
        'cafe',
        'shopping_mall',
        'restaurant',
        'bakery',
        'park',
        'tourist_attraction',
        'museum',
      ];

      final batches =
          await Future.wait(
            nearbyPlaceTypes.map(
              (placeType) => _searchNearbyDestinations(
                currentLocation: currentLocation,
                placeType: placeType,
                radiusMeters: nearbyRadiusMeters,
                maxDistanceKm: nearbyRadiusKm,
              ),
            ),
          ).timeout(
            _placesSearchTimeout,
            onTimeout: () => const <List<Destination>>[],
          );
      final alTrendingPlaces = batches.expand((places) => places).toList();

      final deduped = deduplicateDestinationsById(alTrendingPlaces);
      deduped.removeWhere((destination) {
        final coordinates = destination.coordinates;
        if (coordinates == null) return true;
        return _calculateDistance(currentLocation, coordinates) >
            nearbyRadiusKm;
      });

      deduped.sort((a, b) {
        final ratingCompare = b.rating.compareTo(a.rating);
        if (ratingCompare != 0) return ratingCompare;
        final aDistance = _calculateDistance(
          currentLocation,
          a.coordinates ?? currentLocation,
        );
        final bDistance = _calculateDistance(
          currentLocation,
          b.coordinates ?? currentLocation,
        );
        return aDistance.compareTo(bDistance);
      });

      final topPlaces = deduped.take(6).toList();

      if (topPlaces.isNotEmpty) {
        debugPrint(
          '🟢 Returning ${topPlaces.length} nearby trending places from Google Places',
        );
        return topPlaces;
      } else {
        debugPrint('🔴 No nearby Google Places results, using fallback places');
        return fallbackDestinations(limit: 6, near: currentLocation);
      }
    } catch (e) {
      debugPrint('🔴 Google Places nearby trending failed: $e');
      return fallbackDestinations(limit: 6);
    }
  }
    } catch (e) {
      debugPrint('Google Places nearby trending failed: $e');
      return fallbackDestinations(limit: 6);
    }
  }

  static List<Destination> fallbackDestinations({
    String? query,
    DestinationCategory? category,
    int? limit,
    LatLng? near,
  }) {
    final normalizedQuery = query?.trim().toLowerCase() ?? '';
    var destinations = _fallbackDestinations.where((destination) {
      final matchesCategory =
          category == null || destination.category == category;
      if (!matchesCategory) return false;
      if (normalizedQuery.isEmpty) return true;

      final haystack = [
        destination.name,
        destination.location,
        destination.description,
        ...destination.tags,
        getCategoryName(destination.category),
      ].join(' ').toLowerCase();
      return haystack.contains(normalizedQuery);
    }).toList();

    if (destinations.isEmpty && category != null) {
      destinations = _fallbackDestinations
          .where((destination) => destination.category == category)
          .toList();
    }
    if (destinations.isEmpty) {
      destinations = List<Destination>.from(_fallbackDestinations);
    }

    final reference = near;
    if (reference != null) {
      destinations.sort((a, b) {
        final aDistance = _calculateDistance(
          reference,
          a.coordinates ?? _defaultSearchLocation,
        );
        final bDistance = _calculateDistance(
          reference,
          b.coordinates ?? _defaultSearchLocation,
        );
        return aDistance.compareTo(bDistance);
      });
    } else {
      destinations.sort((a, b) => b.rating.compareTo(a.rating));
    }

    return limit == null ? destinations : destinations.take(limit).toList();
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

      return Future.wait(
        nearbyPlaces
            .take(3)
            .map(
              (place) =>
                  _convertGooglePlaceToDestination(place, fetchDetails: false),
            ),
      );
    } catch (e) {
      debugPrint('Error searching nearby "$placeType": $e');
      return const <Destination>[];
    }
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

  static Future<Destination> _convertGooglePlaceToDestination(
    GooglePlace place, {
    bool fetchDetails = true,
  }) async {
    debugPrint('Converting Google Place: ${place.name}');

    String description = place.vicinity;
    String location = place.vicinity;

    if (fetchDetails) {
      try {
        final placeDetails = await GoogleMapsApiService.getPlaceDetails(
          place.placeId,
        );
        if (placeDetails != null) {
          if (placeDetails.formattedAddress.isNotEmpty) {
            location = placeDetails.formattedAddress;
          }
          if (placeDetails.editorialSummary != null &&
              placeDetails.editorialSummary!.isNotEmpty) {
            description = placeDetails.editorialSummary!;
          } else {
            description = _generateDescription(
              place.name,
              _parseCategory(place.types),
            );
          }
        } else {
          description = _generateDescription(
            place.name,
            _parseCategory(place.types),
          );
        }
      } catch (e) {
        description = _generateDescription(
          place.name,
          _parseCategory(place.types),
        );
      }
    } else if (description.trim().isEmpty) {
      description = _generateDescription(
        place.name,
        _parseCategory(place.types),
      );
    }

    String imageUrl = '';
    if (place.photos.isNotEmpty) {
      final photoReference = place.photos.first.photoReference;
      imageUrl = GoogleMapsApiService.getPhotoUrl(
        photoReference,
        maxWidth: 800,
        maxHeight: 600,
      );
    }

    return Destination(
      id: place.placeId,
      name: place.name,
      description: description,
      location: location,
      imageUrl: imageUrl,
      coordinates: place.location,
      category: _parseCategory(place.types),
      rating: place.rating,
      budget: BudgetInfo(minCost: 0, maxCost: 0, currency: 'PHP'),
    );
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
      final realPlaces = await Future.wait(
        googlePlaces.map(
          (place) =>
              _convertGooglePlaceToDestination(place, fetchDetails: false),
        ),
      );
      return realPlaces.isNotEmpty
          ? realPlaces
          : fallbackDestinations(
              query: query,
              category: category,
              near: searchLocation,
            );
    } catch (e) {
      debugPrint('Error searching real places: $e');
      return fallbackDestinations(query: query, category: category);
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
      final realPlaces = await Future.wait(
        googlePlaces.map(
          (place) =>
              _convertGooglePlaceToDestination(place, fetchDetails: false),
        ),
      );

      if (category != null && realPlaces.isNotEmpty) {
        final filtered = realPlaces
            .where((dest) => dest.category == category)
            .toList();
        return filtered.isNotEmpty
            ? filtered
            : fallbackDestinations(
                query: query,
                category: category,
                near: currentLocation,
              );
      }

      return realPlaces.isNotEmpty
          ? realPlaces
          : fallbackDestinations(
              query: query,
              category: category,
              near: currentLocation,
            );
    } catch (e) {
      debugPrint('Enhanced search failed: $e');
      return fallbackDestinations(query: query, category: category);
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

  static bool isInvalidLocation(LatLng location) {
    return location.latitude == 0 && location.longitude == 0;
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
