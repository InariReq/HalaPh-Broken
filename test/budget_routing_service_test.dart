import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:halaph/services/budget_routing_service.dart';

void main() {
  test(
    'calculateBudgetRoutes includes MRT/LRT option with station access',
    () async {
      const origin = LatLng(14.5349, 121.0506); // McKinley Hill / BGC area.
      const destination = LatLng(14.5907, 120.9747); // Intramuros area.

      final routes = await BudgetRoutingService.calculateBudgetRoutes(
        origin: origin,
        destination: destination,
      );

      expect(
        TravelMode.values.map((mode) => mode.name),
        isNot(contains('driving')),
      );

      final trainRoutes = routes.where(
        (route) => route.mode == TravelMode.train,
      );
      expect(trainRoutes, isNotEmpty);

      final trainRoute = trainRoutes.first;
      expect(trainRoute.routeDetails?.routeName, contains('MRT-3'));
      expect(trainRoute.instructions.join(' '), contains('station'));
      expect(trainRoute.fareDetails.regular, greaterThan(0));
    },
  );
}
