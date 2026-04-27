import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:halaph/services/destination_service.dart';
import 'package:halaph/services/google_maps_api_service.dart';

class TravelCostEstimate {
  final String travelMode;
  final Duration duration;
  final double distance;
  final double estimatedCost;

  TravelCostEstimate({
    required this.travelMode,
    required this.duration,
    required this.distance,
    required this.estimatedCost,
  });
}

class TravelCostService {
  // Cost estimation constants (in PHP)
  static const double _grabBaseFare = 40.0;
  static const double _grabPerKm = 13.0;
  static const double _jeepneyFare = 12.0; // Minimum jeepney fare
  static const double _jeepneyPerKm = 1.5;

  static Future<List<TravelCostEstimate>> getTravelCostEstimates(
    LatLng destination,
  ) async {
    try {
      // Get current location
      final currentLocation = await DestinationService.getCurrentLocation();
      
      // Get directions for different travel modes
      final directions = await GoogleMapsApiService.getAllDirectionsModes(
        origin: currentLocation,
        destination: destination,
      );

      List<TravelCostEstimate> estimates = [];

      for (final direction in directions) {
        if (direction.routes.isNotEmpty) {
          final route = direction.routes.first;
          final travelMode = _getTravelModeFromRequest(direction);
          final distance = route.totalDistance;
          final duration = route.totalDuration;
          final cost = _estimateCost(travelMode, distance);

          estimates.add(TravelCostEstimate(
            travelMode: travelMode,
            duration: duration,
            distance: distance,
            estimatedCost: cost,
          ));
        }
      }

      return estimates;
    } catch (e) {
      debugPrint('Error getting travel cost estimates: $e');
      return [];
    }
  }

  static String _getTravelModeFromRequest(dynamic direction) {
    // This is a simplified approach - in a real implementation,
    // you'd need to track which mode was used for each request
    // For now, we'll return a default
    return 'driving';
  }

  static double _estimateCost(String travelMode, double distanceInKm) {
    switch (travelMode.toLowerCase()) {
      case 'driving':
        // Estimate using Grab/ride-hailing rates
        return _grabBaseFare + (_grabPerKm * distanceInKm);
      case 'transit':
        // Estimate using public transport (jeepney + possible LRT/MRT)
        return _jeepneyFare + (_jeepneyPerKm * distanceInKm);
      case 'walking':
        return 0.0; // Walking is free!
      case 'cycling':
        return 0.0; // Assuming personal bike
      default:
        // Default to driving estimate
        return _grabBaseFare + (_grabPerKm * distanceInKm);
    }
  }

  static String formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }

  static String formatDistance(double distanceInKm) {
    if (distanceInKm < 1.0) {
      return '${(distanceInKm * 1000).round()}m';
    } else {
      return '${distanceInKm.toStringAsFixed(1)}km';
    }
  }

  static String formatCost(double costInPHP) {
    return '₱${costInPHP.toStringAsFixed(0)}';
  }
}
