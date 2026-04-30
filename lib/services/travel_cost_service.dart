import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:halaph/services/osm_service.dart';
import 'package:halaph/services/destination_service.dart';

class TravelCostEstimate {
  final String mode;
  final int durationMinutes;
  final double estimatedCost;
  final String description;

  TravelCostEstimate({
    required this.mode,
    required this.durationMinutes,
    required this.estimatedCost,
    required this.description,
  });
}

class TravelCostService {
  // Get travel cost estimates using FREE OSRM + OSM
  static Future<List<TravelCostEstimate>> getTravelCostEstimates(
    LatLng destination, {
    LatLng? origin,
  }) async {
    try {
      final from = origin ?? await DestinationService.getCurrentLocation();
      debugPrint('=== TRAVEL COST SERVICE ===');
      debugPrint('From: ${from.latitude}, ${from.longitude}');
      debugPrint('To: ${destination.latitude}, ${destination.longitude}');

      // Use OSRM only for rough walking distance/duration. Commute options are
      // estimated from that distance; no private-car option is exposed.
      final osmResult = await OSMService.getDirections(
        startLat: from.latitude,
        startLon: from.longitude,
        endLat: destination.latitude,
        endLon: destination.longitude,
        profile: 'walking',
      );

      if (osmResult != null) {
        final distanceKm = (osmResult['distance'] as num) / 1000.0;
        final durationMin = (osmResult['duration'] as num) / 60.0;

        debugPrint(
          '🌍 OSRM: ${distanceKm.toStringAsFixed(1)}km, ${durationMin.toStringAsFixed(0)}min (FREE)',
        );

        return _commuteEstimates(distanceKm, walkingMinutes: durationMin);
      }

      debugPrint('🌍 OSRM failed, using fallback estimates');
      return _fallbackEstimates(from, destination);
    } catch (e) {
      debugPrint('🌍 Travel cost error: $e');
      return _fallbackEstimates(origin, destination);
    }
  }

  static List<TravelCostEstimate> _commuteEstimates(
    double distance, {
    double? walkingMinutes,
  }) {
    return [
      TravelCostEstimate(
        mode: 'walking',
        durationMinutes: (walkingMinutes ?? distance * 15).round(),
        estimatedCost: 0,
        description: 'Walk',
      ),
      TravelCostEstimate(
        mode: 'jeepney',
        durationMinutes: (distance * 3).round(),
        estimatedCost: (distance * 2).roundToDouble(),
        description: 'Traditional jeepney',
      ),
      TravelCostEstimate(
        mode: 'fx',
        durationMinutes: (distance * 2).round(),
        estimatedCost: 30,
        description: 'UV/FX express',
      ),
      TravelCostEstimate(
        mode: 'bus',
        durationMinutes: (distance * 2.5).round(),
        estimatedCost: (distance * 3).roundToDouble(),
        description: 'City bus',
      ),
      TravelCostEstimate(
        mode: 'train',
        durationMinutes: (distance * 2).round(),
        estimatedCost: 28,
        description: 'MRT/LRT train',
      ),
    ]..sort((a, b) => a.estimatedCost.compareTo(b.estimatedCost));
  }

  static double calculateDistance(LatLng point1, LatLng point2) {
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

  static List<TravelCostEstimate> _fallbackEstimates(
    LatLng? origin,
    LatLng destination,
  ) {
    final distance = origin != null
        ? calculateDistance(origin, destination)
        : 5.0;

    return _commuteEstimates(distance);
  }
}
