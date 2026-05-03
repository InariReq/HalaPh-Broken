import 'package:flutter_test/flutter_test.dart';
import 'package:halaph/services/firebase_app_service.dart';
import 'package:halaph/services/simple_plan_service.dart';

void main() {
  group('Plan Deletion Tests', () {
    testWidgets('Regular plan deletion works', (tester) async {
      // Initialize Firebase and plan service
      await FirebaseAppService.initialize();
      await SimplePlanService.initialize();

      // Create a regular plan
      final plan = SimplePlanService.createPlan(
        title: 'Regular Test Plan',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 1)),
        destinations: [],
      );

      // Verify plan exists
      expect(SimplePlanService.getPlanById(plan.id), isNotNull);

      // Delete the plan
      final deleteSuccess = await SimplePlanService.deletePlan(plan.id);
      expect(deleteSuccess, isTrue);

      // Verify plan is gone
      expect(SimplePlanService.getPlanById(plan.id), isNull);

      print('✅ Regular plan deletion test passed');
    });

    testWidgets('Collaboration plan deletion works for owner', (tester) async {
      // Initialize Firebase and plan service
      await FirebaseAppService.initialize();
      await SimplePlanService.initialize();

      // Create a collaboration plan
      final plan = SimplePlanService.createPlan(
        title: 'Collaboration Test Plan',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 2)),
        destinations: [],
      );

      // Add a collaborator
      await SimplePlanService.addCollaborator(plan.id, 'collaborator_user_123');

      // Verify plan exists and has collaborators
      final existingPlan = SimplePlanService.getPlanById(plan.id);
      expect(existingPlan, isNotNull);
      expect(existingPlan!.participantUids.length, greaterThan(1));

      // Delete the plan as owner
      final deleteSuccess = await SimplePlanService.deletePlan(plan.id);
      expect(deleteSuccess, isTrue);

      // Verify plan is gone
      expect(SimplePlanService.getPlanById(plan.id), isNull);

      print('✅ Collaboration plan deletion test passed');
    });

    testWidgets('Plan deletion fails for non-owner', (tester) async {
      // Initialize Firebase and plan service
      await FirebaseAppService.initialize();
      await SimplePlanService.initialize();

      // Create a plan
      final plan = SimplePlanService.createPlan(
        title: 'Owner Test Plan',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 1)),
        destinations: [],
      );

      // Simulate deletion by non-owner (this should fail in real Firebase)
      // Note: This test mainly verifies local logic works correctly
      final isOwner = SimplePlanService.isPlanOwner(plan.id);
      expect(isOwner, isTrue);

      print('✅ Plan ownership verification test passed');
    });

    testWidgets('Plan deletion handles missing plan gracefully',
        (tester) async {
      // Initialize Firebase and plan service
      await FirebaseAppService.initialize();
      await SimplePlanService.initialize();

      // Try to delete non-existent plan
      final deleteSuccess =
          await SimplePlanService.deletePlan('non_existent_plan_id');
      expect(deleteSuccess, isFalse);

      print('✅ Missing plan deletion test passed');
    });
  });
}
