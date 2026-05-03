import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:halaph/utils/firebase_modes.dart';

class DatabaseResetService {
  static const List<String> _knownSubcollections = [
    'members',
    'updates',
    'messages'
  ];

  static Future<void> _deleteCollection(
      CollectionReference<Map<String, dynamic>> coll) async {
    final snapshot = await coll.get();
    for (final doc in snapshot.docs) {
      for (final subName in _knownSubcollections) {
        final sub = doc.reference.collection(subName);
        await _deleteCollection(sub);
      }
      await doc.reference.delete();
    }
  }

  static Future<void> _wipeAllCollections() async {
    final topCollections = [
      'sharedPlans',
      'cached_destinations',
      'publicProfiles',
      'users',
      'friend_requests',
      'notifications',
      'activity',
    ];
    for (final name in topCollections) {
      await _deleteCollection(FirebaseFirestore.instance.collection(name));
    }
  }

  static Future<void> resetFirestoreEmulatorData() async {
    try {
      if (!FirebaseModes.offline) return;
      await _wipeAllCollections();
    } catch (e) {
      debugPrint(
          'DatabaseResetService: failed to reset Firestore emulator data: $e');
    }
  }
}
