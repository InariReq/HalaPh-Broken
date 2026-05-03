import 'package:flutter_test/flutter_test.dart';
import 'package:halaph/services/firebase_app_service.dart';
import 'package:halaph/services/simple_plan_service.dart';
import 'package:halaph/services/friend_service.dart';
import 'package:halaph/utils/firebase_modes.dart';

void main() {
  group('Online Firebase Functionality Tests', () {
    testWidgets('Firebase initialization works for online usage', (tester) async {
      // Ensure online mode
      FirebaseModes.offline = false;
      
      // Initialize Firebase
      await FirebaseAppService.initialize();
      expect(FirebaseAppService.isInitialized, isTrue);
      
      print('✅ Firebase online initialization works');
    });
    
    testWidgets('Plan creation works online', (tester) async {
      // Ensure online mode
      FirebaseModes.offline = false;
      await FirebaseAppService.initialize();
      await SimplePlanService.initialize();
      
      // Create plan
      final plan = SimplePlanService.createPlan(
        title: 'Online Test Plan',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 1)),
        destinations: [],
      );
      
      // Verify plan was created
      expect(plan.title, equals('Online Test Plan'));
      expect(plan.participantUids, isNotEmpty);
      
      print('✅ Online plan creation works');
    });
    
    testWidgets('Plan updates work online', (tester) async {
      // Ensure online mode
      FirebaseModes.offline = false;
      await FirebaseAppService.initialize();
      await SimplePlanService.initialize();
      
      // Create plan
      final plan = SimplePlanService.createPlan(
        title: 'Update Test Plan',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 1)),
        destinations: [],
      );
      
      // Update plan
      final updateSuccess = await SimplePlanService.updatePlan(
        planId: plan.id,
        title: 'Updated Online Plan',
      );
      expect(updateSuccess, isTrue);
      
      print('✅ Online plan updates work');
    });
    
    testWidgets('Plan deletion works online', (tester) async {
      // Ensure online mode
      FirebaseModes.offline = false;
      await FirebaseAppService.initialize();
      await SimplePlanService.initialize();
      
      // Create plan
      final plan = SimplePlanService.createPlan(
        title: 'Delete Test Plan',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 1)),
        destinations: [],
      );
      
      // Delete plan
      final deleteSuccess = await SimplePlanService.deletePlan(plan.id);
      expect(deleteSuccess, isTrue);
      expect(SimplePlanService.getPlanById(plan.id), isNull);
      
      print('✅ Online plan deletion works');
    });
    
    testWidgets('Collaboration features work online', (tester) async {
      // Ensure online mode
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
      final addSuccess = await SimplePlanService.addCollaborator(
        plan.id, 
        'test_collaborator_123'
      );
      expect(addSuccess, isTrue);
      
      // Remove collaborator
      final removeSuccess = await SimplePlanService.removeCollaborator(
        plan.id, 
        'test_collaborator_123'
      );
      expect(removeSuccess, isTrue);
      
      print('✅ Online collaboration features work');
    });
    
    testWidgets('Real-time synchronization works online', (tester) async {
      // Ensure online mode
      FirebaseModes.offline = false;
      await FirebaseAppService.initialize();
      await SimplePlanService.initialize();
      
      // Create plan
      final plan = SimplePlanService.createPlan(
        title: 'Real-time Test',
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
        title: 'Updated Real-time Test',
      );
      
      // Wait for change detection
      await Future.delayed(const Duration(seconds: 1));
      
      expect(changeDetected, isTrue);
      
      print('✅ Online real-time synchronization works');
    });
    
    testWidgets('Friend service works online', (tester) async {
      // Ensure online mode
      FirebaseModes.offline = false;
      await FirebaseAppService.initialize();
      
      final friendService = FriendService();
      
      // Test getting user code
      final myCode = await friendService.getMyCode();
      expect(myCode, isNotEmpty);
      
      // Test getting friends list
      final friends = await friendService.getFriends();
      expect(friends, isA<List>());
      
      print('✅ Online friend service works');
    });
    
    testWidgets('Firebase storage operations work', (tester) async {
      // Ensure online mode
      FirebaseModes.offline = false;
      await FirebaseAppService.initialize();
      
      // Verify Firebase is initialized
      expect(FirebaseAppService.isInitialized, isTrue);
      
      // Test plan operations that would use storage
      await SimplePlanService.initialize();
      
      final plan = SimplePlanService.createPlan(
        title: 'Storage Test Plan',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 1)),
        destinations: [],
      );
      
      // Verify plan was created and would be stored in Firebase
      expect(plan.id, isNotEmpty);
      expect(SimplePlanService.getPlanById(plan.id), isNotNull);
      
      print('✅ Firebase storage operations work');
    });
  });
}
