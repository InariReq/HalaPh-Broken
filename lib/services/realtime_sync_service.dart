import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for Firebase Realtime Database features like live location sharing,
/// typing indicators, and presence tracking.
class RealtimeSyncService {
  RealtimeSyncService._();
  static final instance = RealtimeSyncService._();

  final _db = FirebaseDatabase.instance;
  final _auth = FirebaseAuth.instance;

  /// Get reference to a specific path
  DatabaseReference ref([String? path]) {
    if (path != null) return _db.ref(path);
    return _db.ref();
  }

  /// Share current location with plan collaborators
  Future<void> shareLocation({
    required String planId,
    required double latitude,
    required double longitude,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _db.ref('plan_locations/$planId/$uid').set({
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': ServerValue.timestamp,
      'name': _auth.currentUser?.displayName ?? 'Unknown',
    });
  }

  /// Listen to location updates for a plan
  Stream<Map<String, dynamic>> listenToLocations(String planId) {
    return _db
        .ref('plan_locations/$planId')
        .onValue
        .map((event) {
          final data = event.snapshot.value as Map?;
          if (data == null) return <String, dynamic>{};
          return Map<String, dynamic>.from(data);
        });
  }

  /// Set user presence (online/offline)
  Future<void> setUserPresence({required bool isOnline}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _db.ref('presence/$uid').set({
      'online': isOnline,
      'lastSeen': ServerValue.timestamp,
    });
  }

  /// Listen to user presence
  Stream<bool> listenToPresence(String userId) {
    return _db.ref('presence/$userId/online').onValue.map(
          (event) => event.snapshot.value as bool? ?? false,
        );
  }

  /// Send typing indicator for chat/messages
  Future<void> setTyping({
    required String chatId,
    required bool isTyping,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _db.ref('typing/$chatId/$uid').set({
      'typing': isTyping,
      'timestamp': ServerValue.timestamp,
    });
  }

  /// Listen to typing indicators
  Stream<Map<String, dynamic>> listenToTyping(String chatId) {
    return _db.ref('typing/$chatId').onValue.map((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return <String, dynamic>{};
      return Map<String, dynamic>.from(data);
    });
  }

  /// Clean up user's location when leaving plan
  Future<void> removeLocation(String planId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.ref('plan_locations/$planId/$uid').remove();
  }
}
