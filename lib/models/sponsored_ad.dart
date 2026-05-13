import 'package:cloud_firestore/cloud_firestore.dart';

class SponsoredAd {
  static const collectionPath = 'admin_ads';
  static const sponsoredCardPlacement = 'sponsoredCard';

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
    final starts = startsAt;
    final ends = endsAt;
    return isActive &&
        placement == sponsoredCardPlacement &&
        (starts == null || !starts.isAfter(now)) &&
        (ends == null || !ends.isBefore(now));
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
    final placement = _requiredString(data['placement'], 'placement');
    final isActive = data['isActive'];

    if (isActive is! bool) {
      throw const FormatException('Sponsored ad is missing isActive.');
    }

    return SponsoredAd(
      id: snapshot.id,
      title: title,
      advertiserName: advertiserName,
      placement: placement,
      imageUrl: _optionalString(data['imageUrl']),
      targetUrl: _optionalString(data['targetUrl']),
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

  static int _priorityValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return 10;
  }

  static DateTime? _timestampToDate(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    throw const FormatException('Sponsored ad schedule must be a timestamp.');
  }
}
