import 'package:cloud_firestore/cloud_firestore.dart';

class AdminFeaturedPlace {
  final String id;
  final String name;
  final String city;
  final String category;
  final String description;
  final String imageUrl;
  final int priority;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String createdBy;
  final String updatedBy;

  const AdminFeaturedPlace({
    required this.id,
    required this.name,
    required this.city,
    required this.category,
    this.description = '',
    this.imageUrl = '',
    required this.priority,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    this.createdBy = '',
    this.updatedBy = '',
  });

  factory AdminFeaturedPlace.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AdminFeaturedPlace(
      id: doc.id,
      name: (data['name'] as String?)?.trim() ?? '',
      city: (data['city'] as String?)?.trim() ?? '',
      category: (data['category'] as String?)?.trim() ?? '',
      description: (data['description'] as String?)?.trim() ?? '',
      imageUrl: (data['imageUrl'] as String?)?.trim() ?? '',
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
      'category': category,
      'description': description,
      'imageUrl': imageUrl,
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
      'category': category,
      'description': description,
      'imageUrl': imageUrl,
      'priority': priority,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actorUid,
    };
  }

  AdminFeaturedPlace copyWith({
    String? id,
    String? name,
    String? city,
    String? category,
    String? description,
    String? imageUrl,
    int? priority,
    bool? isActive,
  }) {
    return AdminFeaturedPlace(
      id: id ?? this.id,
      name: name ?? this.name,
      city: city ?? this.city,
      category: category ?? this.category,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      priority: priority ?? this.priority,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdBy: createdBy,
      updatedBy: updatedBy,
    );
  }

  static int _readPriority(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return 10;
  }

  static DateTime? _timestampToDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }
}
