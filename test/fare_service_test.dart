import 'package:flutter_test/flutter_test.dart';
import 'package:halaph/services/fare_service.dart'
    show FareService, PassengerType;
import 'package:halaph/services/budget_routing_service.dart' show TravelMode;

void main() {
  group('FareService', () {
    test('regular fare has no discount', () {
      final fare = FareService.estimateFare(TravelMode.jeepney, 5.0,
          type: PassengerType.regular);
      expect(fare, closeTo(16.0, 0.001));
    });

    test('adult alias maps to regular fare', () {
      final regularFare = FareService.estimateFare(TravelMode.jeepney, 5.0,
          type: PassengerType.regular);
      final adultFare = FareService.estimateFare(TravelMode.jeepney, 5.0,
          type: PassengerType.adult);
      expect(adultFare, closeTo(regularFare, 0.001));
    });

    test('student discount is 20%', () {
      final fare = FareService.estimateFare(TravelMode.jeepney, 5.0,
          type: PassengerType.student);
      expect(fare, closeTo(12.8, 0.001));
    });

    test('senior discount is 20%', () {
      final fare = FareService.estimateFare(TravelMode.jeepney, 5.0,
          type: PassengerType.senior);
      expect(fare, closeTo(12.8, 0.001));
    });

    test('walking fare is zero', () {
      final fare = FareService.estimateFare(TravelMode.walking, 10.0);
      expect(fare, equals(0.0));
    });

    test('pwd discount is 20%', () {
      final fare = FareService.estimateFare(TravelMode.jeepney, 2.0,
          type: PassengerType.pwd);
      expect(fare, closeTo(11.2, 0.001));
    });

    test('fare breakdown includes all passenger categories', () {
      final breakdown = FareService.fareBreakdown(TravelMode.jeepney, 5.0);

      expect(breakdown.baseFare, closeTo(16.0, 0.001));
      expect(breakdown.regularFare, closeTo(16.0, 0.001));
      expect(breakdown.studentFare, closeTo(12.8, 0.001));
      expect(breakdown.seniorFare, closeTo(12.8, 0.001));
      expect(breakdown.pwdFare, closeTo(12.8, 0.001));
    });
  });
}
