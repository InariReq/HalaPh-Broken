import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/services/destination_service.dart';

class MapService {
  // Philippines coordinates (center of the country)
  static const LatLng _philippinesCenter = LatLng(12.8797, 121.7740);

  // Public getter for Philippines center
  static LatLng get philippinesCenter => _philippinesCenter;

  // Get current user location - delegates to DestinationService
  static Future<LatLng?> getCurrentLocation() async {
    try {
      return await DestinationService.getCurrentLocation();
    } catch (e) {
      debugPrint('MapService: Error getting location: $e');
      return null;
    }
  }

  // Get coordinates for a destination
  static LatLng getDestinationCoordinates(Destination destination) {
    return destination.coordinates ?? _philippinesCenter;
  }

  // Create markers for destinations
  static Set<Marker> createDestinationMarkers(List<Destination> destinations) {
    return destinations.where((d) => d.coordinates != null).map((dest) {
      return Marker(
        markerId: MarkerId(dest.id),
        position: dest.coordinates!,
        infoWindow: InfoWindow(
          title: dest.name,
          snippet: dest.location,
        ),
      );
    }).toSet();
  }

  // Find destinations near a location
  static List<Destination> findNearbyDestinations(
    List<Destination> destinations,
    LatLng location,
    double radiusKm,
  ) {
    return destinations.where((dest) {
      if (dest.coordinates == null) return false;
      final distance = DestinationService.isInvalidLocation(dest.coordinates!)
          ? double.infinity
          : calculateDistance(location, dest.coordinates!);
      return distance <= radiusKm;
    }).toList();
  }

  // Get camera bounds for multiple coordinates
  static CameraUpdate getCameraBounds(List<LatLng> coordinates) {
    if (coordinates.isEmpty) {
      return CameraUpdate.newLatLngZoom(_philippinesCenter, 6.0);
    }
    double minLat = coordinates.first.latitude;
    double maxLat = coordinates.first.latitude;
    double minLng = coordinates.first.longitude;
    double maxLng = coordinates.first.longitude;

    for (final coord in coordinates) {
      minLat = minLat < coord.latitude ? minLat : coord.latitude;
      maxLat = maxLat > coord.latitude ? maxLat : coord.latitude;
      minLng = minLng < coord.longitude ? minLng : coord.longitude;
      maxLng = maxLng > coord.longitude ? maxLng : coord.longitude;
    }

    return CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      ),
      100.0, // padding
    );
  }

  // Calculate distance between two points
  static double calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371;
    double lat1Rad = point1.latitude * (pi / 180);
    double lat2Rad = point2.latitude * (pi / 180);
    double deltaLatRad = (point2.latitude - point1.latitude) * (pi / 180);
    double deltaLngRad = (point2.longitude - point1.longitude) * (pi / 180);

    double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) *
            cos(lat2Rad) *
            sin(deltaLngRad / 2) *
            sin(deltaLngRad / 2);
    double c = 2 * asin(sqrt(a).clamp(0.0, 1.0));
    return earthRadius * c;
  }
}
