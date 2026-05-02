import 'package:halaph/services/budget_routing_service.dart';

// Simple fare estimator with rail-shipper-like integration.
// This delegates to BudgetRoutingService for base fare calculation and
// applies simple passenger-type discounts for UX. In production, substitute
// with official fare data sources.
enum PassengerType { adult, student, pwd }

class FareService {
  static double estimateFare(TravelMode mode, double distanceKm,
      {PassengerType type = PassengerType.adult}) {
    if (mode == TravelMode.walking) return 0.0;

    // Base fare from budget routing provider (already distance-aware)
    final baseFare = BudgetRoutingService.calculateFare(mode, distanceKm);
    var fare = baseFare;

    // Apply simple discounts
    switch (type) {
      case PassengerType.student:
        fare *= 0.8; // 20% discount
        break;
      case PassengerType.pwd:
        fare *= 0.9; // 10% discount
        break;
      default:
        break;
    }

    // Ensure non-negative
    if (fare < 0) fare = 0;
    return fare;
  }
}
