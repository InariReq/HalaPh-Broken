import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAppSettings {
  static const documentId = 'public_config';

  final String id;
  final String appName;
  final String announcementTitle;
  final String announcementBody;
  final bool maintenanceMode;
  final bool guideModeDefaultEnabled;
  final bool featuredPlacesEnabled;
  final bool adsEnabled;
  final DateTime? updatedAt;
  final String updatedBy;

  const AdminAppSettings({
    required this.id,
    required this.appName,
    this.announcementTitle = '',
    this.announcementBody = '',
    required this.maintenanceMode,
    required this.guideModeDefaultEnabled,
    required this.featuredPlacesEnabled,
    required this.adsEnabled,
    this.updatedAt,
    this.updatedBy = '',
  });

  factory AdminAppSettings.defaults() {
    return const AdminAppSettings(
      id: documentId,
      appName: 'HalaPH',
      maintenanceMode: false,
      guideModeDefaultEnabled: true,
      featuredPlacesEnabled: true,
      adsEnabled: false,
    );
  }

  factory AdminAppSettings.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AdminAppSettings(
      id: doc.id,
      appName: (data['appName'] as String?)?.trim() ?? 'HalaPH',
      announcementTitle: (data['announcementTitle'] as String?)?.trim() ?? '',
      announcementBody: (data['announcementBody'] as String?)?.trim() ?? '',
      maintenanceMode: data['maintenanceMode'] == true,
      guideModeDefaultEnabled: data['guideModeDefaultEnabled'] != false,
      featuredPlacesEnabled: data['featuredPlacesEnabled'] != false,
      adsEnabled: data['adsEnabled'] == true,
      updatedAt: _timestampToDate(data['updatedAt']),
      updatedBy: (data['updatedBy'] as String?)?.trim() ?? '',
    );
  }

  Map<String, Object?> toSaveMap({required String actorUid}) {
    return {
      'appName': appName,
      'announcementTitle': announcementTitle,
      'announcementBody': announcementBody,
      'maintenanceMode': maintenanceMode,
      'guideModeDefaultEnabled': guideModeDefaultEnabled,
      'featuredPlacesEnabled': featuredPlacesEnabled,
      'adsEnabled': adsEnabled,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actorUid,
    };
  }

  static DateTime? _timestampToDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }
}
