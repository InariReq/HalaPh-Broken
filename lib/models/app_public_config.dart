import 'package:cloud_firestore/cloud_firestore.dart';

class AppPublicConfig {
  static const collectionPath = 'admin_app_settings';
  static const documentId = 'public_config';

  final String appName;
  final String announcementTitle;
  final String announcementBody;
  final bool maintenanceMode;
  final bool guideModeDefaultEnabled;
  final bool featuredPlacesEnabled;
  final bool adsEnabled;
  final bool bannerAdsEnabled;
  final bool sponsoredCardsEnabled;
  final bool fullscreenAdsEnabled;
  final int maxAdsPerScreen;
  final int minCardsBeforeSponsored;
  final DateTime? updatedAt;
  final String updatedBy;

  const AppPublicConfig({
    required this.appName,
    required this.announcementTitle,
    required this.announcementBody,
    required this.maintenanceMode,
    required this.guideModeDefaultEnabled,
    required this.featuredPlacesEnabled,
    required this.adsEnabled,
    required this.bannerAdsEnabled,
    required this.sponsoredCardsEnabled,
    required this.fullscreenAdsEnabled,
    required this.maxAdsPerScreen,
    required this.minCardsBeforeSponsored,
    this.updatedAt,
    required this.updatedBy,
  });

  const AppPublicConfig.defaults()
      : appName = 'HalaPH',
        announcementTitle = '',
        announcementBody = '',
        maintenanceMode = false,
        guideModeDefaultEnabled = false,
        featuredPlacesEnabled = true,
        adsEnabled = true,
        bannerAdsEnabled = true,
        sponsoredCardsEnabled = true,
        fullscreenAdsEnabled = false,
        maxAdsPerScreen = 1,
        minCardsBeforeSponsored = 4,
        updatedAt = null,
        updatedBy = '';

  bool get hasAnnouncement =>
      announcementTitle.trim().isNotEmpty || announcementBody.trim().isNotEmpty;

  factory AppPublicConfig.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (!snapshot.exists) return const AppPublicConfig.defaults();
    return AppPublicConfig.fromMap(
        snapshot.data() ?? const <String, dynamic>{});
  }

  factory AppPublicConfig.fromMap(Map<String, dynamic> data) {
    return AppPublicConfig(
      appName: _stringValue(data['appName'], fallback: 'HalaPH'),
      announcementTitle: _stringValue(data['announcementTitle']),
      announcementBody: _stringValue(data['announcementBody']),
      maintenanceMode: data['maintenanceMode'] == true,
      guideModeDefaultEnabled: data['guideModeDefaultEnabled'] == true,
      featuredPlacesEnabled: data['featuredPlacesEnabled'] != false,
      adsEnabled: data['adsEnabled'] != false,
      bannerAdsEnabled: data['bannerAdsEnabled'] != false,
      sponsoredCardsEnabled: data['sponsoredCardsEnabled'] != false,
      fullscreenAdsEnabled: data['fullscreenAdsEnabled'] == true,
      maxAdsPerScreen: _intValue(data['maxAdsPerScreen'], fallback: 1),
      minCardsBeforeSponsored: _intValue(
        data['minCardsBeforeSponsored'],
        fallback: 4,
      ),
      updatedAt: _timestampToDate(data['updatedAt']),
      updatedBy: _stringValue(data['updatedBy']),
    );
  }

  static String _stringValue(Object? value, {String fallback = ''}) {
    if (value is! String) return fallback;
    final trimmed = value.trim();
    return trimmed.isEmpty && fallback.isNotEmpty ? fallback : trimmed;
  }

  static int _intValue(Object? value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return fallback;
  }

  static DateTime? _timestampToDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }
}
