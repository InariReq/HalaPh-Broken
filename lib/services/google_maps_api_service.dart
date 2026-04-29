import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GoogleMapsApiService {
  // ignore: unused_field
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api';
  static const Duration _requestTimeout = Duration(seconds: 12);
  static String? _apiKey;

  static bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  static void _logMissingApiKey() {
    debugPrint('Google Maps API key is not configured. Check your .env file.');
  }

  static void _loadApiKey() {
    if (_apiKey == null || _apiKey!.isEmpty) {
      try {
        _apiKey = dotenv.env['MAPS_API_KEY']?.trim();
        if (_apiKey == null || _apiKey!.isEmpty) {
          debugPrint('ERROR: MAPS_API_KEY not found in .env file. Please add it.');
          debugPrint('Current .env keys: ${dotenv.env.keys.join(', ')}');
        } else {
          debugPrint('Google Maps API key loaded successfully');
        }
      } catch (e) {
        debugPrint('Error loading MAPS_API_KEY: $e');
      }
    }
  }

  // Geocoding API - Convert address to coordinates
  static Future<LatLng?> geocodeAddress(String address) async {
    _loadApiKey();
    if (!isConfigured) {
      _logMissingApiKey();
      return null;
    }

    debugPrint('=== GOOGLE GEOCODING API ===');
    debugPrint('Geocoding address: "$address"');

    final params = {'address': address, 'key': _apiKey};

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      params,
    );

    try {
      final response = await http.get(uri).timeout(_requestTimeout);
      debugPrint('Geocoding response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Geocoding API status: ${data['status']}');

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          final coordinates = LatLng(location['lat'], location['lng']);
          debugPrint(
            'Geocoded "$address" to: ${coordinates.latitude}, ${coordinates.longitude}',
          );
          return coordinates;
        } else {
          debugPrint(
            'Geocoding failed: ${data['status']} - ${data['error_message'] ?? 'No error message'}',
          );
        }
      }
    } catch (e) {
      debugPrint('Geocoding API error: $e');
    }

    return null;
  }

  // Reverse Geocoding API - Convert coordinates to address
  static Future<String?> reverseGeocode(LatLng coordinates) async {
    _loadApiKey();
    if (!isConfigured) {
      _logMissingApiKey();
      return null;
    }

    debugPrint('=== GOOGLE REVERSE GEOCODING API ===');
    debugPrint(
      'Reverse geocoding: ${coordinates.latitude}, ${coordinates.longitude}',
    );

    final params = {
      'latlng': '${coordinates.latitude},${coordinates.longitude}',
      'key': _apiKey,
    };

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      params,
    );

    try {
      final response = await http.get(uri).timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final address = data['results'][0]['formatted_address'];
          debugPrint('Reverse geocoded to: "$address"');
          return address;
        }
      }
    } catch (e) {
      debugPrint('Reverse geocoding error: $e');
    }

    return null;
  }

  // Directions API - Get real directions between two points
  static Future<GoogleDirectionsResponse?> getDirections({
    required LatLng origin,
    required LatLng destination,
    String? travelMode = 'driving', // driving, walking, bicycling, transit
    String? departureTime,
  }) async {
    _loadApiKey();
    if (!isConfigured) {
      _logMissingApiKey();
      return null;
    }

    debugPrint('=== GOOGLE DIRECTIONS API ===');
    debugPrint(
      'Getting directions from ${origin.latitude},${origin.longitude} to ${destination.latitude},${destination.longitude}',
    );
    debugPrint('Travel mode: $travelMode');

    final params = {
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'mode': travelMode ?? 'driving',
      'alternatives': 'true',
      'key': _apiKey,
    };

    // Add departure time for transit mode
    if (travelMode == 'transit' && departureTime != null) {
      params['departure_time'] = departureTime;
    }

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/directions/json',
      params,
    );

    try {
      final response = await http.get(uri).timeout(_requestTimeout);
      debugPrint('Directions API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Directions API status: ${data['status']}');

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final directionsResponse = GoogleDirectionsResponse.fromJson(data);
          debugPrint(
            'Found ${directionsResponse.routes.length} routes with ${directionsResponse.routes.first.legs.length} legs',
          );
          return directionsResponse;
        } else {
          debugPrint(
            'Directions API failed: ${data['status']} - ${data['error_message'] ?? 'No error message'}',
          );
        }
      }
    } catch (e) {
      debugPrint('Directions API error: $e');
    }

    return null;
  }

  // Get multiple travel modes for the same route
  static Future<List<GoogleDirectionsResponse>> getAllDirectionsModes({
    required LatLng origin,
    required LatLng destination,
  }) async {
    _loadApiKey();
    if (!isConfigured) {
      _logMissingApiKey();
      return [];
    }

    final List<GoogleDirectionsResponse> allRoutes = [];

    // Add current time for transit departure
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final travelModes = [
      {'mode': 'walking', 'departure_time': null},
      {'mode': 'transit', 'departure_time': now.toString()},
    ];

    for (final modeConfig in travelModes) {
      try {
        debugPrint('Trying ${modeConfig['mode']} mode...');
        final directions = await getDirections(
          origin: origin,
          destination: destination,
          travelMode: modeConfig['mode'] as String,
          departureTime: modeConfig['departure_time'],
        );

        if (directions != null) {
          allRoutes.add(directions);
          debugPrint('Successfully got ${modeConfig['mode']} directions');
        } else {
          debugPrint('No directions returned for ${modeConfig['mode']} mode');
        }
      } catch (e) {
        debugPrint('Error getting ${modeConfig['mode']} directions: $e');
      }
    }

    debugPrint(
      'Got directions for ${allRoutes.length} travel modes out of ${travelModes.length} requested',
    );
    return allRoutes;
  }

  // Places Text Search API - Find places by name/query
  static Future<List<GooglePlace>> searchPlaces({
    required String query,
    LatLng? location,
    double radius = 10000, // 10km radius
  }) async {
    _loadApiKey();
    if (!isConfigured) {
      _logMissingApiKey();
      return [];
    }

    debugPrint('=== GOOGLE PLACES TEXT SEARCH ===');
    debugPrint('Searching for: "$query"');
    if (location != null) {
      debugPrint('Near location: ${location.latitude},${location.longitude}');
    }

    final params = {'query': query, 'key': _apiKey};

    // Add location and radius if provided
    if (location != null) {
      params['location'] = '${location.latitude},${location.longitude}';
      params['radius'] = radius.toString();
    }

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/textsearch/json',
      params,
    );
    debugPrint('Google Places API URL: $uri');

    try {
      final response = await http.get(uri).timeout(_requestTimeout);
      debugPrint('Places search response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Places search status: ${data['status']}');

        if (data['status'] == 'OK') {
          final places = (data['results'] as List)
              .map((place) => GooglePlace.fromJson(place))
              .toList();
          debugPrint('Found ${places.length} places for "$query"');

          // Print first few results for debugging
          for (int i = 0; i < places.length && i < 3; i++) {
            final place = places[i];
            debugPrint(
              '  ${i + 1}. ${place.name} at ${place.location.latitude},${place.location.longitude}',
            );
          }

          return places;
        } else {
          debugPrint(
            'Places search failed: ${data['status']} - ${data['error_message'] ?? 'No error message'}',
          );
        }
      }
    } catch (e) {
      debugPrint('Places search error: $e');
    }

    return [];
  }

  // Places API - Find places near a location
  static Future<List<GooglePlace>> findNearbyPlaces({
    required LatLng location,
    required String placeType,
    double radius = 1000, // meters
  }) async {
    _loadApiKey();
    if (!isConfigured) {
      _logMissingApiKey();
      return [];
    }

    debugPrint('=== GOOGLE PLACES NEARBY SEARCH ===');
    debugPrint(
      'Finding $placeType near ${location.latitude},${location.longitude} within ${radius}m',
    );

    final params = {
      'location': '${location.latitude},${location.longitude}',
      'radius': radius.toString(),
      'type': placeType,
      'key': _apiKey,
    };

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/nearbysearch/json',
      params,
    );

    try {
      final response = await http.get(uri).timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final places = (data['results'] as List)
              .map((place) => GooglePlace.fromJson(place))
              .toList();
          debugPrint('Found ${places.length} nearby $placeType places');
          return places;
        }
      }
    } catch (e) {
      debugPrint('Nearby places error: $e');
    }

    return [];
  }

  // Places Photos API - Get photo URL from photo reference
  static String getPhotoUrl(
    String photoReference, {
    int maxWidth = 400,
    int maxHeight = 400,
  }) {
    _loadApiKey();
    if (!isConfigured) {
      _logMissingApiKey();
      return '';
    }

    debugPrint('=== GOOGLE PLACES PHOTO API ===');
    debugPrint('Getting photo for reference: $photoReference');

    final params = {
      'maxwidth': maxWidth.toString(),
      'maxheight': maxHeight.toString(),
      'photo_reference': photoReference,
      'key': _apiKey,
    };

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/photo',
      params,
    );
    debugPrint('Generated photo URL: $uri');
    return uri.toString();
  }

  // Place Details API - Get detailed information about a place
  static Future<GooglePlaceDetails?> getPlaceDetails(String placeId) async {
    _loadApiKey();
    if (!isConfigured) {
      _logMissingApiKey();
      return null;
    }

    debugPrint('=== GOOGLE PLACE DETAILS API ===');
    debugPrint('Getting details for place ID: $placeId');

    final params = {
      'place_id': placeId,
      'fields':
          'place_id,name,formatted_address,formatted_phone_number,rating,reviews,photos,types,editorial_summary,website,geometry',
      'key': _apiKey,
    };

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      params,
    );

    try {
      final response = await http.get(uri).timeout(_requestTimeout);
      debugPrint('Place details response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Place details status: ${data['status']}');

        if (data['status'] == 'OK' && data['result'] != null) {
          final placeDetails = GooglePlaceDetails.fromJson(data['result']);
          debugPrint('Successfully got details for ${placeDetails.name}');
          return placeDetails;
        } else {
          debugPrint(
            'Place details failed: ${data['status']} - ${data['error_message'] ?? 'No error message'}',
          );
        }
      }
    } catch (e) {
      debugPrint('Place details API error: $e');
    }

    return null;
  }
}

// Models for Google API responses

class GoogleDirectionsResponse {
  final List<GoogleRoute> routes;
  final List<GoogleGeocodedWaypoint> geocodedWaypoints;
  final String status;

  GoogleDirectionsResponse({
    required this.routes,
    required this.geocodedWaypoints,
    required this.status,
  });

  factory GoogleDirectionsResponse.fromJson(Map<String, dynamic> json) {
    return GoogleDirectionsResponse(
      routes: (json['routes'] as List)
          .map((route) => GoogleRoute.fromJson(route))
          .toList(),
      geocodedWaypoints: (json['geocoded_waypoints'] as List)
          .map((waypoint) => GoogleGeocodedWaypoint.fromJson(waypoint))
          .toList(),
      status: json['status'],
    );
  }
}

class GoogleRoute {
  final List<GoogleLeg> legs;
  final String overviewPolyline;
  final List<String> warnings;
  final GoogleBounds bounds;
  final String summary;
  final GoogleFare? fare;

  GoogleRoute({
    required this.legs,
    required this.overviewPolyline,
    required this.warnings,
    required this.bounds,
    required this.summary,
    this.fare,
  });

  factory GoogleRoute.fromJson(Map<String, dynamic> json) {
    return GoogleRoute(
      legs: (json['legs'] as List)
          .map((leg) => GoogleLeg.fromJson(leg))
          .toList(),
      overviewPolyline: json['overview_polyline']['points'],
      warnings: List<String>.from(json['warnings'] ?? []),
      bounds: GoogleBounds.fromJson(json['bounds']),
      summary: json['summary'] ?? '',
      fare: json['fare'] != null ? GoogleFare.fromJson(json['fare']) : null,
    );
  }

  Duration get totalDuration {
    int totalSeconds = 0;
    for (final leg in legs) {
      totalSeconds += leg.duration.value;
    }
    return Duration(seconds: totalSeconds);
  }

  double get totalDistance {
    double totalMeters = 0;
    for (final leg in legs) {
      totalMeters += leg.distance.value;
    }
    return totalMeters / 1000; // Convert to km
  }
}

class GoogleLeg {
  final List<GoogleStep> steps;
  final GoogleDistance distance;
  final GoogleDuration duration;
  final String startAddress;
  final String endAddress;
  final LatLng startLocation;
  final LatLng endLocation;

  GoogleLeg({
    required this.steps,
    required this.distance,
    required this.duration,
    required this.startAddress,
    required this.endAddress,
    required this.startLocation,
    required this.endLocation,
  });

  factory GoogleLeg.fromJson(Map<String, dynamic> json) {
    return GoogleLeg(
      steps: (json['steps'] as List)
          .map((step) => GoogleStep.fromJson(step))
          .toList(),
      distance: GoogleDistance.fromJson(json['distance']),
      duration: GoogleDuration.fromJson(json['duration']),
      startAddress: json['start_address'],
      endAddress: json['end_address'],
      startLocation: LatLng(
        json['start_location']['lat'],
        json['start_location']['lng'],
      ),
      endLocation: LatLng(
        json['end_location']['lat'],
        json['end_location']['lng'],
      ),
    );
  }
}

class GoogleStep {
  final GoogleDistance distance;
  final GoogleDuration duration;
  final LatLng startLocation;
  final LatLng endLocation;
  final String htmlInstructions;
  final String maneuver;
  final String travelMode;
  final String polyline;
  final GoogleTransitDetails? transitDetails;
  final List<GoogleStep> subSteps;

  GoogleStep({
    required this.distance,
    required this.duration,
    required this.startLocation,
    required this.endLocation,
    required this.htmlInstructions,
    required this.maneuver,
    required this.travelMode,
    required this.polyline,
    this.transitDetails,
    this.subSteps = const [],
  });

  factory GoogleStep.fromJson(Map<String, dynamic> json) {
    return GoogleStep(
      distance: GoogleDistance.fromJson(json['distance']),
      duration: GoogleDuration.fromJson(json['duration']),
      startLocation: LatLng(
        json['start_location']['lat'],
        json['start_location']['lng'],
      ),
      endLocation: LatLng(
        json['end_location']['lat'],
        json['end_location']['lng'],
      ),
      htmlInstructions: json['html_instructions'] ?? '',
      maneuver: json['maneuver'] ?? '',
      travelMode: json['travel_mode'] ?? '',
      polyline: json['polyline']?['points'] ?? '',
      transitDetails: json['transit_details'] != null
          ? GoogleTransitDetails.fromJson(json['transit_details'])
          : null,
      subSteps:
          (json['steps'] as List?)
              ?.map((step) => GoogleStep.fromJson(step))
              .toList() ??
          const [],
    );
  }
}

class GoogleTransitDetails {
  final GoogleTransitStop departureStop;
  final GoogleTransitStop arrivalStop;
  final String departureTimeText;
  final String arrivalTimeText;
  final String headsign;
  final int numStops;
  final GoogleTransitLine line;

  GoogleTransitDetails({
    required this.departureStop,
    required this.arrivalStop,
    required this.departureTimeText,
    required this.arrivalTimeText,
    required this.headsign,
    required this.numStops,
    required this.line,
  });

  factory GoogleTransitDetails.fromJson(Map<String, dynamic> json) {
    return GoogleTransitDetails(
      departureStop: GoogleTransitStop.fromJson(json['departure_stop'] ?? {}),
      arrivalStop: GoogleTransitStop.fromJson(json['arrival_stop'] ?? {}),
      departureTimeText: json['departure_time']?['text'] ?? '',
      arrivalTimeText: json['arrival_time']?['text'] ?? '',
      headsign: json['headsign'] ?? '',
      numStops: json['num_stops'] ?? 0,
      line: GoogleTransitLine.fromJson(json['line'] ?? {}),
    );
  }
}

class GoogleTransitStop {
  final String name;
  final LatLng? location;

  GoogleTransitStop({required this.name, this.location});

  factory GoogleTransitStop.fromJson(Map<String, dynamic> json) {
    final location = json['location'];
    LatLng? latLng;
    if (location is Map && location['lat'] != null && location['lng'] != null) {
      latLng = LatLng(
        (location['lat'] as num).toDouble(),
        (location['lng'] as num).toDouble(),
      );
    }
    return GoogleTransitStop(name: json['name'] ?? '', location: latLng);
  }
}

class GoogleTransitLine {
  final String name;
  final String shortName;
  final String color;
  final String textColor;
  final String vehicleName;
  final String vehicleType;

  GoogleTransitLine({
    required this.name,
    required this.shortName,
    required this.color,
    required this.textColor,
    required this.vehicleName,
    required this.vehicleType,
  });

  factory GoogleTransitLine.fromJson(Map<String, dynamic> json) {
    final vehicle = json['vehicle'] ?? {};
    return GoogleTransitLine(
      name: json['name'] ?? '',
      shortName: json['short_name'] ?? '',
      color: json['color'] ?? '',
      textColor: json['text_color'] ?? '',
      vehicleName: vehicle['name'] ?? '',
      vehicleType: vehicle['type'] ?? '',
    );
  }
}

class GoogleFare {
  final String text;
  final double value;
  final String currency;

  GoogleFare({required this.text, required this.value, required this.currency});

  factory GoogleFare.fromJson(Map<String, dynamic> json) {
    return GoogleFare(
      text: json['text'] ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] ?? '',
    );
  }
}

class GoogleDistance {
  final String text;
  final double value;

  GoogleDistance({required this.text, required this.value});

  factory GoogleDistance.fromJson(Map<String, dynamic> json) {
    return GoogleDistance(text: json['text'], value: json['value'].toDouble());
  }
}

class GoogleDuration {
  final String text;
  final int value;

  GoogleDuration({required this.text, required this.value});

  factory GoogleDuration.fromJson(Map<String, dynamic> json) {
    return GoogleDuration(text: json['text'], value: json['value']);
  }
}

class GoogleBounds {
  final LatLng northeast;
  final LatLng southwest;

  GoogleBounds({required this.northeast, required this.southwest});

  factory GoogleBounds.fromJson(Map<String, dynamic> json) {
    return GoogleBounds(
      northeast: LatLng(json['northeast']['lat'], json['northeast']['lng']),
      southwest: LatLng(json['southwest']['lat'], json['southwest']['lng']),
    );
  }
}

class GoogleGeocodedWaypoint {
  final String geocoderStatus;
  final String placeId;
  final List<String> types;

  GoogleGeocodedWaypoint({
    required this.geocoderStatus,
    required this.placeId,
    required this.types,
  });

  factory GoogleGeocodedWaypoint.fromJson(Map<String, dynamic> json) {
    return GoogleGeocodedWaypoint(
      geocoderStatus: json['geocoder_status'],
      placeId: json['place_id'],
      types: List<String>.from(json['types'] ?? []),
    );
  }
}

class GooglePlace {
  final String placeId;
  final String name;
  final LatLng location;
  final String vicinity;
  final List<String> types;
  final double rating;
  final List<GooglePlacePhoto> photos;

  GooglePlace({
    required this.placeId,
    required this.name,
    required this.location,
    required this.vicinity,
    required this.types,
    required this.rating,
    required this.photos,
  });

  factory GooglePlace.fromJson(Map<String, dynamic> json) {
    return GooglePlace(
      placeId: json['place_id'],
      name: json['name'],
      location: LatLng(
        json['geometry']['location']['lat'],
        json['geometry']['location']['lng'],
      ),
      vicinity: json['vicinity'] ?? '',
      types: List<String>.from(json['types'] ?? []),
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      photos:
          (json['photos'] as List?)
              ?.map((photo) => GooglePlacePhoto.fromJson(photo))
              .toList() ??
          [],
    );
  }
}

class GooglePlacePhoto {
  final String photoReference;
  final int height;
  final int width;

  GooglePlacePhoto({
    required this.photoReference,
    required this.height,
    required this.width,
  });

  factory GooglePlacePhoto.fromJson(Map<String, dynamic> json) {
    return GooglePlacePhoto(
      photoReference: json['photo_reference'],
      height: json['height'] ?? 400,
      width: json['width'] ?? 400,
    );
  }
}

class GooglePlaceDetails {
  final String placeId;
  final String name;
  final String formattedAddress;
  final String? formattedPhoneNumber;
  final double rating;
  final List<String> types;
  final List<GooglePlacePhoto> photos;
  final String? editorialSummary;
  final String? website;
  final LatLng? location;

  GooglePlaceDetails({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    this.formattedPhoneNumber,
    required this.rating,
    required this.types,
    required this.photos,
    this.editorialSummary,
    this.website,
    this.location,
  });

  factory GooglePlaceDetails.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry']?['location'];
    LatLng? latLng;
    if (geometry is Map && geometry['lat'] != null && geometry['lng'] != null) {
      latLng = LatLng(
        (geometry['lat'] as num).toDouble(),
        (geometry['lng'] as num).toDouble(),
      );
    }

    return GooglePlaceDetails(
      placeId: json['place_id'] ?? '',
      name: json['name'] ?? '',
      formattedAddress: json['formatted_address'] ?? '',
      formattedPhoneNumber: json['formatted_phone_number'],
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      types: List<String>.from(json['types'] ?? []),
      photos:
          (json['photos'] as List?)
              ?.map((photo) => GooglePlacePhoto.fromJson(photo))
              .toList() ??
          [],
      editorialSummary: json['editorial_summary']?['overview'],
      website: json['website'],
      location: latLng,
    );
  }
}
