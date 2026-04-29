import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:halaph/services/budget_routing_service.dart';
import 'package:halaph/services/destination_service.dart';

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
  static Future<List<TravelCostEstimate>> getTravelCostEstimates(
    LatLng destination,
  ) async {
    try {
      // Get current location
      final currentLocation = await DestinationService.getCurrentLocation();

      final routes = await BudgetRoutingService.calculateBudgetRoutes(
        origin: currentLocation,
        destination: destination,
      );

      return routes
          .where((route) => route.mode != TravelMode.driving)
          .map(
            (route) => TravelCostEstimate(
              travelMode: _modeLabel(route.mode),
              duration: route.duration,
              distance: route.distance,
              estimatedCost: route.cost,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('Error getting travel cost estimates: $e');
      return [];
    }
  }

  static String _modeLabel(TravelMode mode) {
    return switch (mode) {
      TravelMode.jeepney => 'jeepney',
      TravelMode.bus => 'bus',
      TravelMode.train => 'train',
      TravelMode.fx => 'uv_fx',
      TravelMode.walking => 'walking',
      TravelMode.driving => 'driving',
    };
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
