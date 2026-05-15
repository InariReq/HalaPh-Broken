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
  final String imageUrl;
  final String googlePhotoUrl;
  final String source;
  final String googlePlaceId;
  final String googlePhotoReference;
  final int priority;
  final bool isFeatured;
  final int featuredPriority;
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
    this.imageUrl = '',
    this.googlePhotoUrl = '',
    this.source = 'admin',
    this.googlePlaceId = '',
    this.googlePhotoReference = '',
    required this.priority,
    this.isFeatured = false,
    this.featuredPriority = 999,
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
      imageUrl: _readFirstString(
        data,
        const [
          'imageUrl',
          'image',
          'photoUrl',
          'photoURL',
          'thumbnailUrl',
          'thumbnail',
          'coverImageUrl',
          'bannerImage',
          'googlePhotoUrl',
        ],
      ),
      googlePhotoUrl: _readFirstString(data, const ['googlePhotoUrl']),
      source: (data['source'] as String?)?.trim() ?? 'admin',
      googlePlaceId: _readFirstString(data, const ['googlePlaceId', 'placeId']),
      googlePhotoReference: _readFirstString(
        data,
        const [
          'googlePhotoReference',
          'photoReference',
          'photo_reference',
          'google_photo_reference',
        ],
      ),
      priority: _readPriority(data['priority']),
      isFeatured: data['isFeatured'] == true || data['featured'] == true,
      featuredPriority: _readPriority(
        data['featuredPriority'],
        fallback: 999,
      ),
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
      'imageUrl': imageUrl,
      'googlePhotoUrl': googlePhotoUrl,
      'source': source,
      'googlePlaceId': googlePlaceId,
      'googlePhotoReference': googlePhotoReference,
      'priority': priority,
      'isFeatured': isFeatured,
      'featuredPriority': featuredPriority,
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
      'imageUrl': imageUrl,
      'googlePhotoUrl': googlePhotoUrl,
      'source': source,
      'googlePlaceId': googlePlaceId,
      'googlePhotoReference': googlePhotoReference,
      'priority': priority,
      'isFeatured': isFeatured,
      'featuredPriority': featuredPriority,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actorUid,
    };
  }

  bool get hasCoordinates => latitude != null && longitude != null;

  static int _readPriority(Object? value, {int fallback = 10}) {
    if (value is int) return value;
    if (value is num) return value.round();
    return fallback;
  }

  static double? _readDouble(Object? value) {
    if (value is num) return value.toDouble();
    return null;
  }

  static String _readFirstString(
    Map<String, dynamic> data,
    List<String> fields,
  ) {
    for (final field in fields) {
      final value = data[field];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  static DateTime? _timestampToDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }
}
