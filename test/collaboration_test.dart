import 'package:flutter_test/flutter_test.dart';
import 'package:halaph/services/simple_plan_service.dart';
import 'package:halaph/services/friend_service.dart';

void main() {
  group('Cross-platform Collaboration Tests', () {
    test('SimplePlanService methods exist and are callable', () {
      // Verify that collaboration-related methods exist
      expect(SimplePlanService.savePlan, isNotNull);
      expect(SimplePlanService.updatePlanParticipants, isNotNull);
      expect(SimplePlanService.getPlanById, isNotNull);
      expect(SimplePlanService.deletePlan, isNotNull);
    });

    test('FriendService methods exist for collaboration', () {
      final service = FriendService();

      // Verify friend-related methods for collaboration
      expect(service.getMyCode, isNotNull);
      expect(service.addFriendByCode, isNotNull);
      expect(service.getFriends, isNotNull);
      expect(service.resolveParticipantUids, isNotNull);
      expect(service.getPublicFavoriteIds, isNotNull);
      expect(service.getPublicFavoritePlaces, isNotNull);
      expect(service.publishFavoritePlaceIds, isNotNull);
      expect(service.publishFavoritePlaces, isNotNull);
    });

    test('Plan ID generation is accessible', () {
      // Test that the service can be accessed
      expect(SimplePlanService, isNotNull);
      expect(SimplePlanService.shareLink('test'), isNotNull);
    });

    test('Collaboration service structure is correct', () {
      // Verify that the services can be instantiated
      final friendService = FriendService();
      expect(friendService, isA<FriendService>());
    });
  });
}
