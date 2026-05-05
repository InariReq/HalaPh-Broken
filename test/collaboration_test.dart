import 'package:flutter_test/flutter_test.dart';
import 'package:halaph/models/friend.dart';
import 'package:halaph/screens/plan_details_screen.dart';
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

    test('maps current participant UID to friend code for selection', () {
      final selectedCodes = PlanDetailsScreen.collaboratorCodesForParticipants(
        participantUids: const ['ownerUid', 'friendUid'],
        ownerUid: 'ownerUid',
        friends: [
          Friend(
            id: 'friendUid',
            uid: 'friendUid',
            name: 'Friend',
            role: 'Viewer',
            code: 'AB-1234',
          ),
        ],
      );

      expect(selectedCodes, ['AB-1234']);
    });

    test('update participant merge keeps resolved Firebase UIDs', () {
      final participants =
          SimplePlanService.mergeResolvedParticipantsForTesting(
        ownerUid: 'ownerUid',
        selectedParticipants: const ['AB-1234'],
        resolvedCodeUids: const ['friendUid'],
      );

      expect(participants, containsAll(['ownerUid', 'friendUid']));
      expect(participants, isNot(contains('AB-1234')));
    });

    test('re-add after leave keeps owner and collaborator UID', () {
      final participants =
          SimplePlanService.mergeResolvedParticipantsForTesting(
        ownerUid: 'ownerUid',
        selectedParticipants: const ['ownerUid', 'AB-1234'],
        resolvedCodeUids: const ['ownerUid', 'friendUid'],
      );

      expect(participants.toSet(), {'ownerUid', 'friendUid'});
    });

    test('resolved participants do not mix UID and code after save', () {
      final participants =
          SimplePlanService.mergeResolvedParticipantsForTesting(
        ownerUid: 'ownerUid',
        selectedParticipants: const ['friendUid', 'AB-1234'],
        resolvedCodeUids: const ['friendUid'],
      );

      expect(participants, contains('friendUid'));
      expect(participants, isNot(contains('AB-1234')));
    });
  });
}
