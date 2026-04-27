import 'package:halaph/db/local_db.dart';
import 'package:halaph/models/friend.dart';
import 'package:halaph/services/auth_service.dart';
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

  Future<String> getMyCode() async {
    final stored = await LocalDb.instance.loadProfileCode();
    if (stored != null && stored.isNotEmpty) return stored;

    final remoteProfile = await RemoteSyncService.instance.loadNamespace(
      'profile',
    );
    final remoteCode = remoteProfile?['code'] as String?;
    if (remoteCode != null && remoteCode.isNotEmpty) {
      await LocalDb.instance.saveProfileCode(remoteCode);
      return remoteCode;
    }

    final user = await AuthService().getCurrentUser();
    final seed = user?.email ?? user?.name ?? 'traveler';
    final generated = _generateCode(seed);
    await LocalDb.instance.saveProfileCode(generated);
    await RemoteSyncService.instance.saveNamespace('profile', {
      'code': generated,
    });
    return generated;
  }

  Future<List<Friend>> getFriends() async {
    final localFriends = await LocalDb.instance.loadFriends();
    final remoteFriends = await _loadRemoteFriends();
    final friends = _mergeFriends(localFriends, remoteFriends);
    if (remoteFriends.isNotEmpty) {
      await LocalDb.instance.saveFriends(friends);
    }
    friends.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return friends;
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

    final friend = Friend(
      id: 'friend_${DateTime.now().microsecondsSinceEpoch}',
      name: 'Friend $code',
      role: 'Viewer',
      code: code,
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

  Future<void> updateFriendRole(String friendId, String role) async {
    final friends = await getFriends();
    final updated = friends.map((friend) {
      if (friend.id != friendId) return friend;
      return Friend(
        id: friend.id,
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
    await LocalDb.instance.saveFriends(friends);
    await RemoteSyncService.instance.saveNamespace('friends', {
      'friends': friends.map((friend) => friend.toJson()).toList(),
    });
  }

  List<Friend> _mergeFriends(List<Friend> local, List<Friend> remote) {
    final byCode = <String, Friend>{};
    for (final friend in local) {
      byCode[_normalizeCode(friend.code)] = friend;
    }
    for (final friend in remote) {
      byCode[_normalizeCode(friend.code)] = friend;
    }
    return byCode.values.toList();
  }

  String _normalizeCode(String code) {
    return code.trim().toUpperCase().replaceAll(' ', '');
  }

  String _generateCode(String seed) {
    final cleaned = seed.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final prefix = (cleaned.isEmpty ? 'HP' : cleaned)
        .padRight(2, 'H')
        .substring(0, 2);
    final numeric = (seed.hashCode.abs() % 10000).toString().padLeft(4, '0');
    return '$prefix-$numeric';
  }
}
