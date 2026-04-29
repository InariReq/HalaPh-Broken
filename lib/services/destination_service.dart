import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/services/google_maps_api_service.dart';

class DestinationService {
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

  // Get current location
  static Future<LatLng> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LatLng(0, 0); // Invalid location
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return const LatLng(0, 0);
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return const LatLng(0, 0);
      }

      final settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );

      debugPrint(
        'Current location: ${position.latitude}, ${position.longitude}',
      );
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('Error getting location: $e');
      return const LatLng(0, 0);
    }
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

  // Search destinations using Google Places API
  static Future<List<Destination>> searchDestinations(String? query) async {
    try {
      return await searchRealPlaces(
        query: query ?? '',
        location: await getCurrentLocation(),
      );
    } catch (e) {
      debugPrint('Search failed completely: $e');
      return [];
    }
  }

  // Get trending destinations - REAL Google Places API only
  static Future<List<Destination>> getTrendingDestinations() async {
    debugPrint('=== getTrendingDestinations called ===');
    try {
      final currentLocation = await getCurrentLocation();

      // If location is invalid, return empty
      if (currentLocation.latitude == 0 && currentLocation.longitude == 0) {
        debugPrint('Invalid location (0,0) - returning empty');
        return [];
      }

      const nearbyRadiusMeters = 5000.0; // 5km
      const nearbyRadiusKm = 5.0;

      debugPrint(
        'Searching from location: ${currentLocation.latitude}, ${currentLocation.longitude}',
      );

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

      final batches = await Future.wait(
        nearbyPlaceTypes.map(
          (placeType) => _searchNearbyDestinations(
            currentLocation: currentLocation,
            placeType: placeType,
            radiusMeters: nearbyRadiusMeters,
            maxDistanceKm: nearbyRadiusKm,
          ),
        ),
      );
      final allTrendingPlaces = batches.expand((places) => places).toList();

      final deduped = deduplicateDestinationsById(allTrendingPlaces);
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
          'Returning ${topPlaces.length} nearby trending places from Google Places',
        );
        return topPlaces;
      } else {
        debugPrint('No nearby Google Places results, returning empty list');
        return [];
      }
    } catch (e) {
      debugPrint('Google Places nearby trending failed: $e');
      return [];
    }
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
      final searchLocation = location ?? await getCurrentLocation();
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
      );
      final realPlaces = await Future.wait(
        googlePlaces.map((place) => _convertGooglePlaceToDestination(place)),
      );
      return realPlaces;
    } catch (e) {
      debugPrint('Error searching real places: $e');
      return [];
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
      final searchLocation = location ?? await getCurrentLocation();
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
      final currentLocation = await getCurrentLocation();

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
      );
      final realPlaces = await Future.wait(
        googlePlaces.map((place) => _convertGooglePlaceToDestination(place)),
      );

      if (category != null && realPlaces.isNotEmpty) {
        final filtered = realPlaces
            .where((dest) => dest.category == category)
            .toList();
        return filtered;
      }

      return realPlaces;
    } catch (e) {
      debugPrint('Enhanced search failed: $e');
      return [];
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
