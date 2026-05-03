import 'package:flutter_test/flutter_test.dart';
import 'package:halaph/models/plan.dart';
import 'package:halaph/services/simple_plan_service.dart';

void main() {
  group('Firestore Rules Validation', () {
    test('Plan model schema is consistent', () {
      final plan = TravelPlan(
        id: 'test-plan',
        title: 'Test Plan',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 1)),
        participantUids: ['user123'],
        createdBy: 'user123',
        itinerary: [],
        isShared: false,
        bannerImage: null,
      );

      final json = plan.toJson();
      expect(json['participantUids'], isA<List>());
      expect(json['createdBy'], isA<String>());
      expect(json['title'], isA<String>());

      print('✅ Plan model schema validation passed');
    });

    test('Plan creation data structure matches Firestore rules', () {
      final plan = TravelPlan(
        id: 'test-plan',
        title: 'Test Plan',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 1)),
        participantUids: ['owner123'],
        createdBy: 'owner123',
        itinerary: [],
        isShared: false,
        bannerImage: null,
      );

      // Verify data structure matches what Firestore rules expect
      expect(plan.participantUids, contains('owner123'));
      expect(plan.createdBy, equals('owner123'));
      expect(plan.participantUids.length, equals(1));

      print('✅ Plan data structure validation passed');
    });

    test('SimplePlanService createPlan works correctly', () {
      // Test in-memory plan creation (without Firebase)
      SimplePlanService.debugAllowMemoryOnlyPlans = true;

      final plan = SimplePlanService.createPlan(
        title: 'Test Plan',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 1)),
        destinations: [],
      );

      expect(plan.title, equals('Test Plan'));
      expect(plan.participantUids, contains('demo_user'));
      expect(plan.createdBy, equals('demo_user'));
      expect(plan.isShared, isFalse);

      print('✅ SimplePlanService createPlan validation passed');
    });
  });
}
