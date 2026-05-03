import 'package:flutter_test/flutter_test.dart';
import 'package:halaph/services/firebase_app_service.dart';
import 'package:halaph/services/simple_plan_service.dart';
import 'package:halaph/utils/firebase_modes.dart';

void main() {
  group('Collaboration Plan Visibility Tests', () {
    testWidgets('Collaboration plans appear on both users apps',
        (tester) async {
      // Ensure online mode
      FirebaseModes.offline = false;
      await FirebaseAppService.initialize();
      await SimplePlanService.initialize();

      // Create a plan as user A
      final plan = SimplePlanService.createPlan(
        title: 'Shared Collaboration Plan',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 2)),
        destinations: [],
      );

      // Add collaborator (user B)
      final collaboratorId = 'user_b_123';
      final addSuccess =
          await SimplePlanService.addCollaborator(plan.id, collaboratorId);
      expect(addSuccess, isTrue);

      // Verify plan has collaborators
      final updatedPlan = SimplePlanService.getPlanById(plan.id);
      expect(updatedPlan?.participantUids, contains(collaboratorId));

      // Test that plan would be visible to collaborator
      final sharedPlans =
          SimplePlanService.getPlansSharedWithUser(collaboratorId);
      expect(sharedPlans, isNotEmpty);

      print('✅ Collaboration plans appear on both users apps');
    });

    testWidgets('Real-time sync works for shared plans', (tester) async {
      // Ensure online mode
      FirebaseModes.offline = false;
      await FirebaseAppService.initialize();
      await SimplePlanService.initialize();

      // Create plan
      final plan = SimplePlanService.createPlan(
        title: 'Real-time Collaboration Test',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 1)),
        destinations: [],
      );

      // Listen for changes
      bool changeDetected = false;
      SimplePlanService.changes.listen((_) {
        changeDetected = true;
      });

      // Add collaborator to trigger real-time update
      await SimplePlanService.addCollaborator(plan.id, 'realtime_user_456');

      // Wait for real-time sync
      await Future.delayed(const Duration(seconds: 1));

      expect(changeDetected, isTrue);

      // Verify collaborator was added
      final updatedPlan = SimplePlanService.getPlanById(plan.id);
      expect(updatedPlan?.participantUids, contains('realtime_user_456'));

      print('✅ Real-time sync works for shared plans');
    });

    testWidgets('Plan sharing between different users works', (tester) async {
      // Ensure online mode
      FirebaseModes.offline = false;
      await FirebaseAppService.initialize();
      await SimplePlanService.initialize();

      // Create plan as owner
      final plan = SimplePlanService.createPlan(
        title: 'Multi-user Shared Plan',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 3)),
        destinations: [],
      );

      // Add multiple collaborators
      final collaborators = ['user_1', 'user_2', 'user_3'];
      for (final collaborator in collaborators) {
        final success =
            await SimplePlanService.addCollaborator(plan.id, collaborator);
        expect(success, isTrue);
      }

      // Verify all collaborators are added
      final finalPlan = SimplePlanService.getPlanById(plan.id);
      for (final collaborator in collaborators) {
        expect(finalPlan?.participantUids, contains(collaborator));
      }

      // Test visibility for each collaborator
      for (final collaborator in collaborators) {
        final sharedPlans =
            SimplePlanService.getPlansSharedWithUser(collaborator);
        expect(sharedPlans, isNotEmpty);
        expect(sharedPlans.any((p) => p.id == plan.id), isTrue);
      }

      print('✅ Plan sharing between different users works');
    });

    testWidgets('Added friends can see collaboration plans', (tester) async {
      // Ensure online mode
      FirebaseModes.offline = false;
      await FirebaseAppService.initialize();
      await SimplePlanService.initialize();

      // Create plan
      final plan = SimplePlanService.createPlan(
        title: 'Friend Collaboration Plan',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 2)),
        destinations: [],
      );

      // Add friend as collaborator
      final friendId = 'friend_user_789';
      await SimplePlanService.addCollaborator(plan.id, friendId);

      // Verify friend can see the plan
      final friendSharedPlans =
          SimplePlanService.getPlansSharedWithUser(friendId);
      expect(friendSharedPlans, isNotEmpty);
      expect(friendSharedPlans.any((p) => p.id == plan.id), isTrue);

      // Verify owner can still see their plan
      final ownerPlans = SimplePlanService.getAllPlans();
      expect(ownerPlans, isNotEmpty);
      expect(ownerPlans.any((p) => p.id == plan.id), isTrue);

      print('✅ Added friends can see collaboration plans');
    });

    testWidgets('Plan visibility persists after updates', (tester) async {
      // Ensure online mode
      FirebaseModes.offline = false;
      await FirebaseAppService.initialize();
      await SimplePlanService.initialize();

      // Create plan
      final plan = SimplePlanService.createPlan(
        title: 'Persistent Visibility Plan',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 1)),
        destinations: [],
      );

      // Add collaborator
      final collaboratorId = 'persistent_user_999';
      await SimplePlanService.addCollaborator(plan.id, collaboratorId);

      // Update plan details
      final updateSuccess = await SimplePlanService.updatePlan(
        planId: plan.id,
        title: 'Updated Persistent Visibility Plan',
      );
      expect(updateSuccess, isTrue);

      // Verify collaborator can still see the updated plan
      final collaboratorPlans =
          SimplePlanService.getPlansSharedWithUser(collaboratorId);
      expect(collaboratorPlans, isNotEmpty);
      expect(collaboratorPlans.any((p) => p.id == plan.id), isTrue);

      // Verify plan title was updated
      final updatedPlan = SimplePlanService.getPlanById(plan.id);
      expect(updatedPlan?.title, equals('Updated Persistent Visibility Plan'));

      print('✅ Plan visibility persists after updates');
    });

    testWidgets('Real-time listeners work correctly', (tester) async {
      // Ensure online mode
      FirebaseModes.offline = false;
      await FirebaseAppService.initialize();
      await SimplePlanService.initialize();

      // Create plan
      final plan = SimplePlanService.createPlan(
        title: 'Real-time Listener Test',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 1)),
        destinations: [],
      );

      // Count initial changes
      int changeCount = 0;
      SimplePlanService.changes.listen((_) {
        changeCount++;
      });

      // Add collaborator
      await SimplePlanService.addCollaborator(plan.id, 'listener_user_111');

      // Wait for changes to propagate
      await Future.delayed(const Duration(seconds: 2));

      // Update plan
      await SimplePlanService.updatePlan(
        planId: plan.id,
        title: 'Updated Real-time Listener Test',
      );

      // Wait for changes to propagate
      await Future.delayed(const Duration(seconds: 2));

      // Verify changes were detected
      expect(changeCount, greaterThan(0));

      print('✅ Real-time listeners work correctly');
    });
  });
}
