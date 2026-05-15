import 'package:cloud_firestore/cloud_firestore.dart';

class AdminFeaturedPlace {
  final String id;
  final String name;
  final String city;
  final String category;
  final String description;
  final String imageUrl;
  final String displayNameOverride;
  final String adminDisplayName;
  final String displayName;
  final String originalName;
  final String googleName;
  final String rawName;
  final String sourceCollection;
  final String sourceId;
  final String targetId;
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
    this.displayNameOverride = '',
    this.adminDisplayName = '',
    this.displayName = '',
    this.originalName = '',
    this.googleName = '',
    this.rawName = '',
    this.sourceCollection = '',
    this.sourceId = '',
    this.targetId = '',
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
    final sourceCollection =
        (data['sourceCollection'] as String?)?.trim() ?? '';
    final sourceId = (data['sourceId'] as String?)?.trim() ?? '';
    final targetId = (data['targetId'] as String?)?.trim() ?? '';
    final fallbackName = sourceCollection.isNotEmpty && sourceId.isNotEmpty
        ? 'Reference: $sourceCollection/$sourceId'
        : '';
    final displayNameOverride =
        (data['displayNameOverride'] as String?)?.trim() ?? '';
    final adminDisplayName =
        (data['adminDisplayName'] as String?)?.trim() ?? '';
    final displayName = (data['displayName'] as String?)?.trim() ?? '';
    final name = _firstNonEmpty([
      (data['name'] as String?)?.trim() ?? '',
      displayNameOverride,
      adminDisplayName,
      displayName,
      fallbackName,
    ]);
    return AdminFeaturedPlace(
      id: doc.id,
      name: name,
      city: (data['city'] as String?)?.trim() ?? sourceCollection,
      category: (data['category'] as String?)?.trim() ??
          (sourceCollection.isEmpty ? '' : 'Reference'),
      description: (data['description'] as String?)?.trim() ?? '',
      imageUrl: (data['imageUrl'] as String?)?.trim() ?? '',
      displayNameOverride: displayNameOverride,
      adminDisplayName: adminDisplayName,
      displayName: displayName,
      originalName: (data['originalName'] as String?)?.trim() ?? '',
      googleName: (data['googleName'] as String?)?.trim() ?? '',
      rawName: (data['rawName'] as String?)?.trim() ?? '',
      sourceCollection: sourceCollection,
      sourceId: sourceId,
      targetId: targetId,
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
      if (displayNameOverride.isNotEmpty)
        'displayNameOverride': displayNameOverride,
      if (adminDisplayName.isNotEmpty) 'adminDisplayName': adminDisplayName,
      if (displayName.isNotEmpty) 'displayName': displayName,
      if (originalName.isNotEmpty) 'originalName': originalName,
      if (googleName.isNotEmpty) 'googleName': googleName,
      if (rawName.isNotEmpty) 'rawName': rawName,
      if (sourceCollection.isNotEmpty) 'sourceCollection': sourceCollection,
      if (sourceId.isNotEmpty) 'sourceId': sourceId,
      if (targetId.isNotEmpty) 'targetId': targetId,
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
      if (displayNameOverride.isNotEmpty)
        'displayNameOverride': displayNameOverride,
      if (adminDisplayName.isNotEmpty) 'adminDisplayName': adminDisplayName,
      if (displayName.isNotEmpty) 'displayName': displayName,
      if (originalName.isNotEmpty) 'originalName': originalName,
      if (googleName.isNotEmpty) 'googleName': googleName,
      if (rawName.isNotEmpty) 'rawName': rawName,
      if (sourceCollection.isNotEmpty) 'sourceCollection': sourceCollection,
      if (sourceId.isNotEmpty) 'sourceId': sourceId,
      if (targetId.isNotEmpty) 'targetId': targetId,
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
    String? displayNameOverride,
    String? adminDisplayName,
    String? displayName,
    String? originalName,
    String? googleName,
    String? rawName,
    String? sourceCollection,
    String? sourceId,
    String? targetId,
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
      displayNameOverride: displayNameOverride ?? this.displayNameOverride,
      adminDisplayName: adminDisplayName ?? this.adminDisplayName,
      displayName: displayName ?? this.displayName,
      originalName: originalName ?? this.originalName,
      googleName: googleName ?? this.googleName,
      rawName: rawName ?? this.rawName,
      sourceCollection: sourceCollection ?? this.sourceCollection,
      sourceId: sourceId ?? this.sourceId,
      targetId: targetId ?? this.targetId,
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

  static String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      if (value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }
}
