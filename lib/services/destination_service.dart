import 'package:flutter/foundation.dart';
import 'dart:math';
import 'package:halaph/models/destination.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:halaph/services/google_maps_api_service.dart';

class DestinationService {
  // Get current city based on location
  static String getCurrentCity(LatLng location) {
    // Major Philippines cities with their approximate coordinates
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

    String closestCity = 'Quezon City'; // Default to largest city
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
    const double earthRadius = 6371; // Earth's radius in kilometers

    double lat1Rad = point1.latitude * (3.14159265359 / 180);
    double lat2Rad = point2.latitude * (3.14159265359 / 180);
    double deltaLatRad =
        (point2.latitude - point1.latitude) * (3.14159265359 / 180);
    double deltaLngRad =
        (point2.longitude - point1.longitude) * (3.14159265359 / 180);

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
    debugPrint('=== DESTINATION SERVICE CALLED ===');
    try {
      debugPrint('=== GETTING CURRENT LOCATION ===');

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint(
          'Location services are disabled - using default Philippines location',
        );
        return _getDefaultPhilippinesLocation();
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permissions denied - requesting...');
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint(
            'Location permissions still denied - using default Philippines location',
          );
          return _getDefaultPhilippinesLocation();
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint(
          'Location permissions permanently denied - using default Philippines location',
        );
        return _getDefaultPhilippinesLocation();
      }

      // Get current position
      debugPrint('✅ Getting GPS position...');
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      debugPrint(
        '✅ Current location: ${position.latitude}, ${position.longitude}',
      );
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      debugPrint(
        'Error getting location: $e - using default Philippines location',
      );
      return _getDefaultPhilippinesLocation();
    }
  }

  static LatLng _getDefaultPhilippinesLocation() {
    return const LatLng(12.8797, 121.7740); // Default to Philippines
  }

  // Get all destinations - using hardcoded data for now
  static Future<List<Destination>> getDestinations() async {
    // Return hardcoded Philippines destinations
    return [
      Destination(
        id: '1',
        name: 'Intramuros',
        description: 'Historic walled city in Manila',
        location: 'Manila, Philippines',
        imageUrl:
            'https://images.unsplash.com/photo-15168893845-c5ad698dfc3e?ixlib=rb-4.0.3&ixid=MnXHtFYYlgI',
        coordinates: const LatLng(14.5995, 120.9842),
        category: DestinationCategory.landmark,
        rating: 4.6,
        budget: BudgetInfo(minCost: 0, maxCost: 200, currency: 'PHP'),
      ),
      Destination(
        id: '2',
        name: 'Boracay',
        description: 'White sand beach destination',
        location: 'Aklan, Philippines',
        imageUrl:
            'https://images.unsplash.com/photo-1520200122962-40bd9afbaef7?ixlib=rb-4.0.3&ixid=MnXHtFYYlgI',
        coordinates: const LatLng(13.2529, 123.7851),
        category: DestinationCategory.activities,
        rating: 4.8,
        budget: BudgetInfo(minCost: 1000, maxCost: 5000, currency: 'PHP'),
      ),
      Destination(
        id: '3',
        name: 'Palawan',
        description: 'Ultimate island paradise',
        location: 'Palawan, Philippines',
        imageUrl:
            'https://images.unsplash.com/photo-1518477328608-e5e3b35a0db?ixlib=rb-4.0.3&ixid=MnXHtFYYlgI',
        coordinates: const LatLng(9.8391, 118.7355),
        category: DestinationCategory.activities,
        rating: 4.9,
        budget: BudgetInfo(minCost: 2000, maxCost: 8000, currency: 'PHP'),
      ),
    ];
  }

  // Get destination by ID
  static Future<Destination?> getDestination(String id) async {
    // First check hardcoded list
    final destinations = await getDestinations();
    try {
      return destinations.firstWhere((dest) => dest.id == id);
    } catch (e) {
      // If not found, it might be a Google Place ID - return null
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

  // Search destinations
  static Future<List<Destination>> searchDestinations(String? query) async {
    try {
      final destinations = await getDestinations();

      if (query != null && query.isNotEmpty) {
        final searchQuery = query.toLowerCase();
        return destinations.where((dest) {
          return dest.name.toLowerCase().contains(searchQuery) ||
              dest.description.toLowerCase().contains(searchQuery) ||
              dest.category.name.toLowerCase().contains(searchQuery);
        }).toList();
      } else {
        return destinations;
      }
    } catch (e) {
      // If API fails, return empty list
      debugPrint('Search failed completely: $e');
      return [];
    }
  }

  static Future<List<Destination>> getTrendingDestinations() async {
    debugPrint('\n=== APP CALLED getTrendingDestinations ===');
    try {
      debugPrint('=== GETTING TRENDING DESTINATIONS FROM GOOGLE PLACES ===');

      // Get current location for nearby search
      final currentLocation = await getCurrentLocation();
      debugPrint('=== LOCATION DEBUG ===');
      debugPrint(
        'Searching from location: ${currentLocation.latitude}, ${currentLocation.longitude}',
      );

      // Detect current city
      final currentCity = getCurrentCity(currentLocation);
      debugPrint('=== CITY DETECTION ===');
      debugPrint('Current city detected as: $currentCity');

      // Search for trending places in the current city
      final trendingQueries = [
        'tourist attractions in $currentCity',
        'popular restaurants in $currentCity',
        'shopping malls in $currentCity',
        'parks in $currentCity',
        'museums in $currentCity',
      ];

      debugPrint('=== SEARCH QUERIES ===');
      for (String query in trendingQueries) {
        debugPrint('Query: $query');
      }

      List<Destination> allTrendingPlaces = [];

      for (String query in trendingQueries) {
        try {
          final places = await GoogleMapsApiService.searchPlaces(
            query: query,
            location: currentLocation,
          );
          debugPrint('Found ${places.length} places for query: "$query"');

          // Take top 2 from each category to get variety
          final convertedPlaces = await Future.wait(
            places
                .map((place) => _convertGooglePlaceToDestination(place))
                .take(2),
          );
          allTrendingPlaces.addAll(convertedPlaces);
        } catch (e) {
          debugPrint('Error searching for "$query": $e');
        }
      }

      // Deduplicate using public helper and then sort
      final deduped = deduplicateDestinationsById(allTrendingPlaces);
      // Sort by rating and take top 6
      deduped.sort((a, b) => b.rating.compareTo(a.rating));
      final topPlaces = deduped.take(6).toList();

      if (topPlaces.isNotEmpty) {
        debugPrint(
          'Returning ${topPlaces.length} trending places from Google Places',
        );
        return topPlaces;
      } else {
        debugPrint('No Google Places results, returning empty list');
        return [];
      }
    } catch (e) {
      debugPrint('Google Places trending failed: $e');
      debugPrint('No fallback data available - returning empty list');

      // Return empty list - no mock data
      return [];
    }
  }

  // Public helper to deduplicate destinations by id (stable order)
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

  static DestinationCategory _parseCategory(List<String> types) {
    // Check for shopping/retail first (highest priority for places like SM)
    if (types.contains('shopping_mall') ||
        types.contains('market') ||
        types.contains('store') ||
        types.contains('supermarket')) {
      return DestinationCategory.market;
    }
    // Then check for food/restaurant
    else if (types.contains('restaurant') ||
        types.contains('food') ||
        types.contains('cafe') ||
        types.contains('bakery')) {
      return DestinationCategory.food;
    }
    // Then check for parks
    else if (types.contains('park') || types.contains('natural_feature')) {
      return DestinationCategory.park;
    }
    // Then check for museums
    else if (types.contains('museum') || types.contains('art_gallery')) {
      return DestinationCategory.museum;
    }
    // Then check for activities/entertainment
    else if (types.contains('amusement_park') ||
        types.contains('zoo') ||
        types.contains('aquarium') ||
        types.contains('stadium') ||
        types.contains('entertainment')) {
      return DestinationCategory.activities;
    }
    // Finally check for landmarks (lowest priority)
    else if (types.contains('landmark') ||
        types.contains('tourist_attraction') ||
        types.contains('historic_site')) {
      return DestinationCategory.landmark;
    }
    // Default to landmark if nothing matches
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

  static Future<Destination?> getDestinationById(String id) async {
    try {
      // Try to get real destination data from API
      // For now, return hardcoded destination data
      return await getDestination(id);
    } catch (e) {
      debugPrint('API get destination failed: $e');
      return null;
    }
  }

  static Future<Destination> _convertGooglePlaceToDestination(
    GooglePlace place,
  ) async {
    debugPrint('=== CONVERTING GOOGLE PLACE ===');
    debugPrint('Place name: ${place.name}');
    debugPrint('Place ID: ${place.placeId}');
    debugPrint('Number of photos: ${place.photos.length}');

    // Get detailed place information including address and description
    String description = place.vicinity;
    String location = place.vicinity;

    try {
      final placeDetails = await GoogleMapsApiService.getPlaceDetails(
        place.placeId,
      );
      if (placeDetails != null) {
        debugPrint('Got detailed information for ${place.name}');

        // Use formatted address if available
        if (placeDetails.formattedAddress.isNotEmpty) {
          location = placeDetails.formattedAddress;
        }

        // Use editorial summary if available, otherwise generate description
        if (placeDetails.editorialSummary != null &&
            placeDetails.editorialSummary!.isNotEmpty) {
          description = placeDetails.editorialSummary!;
        } else {
          // Generate a description based on place type and name
          description = _generateDescription(
            place.name,
            _parseCategory(place.types),
          );
        }

        debugPrint('Final location: $location');
        debugPrint('Final description: $description');
      }
    } catch (e) {
      debugPrint('Error getting place details: $e');
      // Fallback to generated description
      description = _generateDescription(
        place.name,
        _parseCategory(place.types),
      );
    }

    // Get real photo from Google Places if available, otherwise use category placeholder
    String imageUrl;
    if (place.photos.isNotEmpty) {
      // Use the first photo from Google Places
      final photoReference = place.photos.first.photoReference;
      debugPrint('Using photo reference: $photoReference');

      imageUrl = GoogleMapsApiService.getPhotoUrl(
        photoReference,
        maxWidth: 800,
        maxHeight: 600,
      );
      debugPrint('Using Google Places photo for ${place.name}: $imageUrl');
    } else {
      // Fallback to category-based placeholder
      imageUrl = _getCategoryImage(_parseCategory(place.types));
      debugPrint(
        'No photos available for ${place.name}, using category placeholder: $imageUrl',
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

    final String imageUrl;
    if (details.photos.isNotEmpty) {
      imageUrl = GoogleMapsApiService.getPhotoUrl(
        details.photos.first.photoReference,
        maxWidth: 800,
        maxHeight: 600,
      );
    } else {
      imageUrl = _getCategoryImage(category);
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

  // Generate descriptive text based on place name and category
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

  static String _getCategoryImage(DestinationCategory category) {
    return switch (category) {
      DestinationCategory.park =>
        'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?ixlib=rb-4.0.3&ixid=MnXHtFYYlgI',
      DestinationCategory.landmark =>
        'https://images.unsplash.com/photo-15168893845-c5ad698dfc3e?ixlib=rb-4.0.3&ixid=MnXHtFYYlgI',
      DestinationCategory.food =>
        'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?ixlib=rb-4.0.3&ixid=MnXHtFYYlgI',
      DestinationCategory.activities =>
        'https://images.unsplash.com/photo-1520200122962-40bd9afbaef7?ixlib=rb-4.0.3&ixid=MnXHtFYYlgI',
      DestinationCategory.museum =>
        'https://images.unsplash.com/photo-1541961017774-22349e4a1262?ixlib=rb-4.0.3&ixid=MnXHtFYYlgI',
      DestinationCategory.market =>
        'https://images.unsplash.com/photo-1516448483748-2aa0cf52309a?ixlib=rb-4.0.3&ixid=MnXHtFYYlgI',
    };
  }

  // NEW: Search real places using Google Places API
  static Future<List<Destination>> searchRealPlaces({
    required String query,
    LatLng? location,
    DestinationCategory? category,
  }) async {
    try {
      // Get current location if none provided
      final searchLocation = location ?? await getCurrentLocation();
      debugPrint(
        'Using location: ${searchLocation.latitude}, ${searchLocation.longitude}',
      );

      // Build search query based on category
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

      // Add Philippines to get local results but don't force Manila
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
      // Return empty list if all methods fail
      return [];
    }
  }

  // NEW: Get autocomplete suggestions
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
    debugPrint('\n=== APP CALLED searchDestinationsEnhanced ===');
    try {
      debugPrint('=== ENHANCED SEARCH: query="$query", category=$category ===');

      // Get current location for location-based search
      final currentLocation = await getCurrentLocation();

      // Use category-specific search query if category is selected but no search query
      String searchQuery;
      if (query?.isNotEmpty == true) {
        searchQuery = query!;
      } else if (category != null) {
        searchQuery = _getCategoryQuery(category);
        debugPrint('Using category-specific query: "$searchQuery"');
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
      debugPrint('Google Places returned ${realPlaces.length} results');

      // Filter by category if specified
      if (category != null && realPlaces.isNotEmpty) {
        final filtered = realPlaces
            .where((dest) => dest.category == category)
            .toList();
        debugPrint(
          'Filtered to ${filtered.length} results for category $category',
        );
        return filtered;
      }

      if (realPlaces.isNotEmpty) {
        debugPrint('Returning ${realPlaces.length} Google Places results');
        return realPlaces;
      }

      debugPrint('Google Places returned no results');
      return [];
    } catch (e) {
      debugPrint('Enhanced search failed: $e');
      return [];
    }
  }

  // Helper method to convert category to search query
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

  // Helper method for original search logic
  // ignore: unused_element
  static Future<List<Destination>> _searchOriginalDestinations({
    String? query,
    DestinationCategory? category,
  }) async {
    try {
      final destinations = await getDestinations();

      return destinations.where((destination) {
        // Filter by query
        if (query != null && query.isNotEmpty) {
          final searchTerm = query.toLowerCase();
          final matchesName = destination.name.toLowerCase().contains(
            searchTerm,
          );
          final matchesLocation = destination.location.toLowerCase().contains(
            searchTerm,
          );
          final matchesDescription = destination.description
              .toLowerCase()
              .contains(searchTerm);

          if (!matchesName && !matchesLocation && !matchesDescription) {
            return false;
          }
        }

        // Filter by category
        if (category != null && destination.category != category) {
          return false;
        }

        return true;
      }).toList();
    } catch (e) {
      return [];
    }
  }
}
