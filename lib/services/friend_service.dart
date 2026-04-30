import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
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
    return List<Friend>.from(_cachedFriends!);
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
        message: 'This friend is already in your list.',
      );
    }

    final publicProfile = await findPublicProfileByCode(code);
    if (publicProfile == null) {
      return const FriendAddResult(
        success: false,
        message: 'No account found for that friend code.',
      );
    }

    final friend = Friend(
      id: publicProfile.uid ?? code,
      uid: publicProfile.uid,
      name: publicProfile.name,
      role: 'Viewer',
      code: publicProfile.code,
      email: publicProfile.email,
      avatarUrl: publicProfile.avatarUrl,
    );
    friends.add(friend);
    await _saveFriends(friends);
    return FriendAddResult(
      success: true,
      message: 'Friend added successfully.',
      friend: friend,
    );
  }

  Future<void> removeFriend(String friendId) async {
    final friends = await getFriends();
    friends.removeWhere((friend) => friend.id == friendId);
    await _saveFriends(friends);
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
    final payload = await RemoteSyncService.instance.loadNamespace('friends');
    final rawFriends = payload?['friends'];
    if (rawFriends is! List) return [];
    return rawFriends
        .whereType<Map>()
        .map((entry) => Friend.fromJson(Map<String, dynamic>.from(entry)))
        .toList();
  }

  Future<void> _saveFriends(List<Friend> friends) async {
    final userId = await _currentUserId();
    if (userId == null) return;

    _cachedUserId = userId;
    _cachedFriends = List<Friend>.from(friends);
    await RemoteSyncService.instance.saveNamespace('friends', {
      'friends': friends.map((friend) => friend.toJson()).toList(),
    });
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

  void clearCache() {
    _cachedUserId = null;
    _cachedCode = null;
    _cachedFriends = null;
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
      await FirebaseFirestore.instance
          .collection('publicProfiles')
          .doc(code)
          .set({
            'uid': firebaseUser.uid,
            'code': code,
            'name':
                firebaseUser.displayName ??
                firebaseUser.email?.split('@').first ??
                'Traveler',
            'email': firebaseUser.email,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
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
