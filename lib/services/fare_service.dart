import 'package:halaph/services/budget_routing_service.dart';

// Simple fare estimator with rough rates per mode and distance.
// Note: This is a heuristic estimator to provide UX for pricing incentives
// (eg. Student/PWD discounts). Replace with official fare data for production.
enum PassengerType { adult, student, pwd }

class FareService {
  static double estimateFare(TravelMode mode, double distanceKm,
      {PassengerType type = PassengerType.adult}) {
    if (mode == TravelMode.walking) return 0.0;

    double base;
    switch (mode) {
      case TravelMode.jeepney:
        base = 8.0;
        break;
      case TravelMode.bus:
        base = 12.0;
        break;
      case TravelMode.train:
        base = 14.0;
        break;
      case TravelMode.fx:
        base = 16.0;
        break;
      case TravelMode.walking:
        base = 0.0;
        break;
    }

    // Rough distance-based increment (simplified)
    final distComponent = distanceKm * 6.0; // ~6 PHP per km as a rough guide
    double fare = base + distComponent;

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
