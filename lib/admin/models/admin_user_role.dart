enum AdminUserRole {
  owner,
  editor,
  viewer;

  static AdminUserRole fromString(String? value) {
    return AdminUserRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => AdminUserRole.viewer,
    );
  }

  String get label {
    return switch (this) {
      AdminUserRole.owner => 'Owner',
      AdminUserRole.editor => 'Editor',
      AdminUserRole.viewer => 'Viewer',
    };
  }

  bool get canManageAdminUsers => this == AdminUserRole.owner;
  bool get canManageContent =>
      this == AdminUserRole.owner || this == AdminUserRole.editor;
}
