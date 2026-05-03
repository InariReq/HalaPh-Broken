import 'package:flutter_test/flutter_test.dart';
import 'package:halaph/services/firebase_app_service.dart';
import 'package:halaph/services/simple_plan_service.dart';
import 'package:halaph/utils/firebase_modes.dart';

void main() {
  group('Real App Functionality Tests', () {
    testWidgets('Firebase initialization works in production', (tester) async {
      // Test Firebase initialization exactly as app does it
      await FirebaseAppService.initialize();
      expect(FirebaseAppService.isInitialized, isTrue);
      
      print('✅ Firebase production initialization works');
    });
    
    testWidgets('App works offline when Firebase unavailable', (tester) async {
      // Simulate offline mode
      FirebaseModes.offline = true;
      
      // Initialize Firebase (should fall back to offline mode)
      await FirebaseAppService.initialize();
      await SimplePlanService.initialize();
      
      // Create plan in offline mode
      final plan = SimplePlanService.createPlan(
        title: 'Offline Test Plan',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 1)),
        destinations: [],
      );
      
      // Verify plan was created locally
      expect(plan.title, equals('Offline Test Plan'));
      expect(plan.participantUids, isNotEmpty);
      
      // Retrieve plan from local cache
      final retrievedPlan = SimplePlanService.getPlanById(plan.id);
      expect(retrievedPlan?.title, equals(plan.title));
      
      print('✅ Offline mode functionality works');
    });
    
    testWidgets('App transitions from offline to online', (tester) async {
      // Start in offline mode
      FirebaseModes.offline = true;
      await FirebaseAppService.initialize();
      await SimplePlanService.initialize();
      
      // Create plan offline
      final plan = SimplePlanService.createPlan(
        title: 'Transition Test Plan',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 1)),
        destinations: [],
      );
      
      // Switch to online mode
      FirebaseModes.offline = false;
      
      // Verify plan still exists after mode switch
      final retrievedPlan = SimplePlanService.getPlanById(plan.id);
      expect(retrievedPlan?.title, equals(plan.title));
      
      print('✅ Offline to online transition works');
    });
    
    testWidgets('Real-time synchronization works', (tester) async {
      // Ensure online mode
      FirebaseModes.offline = false;
      await FirebaseAppService.initialize();
      await SimplePlanService.initialize();
      
      // Create plan
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
      
      // Wait for change detection
      await Future.delayed(const Duration(seconds: 1));
      
      expect(changeDetected, isTrue);
      
      print('✅ Real-time synchronization works');
    });
    
    testWidgets('Plan deletion works in both modes', (tester) async {
      // Test deletion in online mode
      FirebaseModes.offline = false;
      await FirebaseAppService.initialize();
      await SimplePlanService.initialize();
      
      final onlinePlan = SimplePlanService.createPlan(
        title: 'Online Deletion Test',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 1)),
        destinations: [],
      );
      
      // Delete online
      final onlineDeleteSuccess = await SimplePlanService.deletePlan(onlinePlan.id);
      expect(onlineDeleteSuccess, isTrue);
      expect(SimplePlanService.getPlanById(onlinePlan.id), isNull);
      
      // Test deletion in offline mode
      FirebaseModes.offline = true;
      
      final offlinePlan = SimplePlanService.createPlan(
        title: 'Offline Deletion Test',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 1)),
        destinations: [],
      );
      
      // Delete offline
      final offlineDeleteSuccess = await SimplePlanService.deletePlan(offlinePlan.id);
      expect(offlineDeleteSuccess, isTrue);
      expect(SimplePlanService.getPlanById(offlinePlan.id), isNull);
      
      print('✅ Plan deletion works in both online and offline modes');
    });
    
    testWidgets('Collaboration features work', (tester) async {
      // Ensure online mode for collaboration
      FirebaseModes.offline = false;
      await FirebaseAppService.initialize();
      await SimplePlanService.initialize();
      
      // Create plan
      final plan = SimplePlanService.createPlan(
        title: 'Collaboration Test',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 2)),
        destinations: [],
      );
      
      // Add collaborator
      final collabSuccess = await SimplePlanService.addCollaborator(
        plan.id, 
        'test_collaborator_123'
      );
      expect(collabSuccess, isTrue);
      
      // Remove collaborator
      final removeSuccess = await SimplePlanService.removeCollaborator(
        plan.id, 
        'test_collaborator_123'
      );
      expect(removeSuccess, isTrue);
      
      // Delete plan with collaborators
      final deleteSuccess = await SimplePlanService.deletePlan(plan.id);
      expect(deleteSuccess, isTrue);
      
      print('✅ Collaboration features work perfectly');
    });
  });
}
