import 'package:flutter_test/flutter_test.dart';
import 'package:halaph/services/fare_service.dart' show FareService, PassengerType;
import 'package:halaph/services/budget_routing_service.dart' show TravelMode;

void main() {
  group('FareService', () {
    test('jeepney adult fare for 5km', () {
      final fare = FareService.estimateFare(TravelMode.jeepney, 5.0, type: PassengerType.adult);
      expect(fare, closeTo(38.0, 0.001));
    });

    test('jeepney student discount for 5km', () {
      final fare = FareService.estimateFare(TravelMode.jeepney, 5.0, type: PassengerType.student);
      expect(fare, closeTo(30.4, 0.001));
    });

    test('walking fare is zero', () {
      final fare = FareService.estimateFare(TravelMode.walking, 10.0);
      expect(fare, equals(0.0));
    });

    test('pwd discount for jeepney distance 2km', () {
      final fare = FareService.estimateFare(TravelMode.jeepney, 2.0, type: PassengerType.pwd);
      expect(fare, closeTo(18.0, 0.001));
    });
  });
}
