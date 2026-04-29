import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:halaph/models/destination.dart';

class MapService {
  // Philippines coordinates (center of the country)
  static const LatLng _philippinesCenter = LatLng(12.8797, 121.7740);

  // Public getter for Philippines center
  static LatLng get philippinesCenter => _philippinesCenter;

  // Popular destination coordinates
  static const Map<String, LatLng> _destinationCoordinates = {
    'manila': LatLng(14.5995, 120.9842),
    'cebu': LatLng(10.3157, 123.8854),
    'boracay': LatLng(11.9674, 121.9248),
    'palawan': LatLng(9.8667, 118.7333),
    'bohol': LatLng(9.8528, 124.1447),
    'davao': LatLng(7.0731, 125.6128),
    'siargao': LatLng(9.8461, 126.0509),
    'intramuros': LatLng(14.5894, 120.9773),
    'rizal-park': LatLng(14.5847, 120.9809),
    'binondo': LatLng(14.6000, 120.9765),
    'bonifacio-global-city': LatLng(14.5505, 121.0323),
    'national-museum': LatLng(14.5833, 120.9797),
    'quiapo-church': LatLng(14.6006, 120.9835),
    'greenbelt-mall': LatLng(14.5535, 121.0255),
    'divisoria-market': LatLng(14.6031, 120.9822),
  };

  static Position? _cachedPosition;
  static DateTime? _positionCacheTime;
  static const _cacheValidity = Duration(minutes: 5);

  // Get current user location with retry logic and caching
  static Future<Position?> getCurrentLocation() async {
    try {
      // Use cached position if recent
      if (_cachedPosition != null &&
          _positionCacheTime != null &&
          DateTime.now().difference(_positionCacheTime!) < _cacheValidity) {
        debugPrint(
          'Using cached position: ${_cachedPosition!.latitude}, ${_cachedPosition!.longitude}',
        );
        return _cachedPosition;
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled');
        return _cachedPosition;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Requesting location permission...');
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied');
          return _cachedPosition;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied');
        return _cachedPosition;
      }

      // Get current position with retries
      Position? position;
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          debugPrint('Getting position, attempt $attempt...');
          final settings = LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 15),
          );
          position = await Geolocator.getCurrentPosition(
            locationSettings: settings,
          );
          break;
        } catch (e) {
          debugPrint('Position attempt $attempt failed: $e');
          if (attempt < 3) {
            await Future.delayed(Duration(seconds: attempt));
          }
        }
      }

      if (position == null) {
        // Try last known position
        try {
          debugPrint('Trying last known position...');
          position = await Geolocator.getLastKnownPosition();
        } catch (e) {
          debugPrint('Failed to get last known position: $e');
        }
      }

      if (position != null) {
        _cachedPosition = position;
        _positionCacheTime = DateTime.now();
        debugPrint(
          'Current position: ${position.latitude}, ${position.longitude}',
        );
      }

      return position ?? _cachedPosition;
    } catch (e) {
      debugPrint('Failed to get location: $e');
      return _cachedPosition;
    }
  }

  // Get coordinates for a destination
  static LatLng getDestinationCoordinates(Destination destination) {
    if (destination.coordinates != null) return destination.coordinates!;

    // Try to find exact match
    final lowerCaseName = destination.name.toLowerCase();
    final lowerCaseLocation = destination.location.toLowerCase();

    // Check destination name first
    for (final entry in _destinationCoordinates.entries) {
      if (lowerCaseName.contains(entry.key) ||
          lowerCaseLocation.contains(entry.key)) {
        return entry.value;
      }
    }

    // Fallback to city-based coordinates
    if (lowerCaseLocation.contains('manila')) {
      return _destinationCoordinates['manila']!;
    }
    if (lowerCaseLocation.contains('cebu')) {
      return _destinationCoordinates['cebu']!;
    }
    if (lowerCaseLocation.contains('boracay')) {
      return _destinationCoordinates['boracay']!;
    }
    if (lowerCaseLocation.contains('palawan')) {
      return _destinationCoordinates['palawan']!;
    }
    if (lowerCaseLocation.contains('bohol')) {
      return _destinationCoordinates['bohol']!;
    }
    if (lowerCaseLocation.contains('davao')) {
      return _destinationCoordinates['davao']!;
    }
    if (lowerCaseLocation.contains('siargao')) {
      return _destinationCoordinates['siargao']!;
    }

    // Default to Philippines center
    return _philippinesCenter;
  }

  // Create markers for destinations
  static Set<Marker> createDestinationMarkers(List<Destination> destinations) {
    return destinations.map((destination) {
      final coordinates = getDestinationCoordinates(destination);
      return Marker(
        markerId: MarkerId(destination.id),
        position: coordinates,
        infoWindow: InfoWindow(
          title: destination.name,
          snippet: destination.location,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          _getMarkerColor(destination.category),
        ),
      );
    }).toSet();
  }

  // Get marker color based on destination category
  static double _getMarkerColor(DestinationCategory category) {
    switch (category) {
      case DestinationCategory.landmark:
        return BitmapDescriptor.hueRed;
      case DestinationCategory.park:
        return BitmapDescriptor.hueGreen;
      case DestinationCategory.food:
        return BitmapDescriptor.hueOrange;
      case DestinationCategory.activities:
        return BitmapDescriptor.hueBlue;
      case DestinationCategory.museum:
        return BitmapDescriptor.hueViolet;
      case DestinationCategory.market:
        return BitmapDescriptor.hueYellow;
    }
  }

  // Calculate distance between two points (in kilometers) using haversine formula
  static double calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371.0; // kilometers
    double dLat = _deg2rad(point2.latitude - point1.latitude);
    double dLon = _deg2rad(point2.longitude - point1.longitude);
    double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(point1.latitude)) *
            math.cos(_deg2rad(point2.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _deg2rad(double deg) {
    return deg * (math.pi / 180.0);
  }

  // Find nearby destinations within radius (in kilometers)
  static List<Destination> findNearbyDestinations(
    List<Destination> destinations,
    LatLng userLocation,
    double radiusKm,
  ) {
    return destinations.where((destination) {
      final destinationCoords = getDestinationCoordinates(destination);
      final distance = calculateDistance(userLocation, destinationCoords);
      return distance <= radiusKm;
    }).toList();
  }

  // Get camera bounds for multiple destinations
  static CameraUpdate getCameraBounds(List<LatLng> coordinates) {
    if (coordinates.isEmpty) {
      return CameraUpdate.newLatLngZoom(_philippinesCenter, 6.0);
    }

    if (coordinates.length == 1) {
      return CameraUpdate.newLatLngZoom(coordinates.first, 12.0);
    }

    double minLat = coordinates.first.latitude;
    double maxLat = coordinates.first.latitude;
    double minLng = coordinates.first.longitude;
    double maxLng = coordinates.first.longitude;

    for (final coord in coordinates) {
      minLat = math.min(minLat, coord.latitude);
      maxLat = math.max(maxLat, coord.latitude);
      minLng = math.min(minLng, coord.longitude);
      maxLng = math.max(maxLng, coord.longitude);
    }

    if ((maxLat - minLat).abs() < 0.0005) {
      maxLat += 0.0005;
      minLat -= 0.0005;
    }
    if ((maxLng - minLng).abs() < 0.0005) {
      maxLng += 0.0005;
      minLng -= 0.0005;
    }

    return CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      ),
      100.0, // padding
    );
  }
}

// Extension for math functions
extension MathExtensions on double {
  double sin() => math.sin(this);
  double cos() => math.cos(this);
  double asin() => math.asin(this);
  double sqrt() => math.sqrt(this);
}
