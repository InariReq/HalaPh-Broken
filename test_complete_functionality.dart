import 'package:flutter_test/flutter_test.dart';
import 'package:halaph/services/firebase_app_service.dart';
import 'package:halaph/services/simple_plan_service.dart';
import 'package:halaph/services/friend_service.dart';
import 'package:halaph/models/plan.dart';

void main() {
  group('Complete App Functionality Tests', () {
    testWidgets('Firebase initialization works', (tester) async {
      // Test Firebase initialization
      await FirebaseAppService.initialize();
      expect(FirebaseAppService.isInitialized, isTrue);

      print('✅ Firebase initialization test passed');
    });

    testWidgets('Plan creation works end-to-end', (tester) async {
      // Initialize Firebase and plan service
      await FirebaseAppService.initialize();
      await SimplePlanService.initialize();

      // Create a plan
      final plan = SimplePlanService.createPlan(
        title: 'Complete Test Plan',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 2)),
        destinations: [],
      );

      // Verify plan was created and saved
      expect(plan.title, equals('Complete Test Plan'));
      expect(plan.participantUids, isNotEmpty);
      expect(plan.createdBy, isNotEmpty);

      // Retrieve plan from service to verify persistence
      final retrievedPlan = SimplePlanService.getPlanById(plan.id);
      expect(retrievedPlan?.title, equals(plan.title));

      print('✅ Plan creation end-to-end test passed');
    });

    testWidgets('Plan update and collaboration works', (tester) async {
      // Initialize Firebase and plan service
      await FirebaseAppService.initialize();
      await SimplePlanService.initialize();

      // Create a plan
      final plan = SimplePlanService.createPlan(
        title: 'Collaboration Test Plan',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 2)),
        destinations: [],
      );

      // Update plan
      final updateSuccess = await SimplePlanService.updatePlan(
        planId: plan.id,
        title: 'Updated Collaboration Plan',
      );
      expect(updateSuccess, isTrue);

      // Add collaborator
      final collabSuccess = await SimplePlanService.addCollaborator(
          plan.id, 'collaborator_user_123');
      expect(collabSuccess, isTrue);

      print('✅ Plan update and collaboration test passed');
    });

    testWidgets('Plan deletion works correctly', (tester) async {
      // Initialize Firebase and plan service
      await FirebaseAppService.initialize();
      await SimplePlanService.initialize();

      // Create a plan
      final plan = SimplePlanService.createPlan(
        title: 'Deletion Test Plan',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 1)),
        destinations: [],
      );

      // Delete plan
      final deleteSuccess = await SimplePlanService.deletePlan(plan.id);
      expect(deleteSuccess, isTrue);

      // Verify plan is gone
      final deletedPlan = SimplePlanService.getPlanById(plan.id);
      expect(deletedPlan, isNull);

      print('✅ Plan deletion test passed');
    });

    testWidgets('Friend service functionality works', (tester) async {
      // Initialize Firebase
      await FirebaseAppService.initialize();

      final friendService = FriendService();

      // Test getting user code
      final myCode = await friendService.getMyCode();
      expect(myCode, isNotEmpty);

      // Test getting friends list
      final friends = await friendService.getFriends();
      expect(friends, isA<List>());

      print('✅ Friend service functionality test passed');
    });

    testWidgets('Real-time sync works', (tester) async {
      // Initialize Firebase and plan service
      await FirebaseAppService.initialize();
      await SimplePlanService.initialize();

      // Create a plan
      final plan = SimplePlanService.createPlan(
        title: 'Real-time Sync Test',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 1)),
        destinations: [],
      );

      // Listen for changes
      bool changeDetected = false;
      SimplePlanService.changes.listen((_) {
        changeDetected = true;
      });

      // Update plan to trigger change
      await SimplePlanService.updatePlan(
        planId: plan.id,
        title: 'Updated Real-time Sync Test',
      );

      // Wait for change detection (with timeout)
      await Future.delayed(const Duration(seconds: 2));

      expect(changeDetected, isTrue);

      print('✅ Real-time sync test passed');
    });
  });
}
