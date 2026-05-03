import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halaph/services/simple_plan_service.dart';
import 'package:halaph/services/firebase_app_service.dart';

void main() {
  group('Firestore Permission Tests', () {
    test('Plan creation should work with proper authentication', () async {
      // Initialize Firebase and plan service
      await FirebaseAppService.initialize();
      await SimplePlanService.initialize();

      // Create a test plan
      final plan = SimplePlanService.createPlan(
        title: 'Test Plan',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 1)),
        destinations: [],
      );

      // Verify plan was created
      expect(plan.title, 'Test Plan');
      expect(plan.participantUids, isNotEmpty);
      expect(plan.createdBy, isNotEmpty);

      debugPrint('✅ Plan creation test passed');
    });

    test('Plan update should work for owner', () async {
      await SimplePlanService.initialize();

      final plan = SimplePlanService.createPlan(
        title: 'Update Test',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 1)),
        destinations: [],
      );

      // Update plan
      final success = await SimplePlanService.updatePlan(
        planId: plan.id,
        title: 'Updated Plan',
      );

      expect(success, isTrue);
      debugPrint('✅ Plan update test passed');
    });

    test('Plan deletion should work for owner', () async {
      await SimplePlanService.initialize();

      final plan = SimplePlanService.createPlan(
        title: 'Delete Test',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 1)),
        destinations: [],
      );

      // Delete plan
      final success = await SimplePlanService.deletePlan(plan.id);
      expect(success, isTrue);
      debugPrint('✅ Plan deletion permission test passed');
    });

    test('Collaborator addition should work', () async {
      await SimplePlanService.initialize();

      final plan = SimplePlanService.createPlan(
        title: 'Collaboration Test',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 1)),
        destinations: [],
      );

      // Add collaborator
      final success =
          await SimplePlanService.addCollaborator(plan.id, 'test_user_123');
      expect(success, isTrue);
      debugPrint('✅ Collaborator addition test passed');
    });
  });
}
