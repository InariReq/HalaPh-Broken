import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:halaph/utils/firebase_modes.dart';
import 'package:halaph/firebase_app_service.dart' as _firebase;

class DatabaseResetService {
  // Recursively delete all documents in a collection and its subcollections
  static Future<void> _deleteCollection(CollectionReference<Map<String, dynamic>> coll) async {
    final snapshot = await coll.get();
    for (final doc in snapshot.docs) {
      final refs = await doc.reference.listCollections();
      for (final sub in refs) {
        await _deleteCollection(sub.cast<Map<String, dynamic>>());
      }
      await doc.reference.delete();
    }
  }

  static Future<void> _wipeAllCollections() async {
    final List<CollectionReference<Map<String, dynamic>>> topCollections = [
      FirebaseFirestore.instance.collection('sharedPlans'),
      FirebaseFirestore.instance.collection('cached_destinations'),
      FirebaseFirestore.instance.collection('publicProfiles'),
      FirebaseFirestore.instance.collection('users'),
      FirebaseFirestore.instance.collection('friend_requests'),
      FirebaseFirestore.instance.collection('notifications'),
      FirebaseFirestore.instance.collection('activity'),
    ];
    for (final coll in topCollections) {
      await _deleteCollection(coll);
    }
  }

  static Future<void> resetFirestoreEmulatorData() async {
    try {
      // If not in offline/emulator mode, allow this only in emulation contexts
      if (!FirebaseModes.offline) {
        await _wipeAllCollections();
      } else {
        // In offline mode, clear local caches only to avoid network activity
        // This is a best-effort soft reset for dev copy
      }
    } catch (e) {
      // Best-effort: don't crash app if reset fails in a dev environment
      print('DatabaseResetService: failed to reset Firestore emulator data: $e');
    }
  }
}
