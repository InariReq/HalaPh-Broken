import 'package:cloud_firestore/cloud_firestore.dart';

class AdminLocation {
  final String id;
  final String name;
  final String city;
  final String province;
  final String category;
  final String description;
  final double? latitude;
  final double? longitude;
  final int priority;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String createdBy;
  final String updatedBy;

  const AdminLocation({
    required this.id,
    required this.name,
    required this.city,
    this.province = '',
    required this.category,
    this.description = '',
    this.latitude,
    this.longitude,
    required this.priority,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    this.createdBy = '',
    this.updatedBy = '',
  });

  factory AdminLocation.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AdminLocation(
      id: doc.id,
      name: (data['name'] as String?)?.trim() ?? '',
      city: (data['city'] as String?)?.trim() ?? '',
      province: (data['province'] as String?)?.trim() ?? '',
      category: (data['category'] as String?)?.trim() ?? '',
      description: (data['description'] as String?)?.trim() ?? '',
      latitude: _readDouble(data['latitude']),
      longitude: _readDouble(data['longitude']),
      priority: _readPriority(data['priority']),
      isActive: data['isActive'] == true,
      createdAt: _timestampToDate(data['createdAt']),
      updatedAt: _timestampToDate(data['updatedAt']),
      createdBy: (data['createdBy'] as String?)?.trim() ?? '',
      updatedBy: (data['updatedBy'] as String?)?.trim() ?? '',
    );
  }

  Map<String, Object?> toCreateMap({required String actorUid}) {
    final now = FieldValue.serverTimestamp();
    return {
      'name': name,
      'city': city,
      'province': province,
      'category': category,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'priority': priority,
      'isActive': isActive,
      'createdAt': now,
      'updatedAt': now,
      'createdBy': actorUid,
      'updatedBy': actorUid,
    };
  }

  Map<String, Object?> toUpdateMap({required String actorUid}) {
    return {
      'name': name,
      'city': city,
      'province': province,
      'category': category,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'priority': priority,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actorUid,
    };
  }

  bool get hasCoordinates => latitude != null && longitude != null;

  static int _readPriority(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return 10;
  }

  static double? _readDouble(Object? value) {
    if (value is num) return value.toDouble();
    return null;
  }

  static DateTime? _timestampToDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }
}
