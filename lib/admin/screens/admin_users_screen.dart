import 'package:flutter/material.dart';

import '../models/admin_user.dart';
import '../models/admin_user_role.dart';
import '../services/admin_users_service.dart';

class AdminUsersScreen extends StatefulWidget {
  final AdminUser currentAdmin;

  const AdminUsersScreen({super.key, required this.currentAdmin});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _service = AdminUsersService();
  final _searchController = TextEditingController();
  AdminUserRole? _roleFilter;
  bool? _activeFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminUser>>(
      stream: _service.watchAdminUsers(),
      builder: (context, snapshot) {
        final users = snapshot.data ?? const <AdminUser>[];
        final filtered = _filterUsers(users);
        return ListView(
          padding: const EdgeInsets.all(28),
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            _buildWarning(context),
            const SizedBox(height: 16),
            _buildFilters(context),
            const SizedBox(height: 16),
            if (snapshot.connectionState == ConnectionState.waiting)
              const _LoadingCard()
            else if (snapshot.hasError)
              _ErrorCard(error: snapshot.error)
            else if (filtered.isEmpty)
              const _EmptyAdminUsersCard()
            else
              _AdminUsersList(
                users: filtered,
                currentAdmin: widget.currentAdmin,
                onEdit: _openEditDialog,
                onToggleActive: _toggleActive,
              ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Admin Users',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Owners can add, edit, enable, and disable admin access. Head Admins can manage content. Admins have basic dashboard access.',
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: _openAddDialog,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Add Admin'),
        ),
      ],
    );
  }

  Widget _buildWarning(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'The user must already have a Firebase account. Add the UID from Firebase Authentication.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search UID, email, or name',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            SizedBox(
              width: 190,
              child: DropdownButtonFormField<AdminUserRole?>(
                initialValue: _roleFilter,
                decoration: const InputDecoration(labelText: 'Role'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All roles')),
                  for (final role in AdminUserRole.values)
                    DropdownMenuItem(value: role, child: Text(role.label)),
                ],
                onChanged: (value) => setState(() => _roleFilter = value),
              ),
            ),
            SizedBox(
              width: 190,
              child: DropdownButtonFormField<bool?>(
                initialValue: _activeFilter,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All status')),
                  DropdownMenuItem(value: true, child: Text('Active')),
                  DropdownMenuItem(value: false, child: Text('Disabled')),
                ],
                onChanged: (value) => setState(() => _activeFilter = value),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<AdminUser> _filterUsers(List<AdminUser> users) {
    final query = _searchController.text.trim().toLowerCase();
    return users.where((user) {
      final matchesQuery = query.isEmpty ||
          user.uid.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query) ||
          user.displayName.toLowerCase().contains(query);
      final matchesRole = _roleFilter == null || user.role == _roleFilter;
      final matchesActive =
          _activeFilter == null || user.isActive == _activeFilter;
      return matchesQuery && matchesRole && matchesActive;
    }).toList(growable: false);
  }

  Future<void> _openAddDialog() async {
    final result = await showDialog<AdminUser>(
      context: context,
      builder: (context) =>
          _AdminUserFormDialog(currentAdmin: widget.currentAdmin),
    );
    if (result == null || !mounted) return;
    try {
      await _service.createAdminUser(
        adminUser: result,
        actorUid: widget.currentAdmin.uid,
      );
      if (mounted) _showSnack('Admin user added.');
    } catch (_) {
      if (mounted) _showSnack('Could not add admin user.');
    }
  }

  Future<void> _openEditDialog(AdminUser user) async {
    final result = await showDialog<AdminUser>(
      context: context,
      builder: (context) => _AdminUserFormDialog(
        currentAdmin: widget.currentAdmin,
        existingUser: user,
      ),
    );
    if (result == null || !mounted) return;
    try {
      await _service.updateAdminUser(
        adminUser: result,
        actorUid: widget.currentAdmin.uid,
      );
      if (mounted) _showSnack('Admin user updated.');
    } catch (_) {
      if (mounted) _showSnack('Could not update admin user.');
    }
  }

  Future<void> _toggleActive(AdminUser user) async {
    if (user.uid == widget.currentAdmin.uid && user.isActive) {
      _showSnack('You cannot disable your own owner account.');
      return;
    }
    try {
      await _service.setActive(
        uid: user.uid,
        isActive: !user.isActive,
        actorUid: widget.currentAdmin.uid,
      );
      if (mounted) {
        _showSnack(user.isActive ? 'Admin disabled.' : 'Admin enabled.');
      }
    } catch (_) {
      if (mounted) _showSnack('Could not update admin status.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AdminUsersList extends StatelessWidget {
  final List<AdminUser> users;
  final AdminUser currentAdmin;
  final ValueChanged<AdminUser> onEdit;
  final ValueChanged<AdminUser> onToggleActive;

  const _AdminUsersList({
    required this.users,
    required this.currentAdmin,
    required this.onEdit,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            children: [
              for (final user in users)
                _AdminUserCard(
                  user: user,
                  currentAdmin: currentAdmin,
                  onEdit: onEdit,
                  onToggleActive: onToggleActive,
                ),
            ],
          );
        }
        return Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Name')),
                DataColumn(label: Text('Email')),
                DataColumn(label: Text('UID')),
                DataColumn(label: Text('Role')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: [
                for (final user in users)
                  DataRow(
                    cells: [
                      DataCell(Text(user.displayName)),
                      DataCell(Text(user.email)),
                      DataCell(SelectableText(user.uid)),
                      DataCell(_RoleBadge(role: user.role)),
                      DataCell(_StatusBadge(isActive: user.isActive)),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit',
                              onPressed: () => onEdit(user),
                              icon: const Icon(Icons.edit_rounded),
                            ),
                            IconButton(
                              tooltip: user.isActive ? 'Disable' : 'Enable',
                              onPressed:
                                  user.uid == currentAdmin.uid && user.isActive
                                      ? null
                                      : () => onToggleActive(user),
                              icon: Icon(
                                user.isActive
                                    ? Icons.block_rounded
                                    : Icons.check_circle_rounded,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AdminUserCard extends StatelessWidget {
  final AdminUser user;
  final AdminUser currentAdmin;
  final ValueChanged<AdminUser> onEdit;
  final ValueChanged<AdminUser> onToggleActive;

  const _AdminUserCard({
    required this.user,
    required this.currentAdmin,
    required this.onEdit,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    user.displayName,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                _StatusBadge(isActive: user.isActive),
              ],
            ),
            const SizedBox(height: 8),
            Text(user.email),
            const SizedBox(height: 8),
            SelectableText(user.uid),
            const SizedBox(height: 12),
            Row(
              children: [
                _RoleBadge(role: user.role),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => onEdit(user),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: user.uid == currentAdmin.uid && user.isActive
                      ? null
                      : () => onToggleActive(user),
                  icon: Icon(
                    user.isActive
                        ? Icons.block_rounded
                        : Icons.check_circle_rounded,
                  ),
                  label: Text(user.isActive ? 'Disable' : 'Enable'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminUserFormDialog extends StatefulWidget {
  final AdminUser currentAdmin;
  final AdminUser? existingUser;

  const _AdminUserFormDialog({
    required this.currentAdmin,
    this.existingUser,
  });

  @override
  State<_AdminUserFormDialog> createState() => _AdminUserFormDialogState();
}

class _AdminUserFormDialogState extends State<_AdminUserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _uidController;
  late final TextEditingController _emailController;
  late final TextEditingController _displayNameController;
  late AdminUserRole _role;
  late bool _isActive;
  String? _formError;

  bool get _isEditing => widget.existingUser != null;

  @override
  void initState() {
    super.initState();
    final user = widget.existingUser;
    _uidController = TextEditingController(text: user?.uid ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _displayNameController =
        TextEditingController(text: user?.displayName ?? '');
    _role = user?.role ?? AdminUserRole.admin;
    _isActive = user?.isActive ?? true;
  }

  @override
  void dispose() {
    _uidController.dispose();
    _emailController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Admin' : 'Add Admin'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _uidController,
                  enabled: !_isEditing,
                  decoration: const InputDecoration(labelText: 'UID'),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) return 'UID is required.';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) return 'Email is required.';
                    if (!text.contains('@')) return 'Enter a valid email.';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(labelText: 'Display name'),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Display name is required.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<AdminUserRole>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: [
                    for (final role in AdminUserRole.values)
                      DropdownMenuItem(value: role, child: Text(role.label)),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _role = value);
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
                if (_formError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _formError!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isEditing ? 'Save changes' : 'Add Admin'),
        ),
      ],
    );
  }

  void _submit() {
    setState(() => _formError = null);
    if (!_formKey.currentState!.validate()) return;

    final uid = _uidController.text.trim();
    final isSelf = uid == widget.currentAdmin.uid;
    if (isSelf && !_isActive) {
      setState(() => _formError = 'You cannot disable your own account.');
      return;
    }
    if (isSelf && _role != AdminUserRole.owner) {
      setState(() => _formError = 'You cannot demote your own owner role.');
      return;
    }

    Navigator.pop(
      context,
      AdminUser(
        uid: uid,
        email: _emailController.text.trim(),
        displayName: _displayNameController.text.trim(),
        role: _role,
        isActive: _isActive,
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final AdminUserRole role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: const Icon(Icons.shield_rounded, size: 16),
      label: Text(role.label),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;

  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(
        isActive ? Icons.check_circle_rounded : Icons.block_rounded,
        size: 16,
      ),
      label: Text(isActive ? 'Active' : 'Disabled'),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final Object? error;

  const _ErrorCard({this.error});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded,
                color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Admin users could not be loaded. Try again later.'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyAdminUsersCard extends StatelessWidget {
  const _EmptyAdminUsersCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('No admin users match the current filters.')),
      ),
    );
  }
}
