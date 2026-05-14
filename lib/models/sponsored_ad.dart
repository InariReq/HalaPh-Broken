import 'package:cloud_firestore/cloud_firestore.dart';

class SponsoredAd {
  static const collectionPath = 'admin_ads';
  static const sponsoredCardPlacement = 'sponsoredCard';
  static const fullscreenPlacement = 'fullscreen';

  final String id;
  final String title;
  final String advertiserName;
  final String placement;
  final String imageUrl;
  final String targetUrl;
  final String description;
  final int priority;
  final bool isActive;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String createdBy;
  final String updatedBy;

  const SponsoredAd({
    required this.id,
    required this.title,
    required this.advertiserName,
    required this.placement,
    required this.imageUrl,
    required this.targetUrl,
    required this.description,
    required this.priority,
    required this.isActive,
    this.startsAt,
    this.endsAt,
    this.createdAt,
    this.updatedAt,
    required this.createdBy,
    required this.updatedBy,
  });

  bool isActiveFor(DateTime now) {
    return isActiveForPlacement(sponsoredCardPlacement, now);
  }

  bool isActiveForPlacement(String expectedPlacement, DateTime now) {
    final starts = startsAt;
    final ends = endsAt;
    return isActive &&
        matchesPlacement(expectedPlacement) &&
        (starts == null || !starts.isAfter(now)) &&
        (ends == null || !ends.isBefore(now));
  }

  bool matchesPlacement(String expectedPlacement) {
    final normalized = placement.trim().toLowerCase();
    final expected = expectedPlacement.trim().toLowerCase();

    if (normalized == expected) return true;

    if (expected == fullscreenPlacement) {
      return normalized == 'fullscreen' ||
          normalized == 'full screen' ||
          normalized == 'full_screen' ||
          normalized == 'fullscreenad' ||
          normalized == 'fullscreen_ad';
    }

    if (expected == sponsoredCardPlacement) {
      return normalized == 'sponsoredcard' ||
          normalized == 'sponsored card' ||
          normalized == 'sponsored_card';
    }

    return false;
  }

  bool get hasHttpImage => imageUrl.startsWith('http');

  factory SponsoredAd.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw const FormatException('Sponsored ad is missing data.');
    }

    final title = _requiredString(data['title'], 'title');
    final advertiserName =
        _requiredString(data['advertiserName'], 'advertiserName');
    final placement = _requiredString(
      data['placement'] ?? data['adPlacement'] ?? data['type'],
      'placement',
    );
    final isActive = _activeValue(data);

    return SponsoredAd(
      id: snapshot.id,
      title: title,
      advertiserName: advertiserName,
      placement: placement,
      imageUrl: _optionalString(data['imageUrl']),
      targetUrl: _optionalString(
        data['targetUrl'] ??
            data['targetURL'] ??
            data['url'] ??
            data['link'] ??
            data['websiteUrl'],
      ),
      description: _optionalString(data['description']),
      priority: _priorityValue(data['priority']),
      isActive: isActive,
      startsAt: _timestampToDate(data['startsAt']),
      endsAt: _timestampToDate(data['endsAt']),
      createdAt: _timestampToDate(data['createdAt']),
      updatedAt: _timestampToDate(data['updatedAt']),
      createdBy: _optionalString(data['createdBy']),
      updatedBy: _optionalString(data['updatedBy']),
    );
  }

  static String _requiredString(Object? value, String fieldName) {
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Sponsored ad is missing $fieldName.');
    }
    return value.trim();
  }

  static String _optionalString(Object? value) {
    if (value is! String) return '';
    return value.trim();
  }

  static bool _activeValue(Map<String, dynamic> data) {
    final isActive = data['isActive'];
    if (isActive is bool) return isActive;

    final active = data['active'];
    if (active is bool) return active;

    final status = data['status'];
    if (status is String) {
      final normalized = status.trim().toLowerCase();
      if (normalized == 'active' ||
          normalized == 'enabled' ||
          normalized == 'live' ||
          normalized == 'published') {
        return true;
      }
      if (normalized == 'inactive' ||
          normalized == 'disabled' ||
          normalized == 'expired' ||
          normalized == 'draft') {
        return false;
      }
    }

    throw const FormatException('Sponsored ad is missing active status.');
  }

  static int _priorityValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return 10;
  }

  static DateTime? _timestampToDate(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    throw const FormatException('Sponsored ad schedule must be a timestamp.');
  }
}
