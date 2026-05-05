import 'package:halaph/services/budget_routing_service.dart';

// Simple fare estimator with rail-shipper-like integration.
// This delegates to BudgetRoutingService for base fare calculation and
// applies passenger-type discounts for UX. In production, substitute
// with official fare data sources.
enum PassengerType { regular, adult, student, senior, pwd }

class FareBreakdown {
  final double baseFare;
  final double regularFare;
  final double studentFare;
  final double seniorFare;
  final double pwdFare;

  const FareBreakdown({
    required this.baseFare,
    required this.regularFare,
    required this.studentFare,
    required this.seniorFare,
    required this.pwdFare,
  });
}

class FareService {
  static double estimateFare(TravelMode mode, double distanceKm,
      {PassengerType type = PassengerType.regular}) {
    if (mode == TravelMode.walking) return 0.0;

    // Base fare from budget routing provider (already distance-aware)
    final baseFare = BudgetRoutingService.calculateFare(mode, distanceKm);
    final fare = _applyDiscount(baseFare, type);

    // Ensure non-negative
    return fare < 0 ? 0 : fare;
  }

  static FareBreakdown fareBreakdown(TravelMode mode, double distanceKm) {
    final baseFare = mode == TravelMode.walking
        ? 0.0
        : BudgetRoutingService.calculateFare(mode, distanceKm);
    return FareBreakdown(
      baseFare: baseFare,
      regularFare: _applyDiscount(baseFare, PassengerType.regular),
      studentFare: _applyDiscount(baseFare, PassengerType.student),
      seniorFare: _applyDiscount(baseFare, PassengerType.senior),
      pwdFare: _applyDiscount(baseFare, PassengerType.pwd),
    );
  }

  static double _applyDiscount(double baseFare, PassengerType type) {
    switch (type) {
      case PassengerType.student:
      case PassengerType.senior:
      case PassengerType.pwd:
        return baseFare * 0.8;
      case PassengerType.regular:
      case PassengerType.adult:
        return baseFare;
    }
  }
}
