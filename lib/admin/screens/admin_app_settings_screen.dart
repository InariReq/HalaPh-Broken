import 'package:flutter/material.dart';

import '../models/admin_app_settings.dart';
import '../models/admin_user.dart';
import '../models/admin_user_role.dart';
import '../services/admin_app_settings_service.dart';

class AdminAppSettingsScreen extends StatefulWidget {
  final AdminUser currentAdmin;

  const AdminAppSettingsScreen({
    super.key,
    required this.currentAdmin,
  });

  @override
  State<AdminAppSettingsScreen> createState() => _AdminAppSettingsScreenState();
}

class _AdminAppSettingsScreenState extends State<AdminAppSettingsScreen> {
  final _service = AdminAppSettingsService();

  bool get _canEdit => widget.currentAdmin.role == AdminUserRole.owner;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AdminAppSettingsSnapshot>(
      stream: _service.watchPublicConfig(),
      builder: (context, snapshot) {
        final config = snapshot.data;
        return ListView(
          padding: const EdgeInsets.all(28),
          children: [
            _buildHeader(context, config),
            const SizedBox(height: 16),
            if (!_canEdit) ...[
              const _ReadOnlyNotice(),
              const SizedBox(height: 16),
            ],
            if (snapshot.connectionState == ConnectionState.waiting)
              const _LoadingCard()
            else if (snapshot.hasError)
              _ErrorCard(error: snapshot.error)
            else if (config == null)
              const _ErrorCard(error: 'Settings response was empty.')
            else
              _SettingsCard(
                snapshot: config,
                canEdit: _canEdit,
                onEdit: () => _openEditDialog(config.settings),
              ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AdminAppSettingsSnapshot? snapshot,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            SizedBox(
              width: 560,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 42,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'App Settings',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Configure public app content and admin-controlled flags.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _canEdit && snapshot != null
                  ? () => _openEditDialog(snapshot.settings)
                  : null,
              icon: const Icon(Icons.save_as_rounded),
              label: Text(snapshot?.exists == false
                  ? 'Save Initial Config'
                  : 'Edit Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditDialog(AdminAppSettings settings) async {
    final result = await showDialog<AdminAppSettings>(
      context: context,
      builder: (context) => _SettingsFormDialog(settings: settings),
    );
    if (result == null || !mounted) return;
    try {
      await _service.savePublicConfig(
        settings: result,
        actorUid: widget.currentAdmin.uid,
      );
      if (mounted) _showSnack('App settings saved.');
    } catch (_) {
      if (mounted) _showSnack('Could not save app settings.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SettingsCard extends StatelessWidget {
  final AdminAppSettingsSnapshot snapshot;
  final bool canEdit;
  final VoidCallback onEdit;

  const _SettingsCard({
    required this.snapshot,
    required this.canEdit,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final settings = snapshot.settings;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      settings.appName,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(snapshot.exists
                        ? 'Document: admin_app_settings/public_config'
                        : 'Using default values. Owner can save initial config.'),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: canEdit ? onEdit : null,
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Edit'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SettingChip(
                  icon: Icons.construction_rounded,
                  label: settings.maintenanceMode
                      ? 'Maintenance on'
                      : 'Maintenance off',
                ),
                _SettingChip(
                  icon: Icons.tour_rounded,
                  label: settings.guideModeDefaultEnabled
                      ? 'Guide default on'
                      : 'Guide default off',
                ),
                _SettingChip(
                  icon: Icons.star_rounded,
                  label: settings.featuredPlacesEnabled
                      ? 'Featured places on'
                      : 'Featured places off',
                ),
                _SettingChip(
                  icon: Icons.campaign_rounded,
                  label: settings.adsEnabled ? 'Ads on' : 'Ads off',
                ),
                _SettingChip(
                  icon: Icons.fullscreen_rounded,
                  label: settings.fullscreenAdsEnabled
                      ? 'Fullscreen ads on'
                      : 'Fullscreen ads off',
                ),
              ],
            ),
            const SizedBox(height: 18),
            _InfoRow(
              label: 'Announcement title',
              value: settings.announcementTitle.isEmpty
                  ? 'None'
                  : settings.announcementTitle,
            ),
            const SizedBox(height: 10),
            _InfoRow(
              label: 'Announcement body',
              value: settings.announcementBody.isEmpty
                  ? 'None'
                  : settings.announcementBody,
            ),
            const Divider(height: 28),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Text(
                  'Updated: ${settings.updatedAt == null ? 'Not saved yet' : _formatDateTime(settings.updatedAt!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'Updated by: ${settings.updatedBy.isEmpty ? '—' : settings.updatedBy}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsFormDialog extends StatefulWidget {
  final AdminAppSettings settings;

  const _SettingsFormDialog({required this.settings});

  @override
  State<_SettingsFormDialog> createState() => _SettingsFormDialogState();
}

class _SettingsFormDialogState extends State<_SettingsFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _appNameController;
  late final TextEditingController _announcementTitleController;
  late final TextEditingController _announcementBodyController;
  late bool _maintenanceMode;
  late bool _guideModeDefaultEnabled;
  late bool _featuredPlacesEnabled;
  late bool _adsEnabled;
  late bool _fullscreenAdsEnabled;

  @override
  void initState() {
    super.initState();
    final settings = widget.settings;
    _appNameController = TextEditingController(text: settings.appName);
    _announcementTitleController =
        TextEditingController(text: settings.announcementTitle);
    _announcementBodyController =
        TextEditingController(text: settings.announcementBody);
    _maintenanceMode = settings.maintenanceMode;
    _guideModeDefaultEnabled = settings.guideModeDefaultEnabled;
    _featuredPlacesEnabled = settings.featuredPlacesEnabled;
    _adsEnabled = settings.adsEnabled;
    _fullscreenAdsEnabled = settings.fullscreenAdsEnabled;
  }

  @override
  void dispose() {
    _appNameController.dispose();
    _announcementTitleController.dispose();
    _announcementBodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit App Settings'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _appNameController,
                  decoration: const InputDecoration(labelText: 'App name'),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'App name is required.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _announcementTitleController,
                  decoration:
                      const InputDecoration(labelText: 'Announcement title'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _announcementBodyController,
                  decoration:
                      const InputDecoration(labelText: 'Announcement body'),
                  minLines: 3,
                  maxLines: 6,
                ),
                const SizedBox(height: 12),
                _SettingsSwitch(
                  title: 'Maintenance mode',
                  subtitle:
                      'Marks the public app as under maintenance when connected in a later phase.',
                  value: _maintenanceMode,
                  onChanged: (value) => setState(() {
                    _maintenanceMode = value;
                  }),
                ),
                _SettingsSwitch(
                  title: 'Guide Mode default enabled',
                  subtitle:
                      'Default visibility flag for Guide Mode when app settings are connected later.',
                  value: _guideModeDefaultEnabled,
                  onChanged: (value) => setState(() {
                    _guideModeDefaultEnabled = value;
                  }),
                ),
                _SettingsSwitch(
                  title: 'Featured places enabled',
                  subtitle:
                      'Allows admin-managed featured places when user app integration is added.',
                  value: _featuredPlacesEnabled,
                  onChanged: (value) => setState(() {
                    _featuredPlacesEnabled = value;
                  }),
                ),
                _SettingsSwitch(
                  title: 'Ads enabled',
                  subtitle:
                      'Allows admin-managed ad placements in the user app.',
                  value: _adsEnabled,
                  onChanged: (value) => setState(() {
                    _adsEnabled = value;
                    if (!value) {
                      _fullscreenAdsEnabled = false;
                    }
                  }),
                ),
                _SettingsSwitch(
                  title: 'Fullscreen ads enabled',
                  subtitle:
                      'Allows one fullscreen sponsored ad after a completed action.',
                  value: _fullscreenAdsEnabled,
                  onChanged: (value) => setState(() {
                    _fullscreenAdsEnabled = value;
                    if (value) {
                      _adsEnabled = true;
                    }
                  }),
                ),
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
          child: const Text('Save settings'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      AdminAppSettings(
        id: AdminAppSettings.documentId,
        appName: _appNameController.text.trim(),
        announcementTitle: _announcementTitleController.text.trim(),
        announcementBody: _announcementBodyController.text.trim(),
        maintenanceMode: _maintenanceMode,
        guideModeDefaultEnabled: _guideModeDefaultEnabled,
        featuredPlacesEnabled: _featuredPlacesEnabled,
        adsEnabled: _adsEnabled,
        fullscreenAdsEnabled: _fullscreenAdsEnabled,
      ),
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _ReadOnlyNotice extends StatelessWidget {
  const _ReadOnlyNotice();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.visibility_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: const Text('Read-only access'),
        subtitle: const Text(
          'Head Admin and Admin accounts can view app settings. Owner access is required to save changes.',
        ),
      ),
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

  const _ErrorCard({required this.error});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.error_outline_rounded,
          color: Theme.of(context).colorScheme.error,
        ),
        title: const Text('App settings unavailable'),
        subtitle: Text(
          'Could not load app settings. Check admin permissions and try again. ${error ?? ''}',
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(value),
      ],
    );
  }
}

class _SettingChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SettingChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}

String _formatDateTime(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.year}-$month-$day $hour:$minute';
}
