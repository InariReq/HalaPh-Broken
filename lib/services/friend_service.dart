import 'package:halaph/db/local_db.dart';
import 'package:halaph/models/friend.dart';
import 'package:halaph/services/auth_service.dart';

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

    final user = await AuthService().getCurrentUser();
    final seed = user?.email ?? user?.name ?? 'traveler';
    final generated = _generateCode(seed);
    await LocalDb.instance.saveProfileCode(generated);
    return generated;
  }

  Future<List<Friend>> getFriends() async {
    final friends = await LocalDb.instance.loadFriends();
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
    await LocalDb.instance.saveFriends(friends);
    return FriendAddResult(
      success: true,
      message: 'Friend added successfully.',
      friend: friend,
    );
  }

  Future<void> removeFriend(String friendId) async {
    final friends = await getFriends();
    friends.removeWhere((friend) => friend.id == friendId);
    await LocalDb.instance.saveFriends(friends);
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
    await LocalDb.instance.saveFriends(updated);
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
