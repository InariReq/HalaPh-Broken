import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/models/friend.dart';
import 'package:halaph/services/firebase_app_service.dart';
import 'package:halaph/services/remote_sync_service.dart';

class FriendAddResult {
  final bool success;
  final String message;
  final Friend? friend;

  const FriendAddResult({
    required this.success,
    required this.message,
    this.friend,
  });
}

class FriendService {
  static final FriendService _instance = FriendService._internal();
  factory FriendService() => _instance;
  FriendService._internal();

  String? _cachedUserId;
  String? _cachedCode;
  List<Friend>? _cachedFriends;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _friendsSubscription;
  final _friendsController = StreamController<List<Friend>>.broadcast();

  Stream<List<Friend>> get friendsStream => _friendsController.stream;

  Future<String> getMyCode() async {
    final userId = await _currentUserId();
    if (userId == null) return 'HP-0000';

    if (_cachedUserId == userId && _cachedCode != null) {
      return _cachedCode!;
    }

    final remoteProfile = await RemoteSyncService.instance.loadNamespace(
      'profile',
    );
    final remoteCode = remoteProfile?['code'] as String?;
    if (remoteCode != null && remoteCode.isNotEmpty) {
      final normalizedCode = _normalizeCode(remoteCode);
      _cachedUserId = userId;
      _cachedCode = normalizedCode;
      await _publishPublicProfile(normalizedCode);
      return normalizedCode;
    }

    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    final seed = firebaseUser?.email ?? firebaseUser?.displayName ?? 'traveler';
    final generated = _generateCode(seed, firebaseUser?.uid);
    _cachedUserId = userId;
    _cachedCode = generated;
    await RemoteSyncService.instance.saveNamespace('profile', {
      'code': generated,
    });
    await _publishPublicProfile(generated);
    return generated;
  }

  Future<List<Friend>> getFriends() async {
    final userId = await _currentUserId();
    if (userId == null) return const <Friend>[];

    if (_cachedUserId == userId && _cachedFriends != null) {
      return List<Friend>.from(_cachedFriends!);
    }

    final friends = await _loadRemoteFriends();
    friends.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    _cachedUserId = userId;
    _cachedFriends = List<Friend>.from(friends);
    _startFriendsListener(userId);
    return List<Friend>.from(_cachedFriends!);
  }

  void _startFriendsListener(String userId) {
    _friendsSubscription?.cancel();
    _friendsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('friends')
        .snapshots()
        .listen(
          (snapshot) {
            final friends = snapshot.docs.map((doc) {
              final data = doc.data();
              return Friend(
                id: data['friendId'] as String? ?? doc.id,
                uid: data['friendUid'] as String?,
                name: data['name'] as String? ?? 'Unknown',
                role: data['role'] as String? ?? 'Viewer',
                code: data['code'] as String? ?? '',
                email: data['email'] as String?,
                avatarUrl: data['avatarUrl'] as String?,
              );
            }).toList();
            friends.sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
            _cachedFriends = List<Friend>.from(friends);
            _friendsController.add(friends);
          },
          onError: (error) => debugPrint('Friends live updates failed: $error'),
        );
  }

  

  Future<void> removeFriend(String friendId) async {
    final currentUid = await _currentUserId();
    if (currentUid == null) return;

    final friends = await getFriends();
    final removedFriend = friends.where((friend) => friend.id == friendId).firstOrNull;
    
    // Remove from my friends list
    friends.removeWhere((friend) => friend.id == friendId);
    await _saveFriends(friends);

    // Bidirectional removal - remove myself from their friends list too
    final friendUid = removedFriend?.uid ?? friendId;
    if (friendUid.isNotEmpty) {
      try {
        debugPrint('Removing self from $friendUid\'s friends list');
        await FirebaseFirestore.instance
            .collection('users')
            .doc(friendUid)
            .collection('friends')
            .doc(currentUid)
            .delete()
            .timeout(const Duration(seconds: 5));
        debugPrint('Successfully removed self from friend\'s list');
      } catch (e) {
        debugPrint('Failed to remove self from friend\'s list: $e');
      }

      // Also remove any pending friend requests between the two users
      try {
        debugPrint('Checking for pending friend requests to clean up');
        // Remove any request I sent to them
        await FirebaseFirestore.instance
            .collection('users')
            .doc(friendUid)
            .collection('friend_requests')
            .doc(currentUid)
            .delete()
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        // Ignore if no request exists
      }

      try {
        // Remove any request they sent to me
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .collection('friend_requests')
            .doc(friendUid)
            .delete()
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        // Ignore if no request exists
      }
    }
  }

  Future<List<String>> getPublicFavoriteIds(Friend friend) async {
    final code = _normalizeCode(friend.code);
    if (code.isEmpty || !await FirebaseAppService.initialize()) {
      return const <String>[];
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('publicProfiles')
          .doc(code)
          .get()
          .timeout(const Duration(seconds: 5));
      final data = snapshot.data();
      final rawFavorites = data?['favoritePlaceIds'];
      if (rawFavorites is! List) return const <String>[];
      return rawFavorites
          .whereType<String>()
          .where((id) => id.trim().isNotEmpty)
          .toSet()
          .toList();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<List<Destination>> getPublicFavoritePlaces(Friend friend) async {
    final code = _normalizeCode(friend.code);
    if (code.isEmpty || !await FirebaseAppService.initialize()) {
      return const <Destination>[];
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('publicProfiles')
          .doc(code)
          .get()
          .timeout(const Duration(seconds: 5));
      final data = snapshot.data();
      final rawPlaces = data?['favoritePlaces'];
      if (rawPlaces is! List) return const <Destination>[];
      final places = <Destination>[];
      for (final rawPlace in rawPlaces) {
        if (rawPlace is! Map) continue;
        try {
          places.add(Destination.fromJson(Map<String, dynamic>.from(rawPlace)));
        } catch (_) {}
      }
      return places;
    } catch (_) {
      return const <Destination>[];
    }
  }

  Future<void> publishFavoritePlaceIds(List<String> ids) async {
    if (!await FirebaseAppService.initialize()) return;
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;

    final code = _normalizeCode(await getMyCode());
    if (code.isEmpty) return;

    final deduped = ids
        .where((id) => id.trim().isNotEmpty)
        .map((id) => id.trim())
        .toSet()
        .toList();

    try {
      await FirebaseFirestore.instance
          .collection('publicProfiles')
          .doc(code)
          .set({
            'uid': firebaseUser.uid,
            'code': code,
            'favoritePlaceIds': deduped,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  Future<void> publishFavoritePlaces(List<Destination> destinations) async {
    if (!await FirebaseAppService.initialize()) return;
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;

    final code = _normalizeCode(await getMyCode());
    if (code.isEmpty) return;

    final deduped = <String, Destination>{
      for (final destination in destinations) destination.id: destination,
    };

    try {
      await FirebaseFirestore.instance
          .collection('publicProfiles')
          .doc(code)
          .set({
            'uid': firebaseUser.uid,
            'code': code,
            'favoritePlaceIds': deduped.keys.toList(),
            'favoritePlaces': deduped.values
                .map((destination) => destination.toJson())
                .toList(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  Future<void> updateFriendRole(String friendId, String role) async {
    final friends = await getFriends();
    final updated = friends.map((friend) {
      if (friend.id != friendId) return friend;
      return Friend(
        id: friend.id,
        uid: friend.uid,
        name: friend.name,
        role: role,
        code: friend.code,
        email: friend.email,
        avatarUrl: friend.avatarUrl,
      );
    }).toList();
    await _saveFriends(updated);
  }

  Future<List<Friend>> _loadRemoteFriends() async {
    final userId = await _currentUserId();
    if (userId == null) return [];

    List<Friend> friends = [];
    if (await FirebaseAppService.initialize()) {
      friends = await _loadFriendsFromFirestore(userId);
    }

    if (friends.isEmpty) {
      final payload = await RemoteSyncService.instance.loadNamespace('friends');
      final rawFriends = payload?['friends'];
      if (rawFriends is! List) return [];
      friends = rawFriends
          .whereType<Map>()
          .map((entry) => Friend.fromJson(Map<String, dynamic>.from(entry)))
          .toList();
    }

    return friends;
  }

  Future<void> _saveFriends(List<Friend> friends) async {
    final userId = await _currentUserId();
    if (userId == null) return;

    _cachedUserId = userId;
    _cachedFriends = List<Friend>.from(friends);
    await RemoteSyncService.instance.saveNamespace('friends', {
      'friends': friends.map((friend) => friend.toJson()).toList(),
    });
    await _saveFriendsToFirestore(userId, friends);
  }

  Future<void> _saveFriendsToFirestore(String userId, List<Friend> friends) async {
    if (!await FirebaseAppService.initialize()) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      final collection = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('friends');

      final existingDocs = await collection
          .get()
          .timeout(const Duration(seconds: 5));

      for (final doc in existingDocs.docs) {
        batch.delete(doc.reference);
      }

      for (final friend in friends) {
        final docRef = collection.doc(friend.uid ?? friend.id);
        batch.set(docRef, {
          'ownerUid': userId,
          'friendUid': friend.uid ?? friend.id,
          'friendId': friend.id,
          'name': friend.name,
          'code': friend.code,
          'role': friend.role,
          'email': friend.email,
          'avatarUrl': friend.avatarUrl,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit().timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Failed to save friends to Firestore: $e');
    }
  }

  Future<List<Friend>> _loadFriendsFromFirestore(String userId) async {
    if (!await FirebaseAppService.initialize()) return [];

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('friends')
          .get()
          .timeout(const Duration(seconds: 5));

      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            return Friend(
              id: data['friendId'] as String? ?? doc.id,
              uid: data['friendUid'] as String?,
              name: data['name'] as String? ?? 'Unknown',
              role: data['role'] as String? ?? 'Viewer',
              code: data['code'] as String? ?? '',
              email: data['email'] as String?,
              avatarUrl: data['avatarUrl'] as String?,
            );
          })
          .toList();
    } catch (e) {
      debugPrint('Failed to load friends from Firestore: $e');
      return [];
    }
  }

  Future<Friend?> findPublicProfileByCode(String rawCode) async {
    final code = _normalizeCode(rawCode);
    if (code.isEmpty) return null;
    if (!await FirebaseAppService.initialize()) return null;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('publicProfiles')
          .doc(code)
          .get()
          .timeout(const Duration(seconds: 5));
      if (!snapshot.exists) return null;
      final data = snapshot.data() ?? const <String, dynamic>{};
      final uid = data['uid'] as String?;
      if (uid == null || uid.isEmpty) return null;
      return Friend(
        id: uid,
        uid: uid,
        name: (data['name'] as String?)?.trim().isNotEmpty == true
            ? data['name'] as String
            : 'Friend $code',
        role: 'Viewer',
        code: code,
        email: data['email'] as String?,
        avatarUrl: data['avatarUrl'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> ensurePublicProfilePublished() async {
    final code = await getMyCode();
    if (code.isEmpty) return;
    await _publishPublicProfile(code);
  }

  Future<List<String>> resolveParticipantUids(Iterable<String> codes) async {
    final currentUid = await _currentUserId();
    if (currentUid == null) return const <String>[];

    final uids = <String>{currentUid};
    final normalizedCodes = codes.map(_normalizeCode).where((code) {
      return code.isNotEmpty;
    }).toSet();
    if (normalizedCodes.isEmpty) return uids.toList();

    final myCode = _normalizeCode(await getMyCode());
    final friends = await getFriends();
    final byCode = {
      for (final friend in friends) _normalizeCode(friend.code): friend,
    };

    for (final code in normalizedCodes) {
      if (code == myCode) {
        uids.add(currentUid);
        continue;
      }

      final cachedFriend = byCode[code];
      if (cachedFriend?.uid?.isNotEmpty == true) {
        uids.add(cachedFriend!.uid!);
        continue;
      }

      final profile = await findPublicProfileByCode(code);
      if (profile?.uid?.isNotEmpty == true) {
        uids.add(profile!.uid!);
      }
    }
    return uids.toList();
  }

  Future<List<Map<String, dynamic>>> searchUsersByName(String query) async {
    if (query.trim().isEmpty) return const [];
    final currentUid = await _currentUserId();
    if (currentUid == null) return const [];

    try {
      // Search by exact code match instead of listing all profiles
      final code = _normalizeCode(query);
      if (code.isNotEmpty) {
        final profile = await findPublicProfileByCode(code);
        if (profile != null && profile.uid != currentUid) {
          return [
            {
              'uid': profile.uid ?? '',
              'name': profile.name,
              'email': profile.email ?? '',
              'code': profile.code,
              'avatarUrl': profile.avatarUrl ?? '',
            }
          ];
        }
      }

      // Search by name/email using friends list and known profiles
      final results = <Map<String, dynamic>>[];
      final lowerQuery = query.toLowerCase();

      // Check friends first
      final friends = await getFriends();
      for (final friend in friends) {
        if (friend.uid == currentUid) continue;
        final name = friend.name.toLowerCase();
        final email = (friend.email ?? '').toLowerCase();
        final code = friend.code.toLowerCase();

        if (name.contains(lowerQuery) ||
            email.contains(lowerQuery) ||
            code.contains(lowerQuery)) {
          results.add({
            'uid': friend.uid ?? '',
            'name': friend.name,
            'email': friend.email ?? '',
            'code': friend.code,
            'avatarUrl': friend.avatarUrl ?? '',
          });
        }
      }

      return results;
    } catch (e) {
      debugPrint('Failed to search users: $e');
      return const [];
    }
  }

  Future<bool> isAlreadyFriends(String userUid) async {
    if (userUid.isEmpty) return false;
    final friends = await getFriends();
    return friends.any((f) => f.uid == userUid);
  }

  Future<Map<String, dynamic>> getFriendActivitySummary() async {
    final friends = await getFriends();
    final summary = <String, dynamic>{
      'totalFriends': friends.length,
      'recentlyAdded': <Friend>[],
    };

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(await _currentUserId())
          .collection('friends')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get()
          .timeout(const Duration(seconds: 5));

      final recent = snapshot.docs.map((doc) {
        final data = doc.data();
        return Friend(
          id: data['friendId'] as String? ?? doc.id,
          uid: data['friendUid'] as String?,
          name: data['name'] as String? ?? 'Unknown',
          role: data['role'] as String? ?? 'Viewer',
          code: data['code'] as String? ?? '',
          email: data['email'] as String?,
          avatarUrl: data['avatarUrl'] as String?,
        );
      }).toList();

      summary['recentlyAdded'] = recent;
    } catch (e) {
      debugPrint('Failed to get friend activity: $e');
    }

    return summary;
  }

  void clearCache() {
    _cachedUserId = null;
    _cachedCode = null;
    _cachedFriends = null;
    _friendsSubscription?.cancel();
    _friendsSubscription = null;
  }

  Future<String?> _currentUserId() async {
    if (!await FirebaseAppService.initialize()) return null;
    final userId = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (_cachedUserId != null && _cachedUserId != userId) {
      clearCache();
    }
    return userId;
  }

  Future<void> _publishPublicProfile(String rawCode) async {
    final code = _normalizeCode(rawCode);
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (code.isEmpty || firebaseUser == null) return;

    try {
      final data = {
        'uid': firebaseUser.uid,
        'code': code,
        'name':
            firebaseUser.displayName ??
                firebaseUser.email?.split('@').first ??
                'Traveler',
        'email': firebaseUser.email,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (firebaseUser.photoURL?.isNotEmpty == true) {
        data['avatarUrl'] = firebaseUser.photoURL!;
      }

      await FirebaseFirestore.instance
          .collection('publicProfiles')
          .doc(code)
          .set(data, SetOptions(merge: true))
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  Future<FriendAddResult> addFriendByCode(String rawCode) async {
    final code = _normalizeCode(rawCode);
    if (code.isEmpty) {
      return const FriendAddResult(
        success: false,
        message: 'Please enter a valid friend code.',
      );
    }

    final myCode = await getMyCode();
    if (code == myCode) {
      return const FriendAddResult(
        success: false,
        message: 'You cannot add your own code.',
      );
    }

    final friends = await getFriends();
    final exists = friends.any((friend) => _normalizeCode(friend.code) == code);
    if (exists) {
      return const FriendAddResult(
        success: false,
        message: 'This friend is already added.',
      );
    }

    try {
      await _publishPublicProfile(myCode);

      final profile = await findPublicProfileByCode(code);
      if (profile == null) {
        return const FriendAddResult(
          success: false,
          message: 'Friend code not found. Ask them to open the app first so their code is registered.',
        );
      }

      final currentUid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null) {
        return const FriendAddResult(
          success: false,
          message: 'You must be signed in to add friends.',
        );
      }

      if (profile.uid == null) {
        return const FriendAddResult(
          success: false,
          message: 'Could not find user information for this code.',
        );
      }

      final myProfile = await findPublicProfileByCode(myCode);

      debugPrint('Sending friend request: from $currentUid to ${profile.uid}');

      // Send friend request to the target user's friend_requests collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(profile.uid)
          .collection('friend_requests')
          .doc(currentUid)
          .set({
            'fromUid': currentUid,
            'toUid': profile.uid,
            'fromName': myProfile?.name ?? '',
            'fromCode': myCode,
            'fromEmail': myProfile?.email ?? '',
            'fromAvatarUrl': myProfile?.avatarUrl ?? '',
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 8));

      debugPrint('Friend request sent successfully');

      return FriendAddResult(
        success: true,
        message: 'Friend request sent to ${profile.name}!',
      );
    } catch (e) {
      debugPrint('Failed to send friend request: $e');
      return FriendAddResult(
        success: false,
        message: 'Failed to send friend request: ${e.toString().split(':').first}',
      );
    }
  }

  Future<List<Map<String, dynamic>>> getPendingFriendRequests() async {
    final currentUid = await _currentUserId();
    if (currentUid == null) {
      debugPrint('getPendingFriendRequests: No current user');
      return const [];
    }

    debugPrint('getPendingFriendRequests: Checking for user $currentUid');

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('friend_requests')
          .get()
          .timeout(const Duration(seconds: 5));

      debugPrint('getPendingFriendRequests: Found ${snapshot.docs.length} total requests');

      final requests = snapshot.docs
          .where((doc) {
            final data = doc.data();
            final status = data['status'] as String? ?? '';
            debugPrint('Request ${doc.id}: status=$status');
            return status == 'pending';
          })
          .map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'fromUid': data['fromUid'] as String? ?? '',
              'fromName': data['fromName'] as String? ?? 'Unknown',
              'fromCode': data['fromCode'] as String? ?? '',
              'fromEmail': data['fromEmail'] as String? ?? '',
              'fromAvatarUrl': data['fromAvatarUrl'] as String? ?? '',
              'status': data['status'] as String? ?? 'pending',
              'createdAt': data['createdAt'],
            };
          })
          .toList();

      debugPrint('getPendingFriendRequests: Returning ${requests.length} pending requests');
      return requests;
    } catch (e) {
      debugPrint('Failed to load friend requests: $e');
      return const [];
    }
  }

  Future<FriendAddResult> acceptFriendRequest(Map<String, dynamic> request) async {
    final currentUid = await _currentUserId();
    if (currentUid == null) {
      return const FriendAddResult(
        success: false,
        message: 'You must be signed in to accept friend requests.',
      );
    }

    final fromUid = request['fromUid'] as String?;
    final fromName = request['fromName'] as String? ?? 'Unknown';
    final fromCode = request['fromCode'] as String? ?? '';
    final fromEmail = request['fromEmail'] as String?;
    final fromAvatarUrl = request['fromAvatarUrl'] as String?;

    if (fromUid == null || fromUid.isEmpty) {
      return const FriendAddResult(
        success: false,
        message: 'Invalid friend request.',
      );
    }

    try {
      final myCode = await getMyCode();
      final myProfile = await findPublicProfileByCode(myCode);

      debugPrint('=== ACCEPT FRIEND REQUEST ===');
      debugPrint('Current UID: $currentUid');
      debugPrint('From UID: $fromUid');
      debugPrint('My Code: $myCode');

      final batch = FirebaseFirestore.instance.batch();

      // Add friend to my friends collection
      final myFriendsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('friends')
          .doc(fromUid);
      debugPrint('Writing to my friends: users/$currentUid/friends/$fromUid');
      batch.set(myFriendsRef, {
        'friendId': fromUid,
        'friendUid': fromUid,
        'name': fromName,
        'code': fromCode,
        'role': 'Viewer',
        'email': fromEmail,
        'avatarUrl': fromAvatarUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Add myself to their friends collection
      final theirFriendsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(fromUid)
          .collection('friends')
          .doc(currentUid);
      debugPrint('Writing to their friends: users/$fromUid/friends/$currentUid');
      batch.set(theirFriendsRef, {
        'friendId': currentUid,
        'friendUid': currentUid,
        'name': myProfile?.name ?? '',
        'code': myCode,
        'role': 'Viewer',
        'email': myProfile?.email ?? '',
        'avatarUrl': myProfile?.avatarUrl ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update request status to accepted
      final requestRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('friend_requests')
          .doc(fromUid);
      debugPrint('Updating request status: users/$currentUid/friend_requests/$fromUid');
      batch.update(requestRef, {
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Committing batch write...');
      await batch.commit().timeout(const Duration(seconds: 8));
      debugPrint('Batch write SUCCESS!');

      _cachedFriends = null;

      final friend = Friend(
        id: fromUid,
        uid: fromUid,
        name: fromName,
        role: 'Viewer',
        code: fromCode,
        email: fromEmail,
        avatarUrl: fromAvatarUrl,
      );

      return FriendAddResult(
        success: true,
        message: '$fromName is now your friend!',
        friend: friend,
      );
    } catch (e) {
      debugPrint('Failed to accept friend request: $e');
      return FriendAddResult(
        success: false,
        message: 'Failed to accept friend request: ${e.toString().split(':').first}',
      );
    }
  }

  Future<bool> declineFriendRequest(Map<String, dynamic> request) async {
    final currentUid = await _currentUserId();
    if (currentUid == null) return false;

    final fromUid = request['fromUid'] as String?;
    if (fromUid == null || fromUid.isEmpty) return false;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('friend_requests')
          .doc(fromUid)
          .update({
            'status': 'rejected',
            'updatedAt': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 5));
      return true;
    } catch (e) {
      debugPrint('Failed to decline friend request: $e');
      return false;
    }
  }

  String _normalizeCode(String code) {
    final compact = code.trim().toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );
    if (RegExp(r'^[A-Z]{2}[0-9]{4}$').hasMatch(compact)) {
      return '${compact.substring(0, 2)}-${compact.substring(2)}';
    }
    return code.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  }

  String _generateCode(String seed, String? uid) {
    final cleaned = seed.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final prefix = (cleaned.isEmpty ? 'HP' : cleaned)
        .padRight(2, 'H')
        .substring(0, 2);
    final uniquenessSeed = uid?.isNotEmpty == true ? '$seed-$uid' : seed;
    final numeric = (uniquenessSeed.hashCode.abs() % 10000).toString().padLeft(
      4,
      '0',
    );
    return '$prefix-$numeric';
  }
}
