import 'package:halaph/services/budget_routing_service.dart';
import 'package:halaph/services/osm_service.dart';

class ApiService {
  static Future<List<dynamic>> getTransportOptions(
    String from,
    String to,
  ) async {
    final origin = await OSMService.geocodeAddress(from);
    final destination = await OSMService.geocodeAddress(to);
    if (origin == null || destination == null) return [];

    final routes = await BudgetRoutingService.calculateBudgetRoutes(
      origin: origin,
      destination: destination,
    );
    return routes
        .map(
          (route) => {
            'type': route.mode.name,
            'duration': '${route.duration.inMinutes} min',
            'distanceKm': route.distance,
            'cost': route.cost,
            'fareRegular': route.fareDetails.regular,
            'fareStudent': route.fareDetails.student,
            'farePwd': route.fareDetails.pwd,
            'fareSenior': route.fareDetails.senior,
            'description': route.summary,
            'route': route.routeDetails?.routeName,
            'instructions': route.instructions,
          },
        )
        .toList();
  }
}
