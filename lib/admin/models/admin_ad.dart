import 'package:cloud_firestore/cloud_firestore.dart';

enum AdminAdPlacement {
  banner,
  fullscreen,
  sponsoredCard;

  static AdminAdPlacement fromString(String? value) {
    return switch (value?.trim()) {
      'fullscreen' => AdminAdPlacement.fullscreen,
      'sponsoredCard' => AdminAdPlacement.sponsoredCard,
      _ => AdminAdPlacement.sponsoredCard,
    };
  }

  String get label {
    return switch (this) {
      AdminAdPlacement.banner => 'Legacy Banner',
      AdminAdPlacement.fullscreen => 'Fullscreen',
      AdminAdPlacement.sponsoredCard => 'Sponsored Card',
    };
  }
}

class AdminAd {
  final String id;
  final String title;
  final String advertiserName;
  final AdminAdPlacement placement;
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

  const AdminAd({
    required this.id,
    required this.title,
    required this.advertiserName,
    required this.placement,
    this.imageUrl = '',
    this.targetUrl = '',
    this.description = '',
    required this.priority,
    required this.isActive,
    this.startsAt,
    this.endsAt,
    this.createdAt,
    this.updatedAt,
    this.createdBy = '',
    this.updatedBy = '',
  });

  factory AdminAd.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AdminAd(
      id: doc.id,
      title: (data['title'] as String?)?.trim() ?? '',
      advertiserName: (data['advertiserName'] as String?)?.trim() ?? '',
      placement: AdminAdPlacement.fromString(data['placement'] as String?),
      imageUrl: (data['imageUrl'] as String?)?.trim() ?? '',
      targetUrl: (data['targetUrl'] as String?)?.trim() ?? '',
      description: (data['description'] as String?)?.trim() ?? '',
      priority: _readPriority(data['priority']),
      isActive: data['isActive'] == true,
      startsAt: _timestampToDate(data['startsAt']),
      endsAt: _timestampToDate(data['endsAt']),
      createdAt: _timestampToDate(data['createdAt']),
      updatedAt: _timestampToDate(data['updatedAt']),
      createdBy: (data['createdBy'] as String?)?.trim() ?? '',
      updatedBy: (data['updatedBy'] as String?)?.trim() ?? '',
    );
  }

  Map<String, Object?> toCreateMap({required String actorUid}) {
    final now = FieldValue.serverTimestamp();
    return {
      'title': title,
      'advertiserName': advertiserName,
      'placement': placement.name,
      'imageUrl': imageUrl,
      'targetUrl': targetUrl,
      'description': description,
      'priority': priority,
      'isActive': isActive,
      'startsAt': _dateToTimestamp(startsAt),
      'endsAt': _dateToTimestamp(endsAt),
      'createdAt': now,
      'updatedAt': now,
      'createdBy': actorUid,
      'updatedBy': actorUid,
    };
  }

  Map<String, Object?> toUpdateMap({required String actorUid}) {
    return {
      'title': title,
      'advertiserName': advertiserName,
      'placement': placement.name,
      'imageUrl': imageUrl,
      'targetUrl': targetUrl,
      'description': description,
      'priority': priority,
      'isActive': isActive,
      'startsAt': _dateToTimestamp(startsAt),
      'endsAt': _dateToTimestamp(endsAt),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actorUid,
    };
  }

  bool get hasSchedule => startsAt != null || endsAt != null;

  static int _readPriority(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return 10;
  }

  static DateTime? _timestampToDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }

  static Timestamp? _dateToTimestamp(DateTime? value) {
    return value == null ? null : Timestamp.fromDate(value);
  }
}
