import 'package:flutter/material.dart';

import '../models/admin_user.dart';
import '../models/admin_user_role.dart';

class AdminGuard extends StatelessWidget {
  final AdminUser adminUser;
  final AdminUserRole minimumRole;
  final Widget child;

  const AdminGuard({
    super.key,
    required this.adminUser,
    required this.minimumRole,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final allowed = switch (minimumRole) {
      AdminUserRole.owner => adminUser.role == AdminUserRole.owner,
      AdminUserRole.editor => adminUser.role == AdminUserRole.owner ||
          adminUser.role == AdminUserRole.editor,
      AdminUserRole.viewer => true,
    };
    if (allowed) return child;
    return const _LockedAdminState();
  }
}

class _LockedAdminState extends StatelessWidget {
  const _LockedAdminState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 14),
              Text(
                'Access restricted',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Your admin role does not allow access to this page.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
