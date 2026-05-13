enum AdminUserRole {
  owner,
  headAdmin,
  admin;

  static AdminUserRole fromString(String? value) {
    final normalized = value?.trim();
    return switch (normalized) {
      'owner' => AdminUserRole.owner,
      'headAdmin' => AdminUserRole.headAdmin,
      'admin' => AdminUserRole.admin,

      // Legacy role values from the first admin dashboard build.
      'editor' => AdminUserRole.headAdmin,
      'viewer' => AdminUserRole.admin,
      _ => AdminUserRole.admin,
    };
  }

  String get label {
    return switch (this) {
      AdminUserRole.owner => 'Owner',
      AdminUserRole.headAdmin => 'Head Admin',
      AdminUserRole.admin => 'Admin',
    };
  }

  bool get canManageAdminUsers =>
      this == AdminUserRole.owner || this == AdminUserRole.headAdmin;

  bool get canManageAppSettings =>
      this == AdminUserRole.owner || this == AdminUserRole.headAdmin;

  bool get canManageContent => true;

  bool canAssignRole(AdminUserRole role) {
    return switch (this) {
      AdminUserRole.owner => true,
      AdminUserRole.headAdmin => role == AdminUserRole.admin,
      AdminUserRole.admin => false,
    };
  }

  bool canManageTarget(AdminUserRole targetRole, {required bool isSelf}) {
    if (isSelf) return false;

    return switch (this) {
      AdminUserRole.owner => true,
      AdminUserRole.headAdmin => targetRole == AdminUserRole.admin,
      AdminUserRole.admin => false,
    };
  }
}
