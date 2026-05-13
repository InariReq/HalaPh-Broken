import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin_app_settings.dart';

class AdminAppSettingsSnapshot {
  final AdminAppSettings settings;
  final bool exists;

  const AdminAppSettingsSnapshot({
    required this.settings,
    required this.exists,
  });
}

class AdminAppSettingsService {
  final FirebaseFirestore _firestore;

  AdminAppSettingsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _document => _firestore
      .collection('admin_app_settings')
      .doc(AdminAppSettings.documentId);

  Stream<AdminAppSettingsSnapshot> watchPublicConfig() {
    return _document.snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return AdminAppSettingsSnapshot(
          settings: AdminAppSettings.defaults(),
          exists: false,
        );
      }
      return AdminAppSettingsSnapshot(
        settings: AdminAppSettings.fromSnapshot(snapshot),
        exists: true,
      );
    });
  }

  Future<void> savePublicConfig({
    required AdminAppSettings settings,
    required String actorUid,
  }) async {
    await _document.set(
      settings.toSaveMap(actorUid: actorUid),
      SetOptions(merge: true),
    );
  }
}
