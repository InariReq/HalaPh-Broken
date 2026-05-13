import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_user_role.dart';

class AdminUser {
  final String uid;
  final String email;
  final String displayName;
  final AdminUserRole role;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String createdBy;
  final String updatedBy;

  const AdminUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    this.createdBy = '',
    this.updatedBy = '',
  });

  factory AdminUser.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AdminUser(
      uid: doc.id,
      email: (data['email'] as String?)?.trim() ?? '',
      displayName: (data['displayName'] as String?)?.trim() ?? '',
      role: AdminUserRole.fromString(data['role'] as String?),
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
      'email': email,
      'displayName': displayName,
      'role': role.name,
      'isActive': isActive,
      'createdAt': now,
      'updatedAt': now,
      'createdBy': actorUid,
      'updatedBy': actorUid,
    };
  }

  Map<String, Object?> toUpdateMap({required String actorUid}) {
    return {
      'email': email,
      'displayName': displayName,
      'role': role.name,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actorUid,
    };
  }

  AdminUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    AdminUserRole? role,
    bool? isActive,
  }) {
    return AdminUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdBy: createdBy,
      updatedBy: updatedBy,
    );
  }

  static DateTime? _timestampToDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }
}
