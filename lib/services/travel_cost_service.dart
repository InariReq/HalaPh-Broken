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

      // Use OSRM for FREE routing (no billing needed!)
      final osmResult = await OSMService.getDirections(
        startLat: from.latitude,
        startLon: from.longitude,
        endLat: destination.latitude,
        endLon: destination.longitude,
        profile: 'driving',
      );

      if (osmResult != null) {
        final distanceKm = (osmResult['distance'] as num) / 1000.0;
        final durationMin = (osmResult['duration'] as num) / 60.0;

        debugPrint(
          '🌍 OSRM: ${distanceKm.toStringAsFixed(1)}km, ${durationMin.toStringAsFixed(0)}min (FREE)',
        );

        // Calculate rough costs based on distance and mode
        return [
          TravelCostEstimate(
            mode: 'driving',
            durationMinutes: durationMin.round(),
            estimatedCost: _estimateCost(distanceKm, 'driving'),
            description: 'Drive via OSRM (FREE)',
          ),
          TravelCostEstimate(
            mode: 'walking',
            durationMinutes: (durationMin * 3).round(),
            estimatedCost: 0,
            description: 'Walk (FREE)',
          ),
          TravelCostEstimate(
            mode: 'bicycling',
            durationMinutes: (durationMin * 1.5).round(),
            estimatedCost: 0,
            description: 'Bike via OSRM (FREE)',
          ),
        ];
      }

      debugPrint('🌍 OSRM failed, using fallback estimates');
      return _fallbackEstimates(from, destination);
    } catch (e) {
      debugPrint('🌍 Travel cost error: $e');
      return _fallbackEstimates(origin, destination);
    }
  }

  static double _estimateCost(double distanceKm, String mode) {
    switch (mode) {
      case 'driving':
        return distanceKm * 12.0; // ~₱12/km for fuel/maintenance
      case 'jeepney':
        return distanceKm * 2.0; // ~₱2/km for jeepney
      case 'bus':
        return distanceKm * 3.0; // ~₱3/km for bus
      case 'train':
        return 28.0; // Fixed MRT/LRT fare
      case 'fx':
        return 30.0; // Fixed FX fare
      default:
        return distanceKm * 5.0;
    }
  }

  static List<TravelCostEstimate> _fallbackEstimates(
    LatLng? origin,
    LatLng destination,
  ) {
    final distance = origin != null
        ? DestinationService._calculateDistance(origin, destination)
        : 5.0;

    return [
      TravelCostEstimate(
        mode: 'walking',
        durationMinutes: (distance * 15).round(),
        estimatedCost: 0,
        description: 'Walk (FREE)',
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
}
