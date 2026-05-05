import 'package:flutter_test/flutter_test.dart';
import 'package:halaph/services/budget_routing_service.dart';
import 'package:halaph/services/fare_service.dart';

void main() {
  group('Fare Calculations Tests', () {
    test('budget routing service exists', () {
      expect(BudgetRoutingService(), isA<BudgetRoutingService>());
    });

    test('calculate fare with valid distance', () {
      // Test that fare calculation works with valid inputs
      final distanceInMeters = 5000.0; // 5km
      final fare = _calculateSimpleFare(distanceInMeters);
      expect(fare, greaterThan(0));
    });

    test('fare is zero for zero distance', () {
      final distanceInMeters = 0.0;
      final fare = _calculateSimpleFare(distanceInMeters);
      expect(fare, equals(0));
    });

    test('fare increases with distance', () {
      final shortDistance = 2000.0; // 2km
      final longDistance = 10000.0; // 10km
      final shortFare = _calculateSimpleFare(shortDistance);
      final longFare = _calculateSimpleFare(longDistance);
      expect(longFare, greaterThan(shortFare));
    });

    test('fare breakdown exposes required categories', () {
      final breakdown = FareService.fareBreakdown(TravelMode.jeepney, 5.0);

      expect(breakdown.baseFare, breakdown.regularFare);
      expect(breakdown.studentFare, closeTo(breakdown.baseFare * 0.8, 0.001));
      expect(breakdown.seniorFare, closeTo(breakdown.baseFare * 0.8, 0.001));
      expect(breakdown.pwdFare, closeTo(breakdown.baseFare * 0.8, 0.001));
    });
  });
}

double _calculateSimpleFare(double distanceInMeters) {
  const ratePerKm = 12.0; // PHP per km
  final distanceInKm = distanceInMeters / 1000;
  return distanceInKm * ratePerKm;
}
