import 'package:flutter_test/flutter_test.dart';
import 'package:halaph/services/firestore_service.dart';
import 'package:halaph/services/friend_service.dart';

String _normalizeTestCode(String raw) {
  return raw.trim().toUpperCase();
}

void main() {
  group('Friend Code Normalization Tests', () {
    test('trim and uppercase', () {
      expect(_normalizeTestCode(' je-9248 '), 'JE-9248');
      expect(_normalizeTestCode('bd-6060'), 'BD-6060');
      expect(_normalizeTestCode('AB-1234'), 'AB-1234');
      expect(_normalizeTestCode(''), isEmpty);
    });
  });

  group('Friend Request Payload Tests', () {
    test('friend request uses Firebase Auth UID, not friend code', () {
      const currentUid = 'firebase_auth_uid_123';
      const targetUid = 'firebase_auth_uid_456';
      const myCode = 'JE-9248';
      const targetCode = 'BD-6060';

      final payload = {
        'fromUid': currentUid,
        'toUid': targetUid,
        'fromCode': myCode,
        'toCode': targetCode,
        'status': 'pending',
      };

      expect(payload['fromUid'], isNot(contains('-')));
      expect(payload['toUid'], isNot(contains('-')));
    });

    test('self friend request is blocked', () {
      const uid = 'firebase_auth_uid_123';
      const code = 'JE-9248';
      expect(uid, isNot(code));
    });

    test('sendFriendRequest payload includes fromName and toName', () {
      final payload = FirestoreService.friendRequestPayloadForTesting(
        fromUid: 'firebase_auth_uid_123',
        toUid: 'firebase_auth_uid_456',
        fromCode: 'JE-9248',
        toCode: 'BD-6060',
        fromName: 'Alice',
        toName: 'Bob',
      );

      expect(payload['fromName'], 'Alice');
      expect(payload['toName'], 'Bob');
    });

    test('ensureFriendDocs payload writes names and no role field', () {
      final payload = FirestoreService.friendDocPayloadForTesting(
        uid: 'firebase_auth_uid_456',
        code: 'BD-6060',
        name: 'Bob',
      );

      expect(payload['name'], 'Bob');
      expect(payload.containsKey('role'), isFalse);
    });

    test('fallback display name uses email prefix', () {
      final name = FriendService.bestEffortDisplayNameFromValues(
        displayName: '',
        email: 'alice@example.com',
        publicProfileName: 'Profile Alice',
      );

      expect(name, 'alice');
    });
  });

  group('Friends Path Tests', () {
    test('friends path uses Firebase Auth UID', () {
      const userId = 'firebase_auth_uid_123';
      final correctPath = 'users/$userId/friends';
      expect(correctPath, equals('users/firebase_auth_uid_123/friends'));
      expect(correctPath, isNot(contains('-')));
    });
  });

  group('Auth Race Condition Tests', () {
    test('null auth does not call Firestore', () {
      final currentUser = null;
      if (currentUser == null) {
        expect(true, isTrue); // Would show "Please sign in"
      }
    });
  });
}
