import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:halaph/services/auth_service.dart';
import 'package:halaph/services/plan_notification_service.dart';
import 'package:halaph/services/simple_plan_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = AuthService();
  bool _notificationsEnabled = false;
  bool _deletingAccount = false;

  @override
  void initState() {
    super.initState();
    _loadPlanReminderSetting();
  }

  Future<void> _loadPlanReminderSetting() async {
    final enabled = await PlanNotificationService.arePlanRemindersEnabled();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = enabled;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() {
      _notificationsEnabled = value;
    });

    await PlanNotificationService.setPlanRemindersEnabled(value);

    if (value) {
      await SimplePlanService.refreshPlanReminders();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan reminders turned on')),
      );
    } else {
      await SimplePlanService.cancelAllPlanReminders();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan reminders turned off')),
      );
    }
  }

  Future<void> _deleteAccount() async {
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your Firebase account access. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (firstConfirm != true) return;
    if (!mounted) return;

    final passwordController = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm delete account'),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            helperText: 'Enter your password to confirm deletion.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, passwordController.text),
            child: const Text(
              'Delete Account',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    passwordController.dispose();

    if (password == null || password.trim().isEmpty) return;

    setState(() {
      _deletingAccount = true;
    });

    final success = await _auth.deleteCurrentAccount(password: password);

    if (!mounted) return;

    setState(() {
      _deletingAccount = false;
    });

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_auth.lastAuthError ?? 'Could not delete account.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account deleted.')),
    );

    context.go('/accounts');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFFF8F9FA),
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _section(
              title: 'Permissions',
              children: [
                _infoRow(
                  icon: Icons.location_on_outlined,
                  title: 'Location',
                  subtitle:
                      'Used to show nearby places and improve route planning. You can change this in iOS Settings.',
                ),
                const Divider(height: 24),
                _infoRow(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  subtitle:
                      'Used for local plan reminders. Remote push notifications are separate.',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _section(
              title: 'Plan Reminder',
              children: [
                SwitchListTile(
                  value: _notificationsEnabled,
                  onChanged: _toggleNotifications,
                  title: const Text('Plan Reminder'),
                  subtitle: const Text(
                    'Notify 1 hour before the first stop and 30 minutes before each next stop.',
                  ),
                  activeThumbColor: Colors.blue,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _section(
              title: 'Privacy and Account',
              children: [
                _dangerButton(
                  label: _deletingAccount
                      ? 'Deleting account...'
                      : 'Delete Account',
                  onPressed: _deletingAccount ? null : _deleteAccount,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _section(
              title: 'App',
              children: [
                _infoRow(
                  icon: Icons.info_outline,
                  title: 'HalaPH',
                  subtitle: 'Account settings, permissions, and app controls.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.blue[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey[700], height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dangerButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.delete_forever),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
