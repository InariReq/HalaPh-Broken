import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:halaph/services/auth_service.dart';
import 'package:halaph/services/app_tutorial_service.dart';
import 'package:halaph/services/plan_notification_service.dart';
import 'package:halaph/services/simple_plan_service.dart';
import 'package:halaph/services/theme_mode_service.dart';
import 'package:halaph/screens/app_tutorial_screen.dart';
import 'package:halaph/widgets/motion_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = AuthService();
  bool _notificationsEnabled = false;
  bool _tutorialEnabledOnStart = true;
  bool _deletingAccount = false;
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadPlanReminderSetting();
    _loadTutorialSetting();
    _loadThemeModeSetting();
  }

  Future<void> _loadPlanReminderSetting() async {
    final enabled = await PlanNotificationService.arePlanRemindersEnabled();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = enabled;
    });
  }

  Future<void> _loadThemeModeSetting() async {
    setState(() {
      _themeMode = ThemeModeService.themeMode.value;
    });
  }

  Future<void> _loadTutorialSetting() async {
    final enabled = await AppTutorialService.isGuideModeEnabledOnStart();
    if (!mounted) return;
    setState(() {
      _tutorialEnabledOnStart = enabled;
    });
  }

  Future<void> _toggleTutorialOnStart(bool value) async {
    setState(() {
      _tutorialEnabledOnStart = value;
    });
    await AppTutorialService.setGuideModeEnabledOnStart(value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value
            ? 'Guide Mode will show every start'
            : 'Guide Mode will be skipped on start'),
      ),
    );
  }

  Future<void> _replayTutorial() async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: AppTutorialScreen(
              launchedFromSettings: true,
              onFinish: () => Navigator.of(context).pop(),
              onSkip: () => Navigator.of(context).pop(),
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return child;
        },
      ),
    );
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    await ThemeModeService.setThemeMode(mode);
    if (!mounted) return;
    setState(() {
      _themeMode = mode;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${ThemeModeService.labelFor(mode)} selected')),
    );
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
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your account, removes you from friends lists, removes friend requests, removes your public profile, and removes or leaves shared plans where needed. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              debugPrint('Delete account: first dialog cancelled');
              Navigator.of(dialogContext).pop(false);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Continue',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (firstConfirm != true) return;
    if (!mounted) return;

    final deleted = await _showDeletePasswordDialog();

    if (!mounted) return;

    if (deleted == true) {
      context.go('/accounts');
    }
  }

  Future<bool> _showDeletePasswordDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        var isDeleting = false;
        var enteredPassword = '';
        String? passwordError;

        Future<void> submit(StateSetter setDialogState) async {
          final password = enteredPassword.trim();

          if (password.isEmpty) {
            setDialogState(() {
              passwordError = 'Enter your password to delete this account.';
            });
            return;
          }

          debugPrint('Delete account: password submitted');

          setDialogState(() {
            isDeleting = true;
            passwordError = null;
          });

          if (mounted && !_deletingAccount) {
            setState(() {
              _deletingAccount = true;
            });
          }

          try {
            debugPrint('Delete account: cleanup/auth delete starting');
            final success = await _auth.deleteCurrentAccount(
              password: password,
            );

            if (!dialogContext.mounted) return;

            if (!success) {
              if (mounted) {
                setState(() {
                  _deletingAccount = false;
                });
              }

              setDialogState(() {
                isDeleting = false;
                passwordError = _deleteAccountErrorMessage(
                  _auth.lastAuthError,
                );
              });
              return;
            }

            Navigator.of(dialogContext).pop(true);
          } catch (error) {
            debugPrint('SettingsScreen: delete account failed: $error');

            if (mounted) {
              setState(() {
                _deletingAccount = false;
              });
            }

            if (!dialogContext.mounted) return;

            setDialogState(() {
              isDeleting = false;
              passwordError = _deleteAccountErrorMessage(error);
            });
          }
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canSubmit = enteredPassword.trim().isNotEmpty && !isDeleting;

            return AlertDialog(
              title: const Text('Confirm delete account'),
              content: TextField(
                enabled: !isDeleting,
                autofocus: true,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onChanged: (value) {
                  setDialogState(() {
                    enteredPassword = value;
                    passwordError = null;
                  });
                },
                onSubmitted: (_) {
                  if (!isDeleting) {
                    submit(setDialogState);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText:
                      'Enter your password to permanently delete this account.',
                  errorText: passwordError,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting
                      ? null
                      : () {
                          debugPrint(
                            'Delete account: password dialog cancelled',
                          );
                          Navigator.of(dialogContext).pop(false);
                        },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: canSubmit ? () => submit(setDialogState) : null,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  child: Text(
                    isDeleting ? 'Deleting...' : 'Delete Account',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (mounted && _deletingAccount && result != true) {
      setState(() {
        _deletingAccount = false;
      });
    }

    return result == true;
  }

  String _deleteAccountErrorMessage(Object? error) {
    final message = (error ?? '').toString().trim();
    final lower = message.toLowerCase();

    if (lower.contains('invalid-credential') ||
        lower.contains('wrong-password') ||
        lower.contains('password is incorrect') ||
        lower.contains('malformed or has expired')) {
      return 'Password is incorrect.';
    }

    if (lower.contains('requires-recent-login')) {
      return 'Please log in again before deleting your account.';
    }

    if (lower.contains('permission-denied') ||
        lower.contains('insufficient permissions')) {
      return 'Account cleanup is blocked by Firebase rules. Try again after rules are updated.';
    }

    if (lower.contains('network') ||
        lower.contains('timeout') ||
        lower.contains('connection')) {
      return 'Check your internet connection and try again.';
    }

    if (message.isNotEmpty &&
        !lower.contains('exception') &&
        !lower.contains('firebaseauthexception')) {
      return message;
    }

    return 'Could not delete account. Please try again.';
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _cardColor => _isDark ? const Color(0xFF111827) : Colors.white;

  Color get _softCardColor =>
      _isDark ? const Color(0xFF172033) : const Color(0xFFF3F8FF);

  Color get _borderColor =>
      _isDark ? const Color(0xFF263244) : const Color(0xFFE5EAF3);

  Color get _softBorderColor =>
      _isDark ? const Color(0xFF2B3A55) : const Color(0xFFD9E8FF);

  Color get _titleColor => _isDark ? Colors.white : const Color(0xFF111827);

  Color get _subtitleColor =>
      _isDark ? const Color(0xFFCBD5E1) : const Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final scaffoldColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
        backgroundColor: scaffoldColor,
        foregroundColor: _titleColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            SlideFadeIn(order: 0, child: _buildHeroCard()),
            const SizedBox(height: 18),
            SlideFadeIn(
              order: 1,
              child: _section(
                title: 'Appearance',
                icon: Icons.dark_mode_outlined,
                iconColor: const Color(0xFF1976D2),
                children: [
                  _themeOption(ThemeMode.system, Icons.phone_iphone_rounded),
                  const SizedBox(height: 10),
                  _themeOption(ThemeMode.light, Icons.light_mode_rounded),
                  const SizedBox(height: 10),
                  _themeOption(ThemeMode.dark, Icons.dark_mode_rounded),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SlideFadeIn(
              order: 2,
              child: _section(
                title: 'Permissions',
                icon: Icons.privacy_tip_outlined,
                iconColor: const Color(0xFF1976D2),
                children: [
                  _infoRow(
                    icon: Icons.location_on_outlined,
                    title: 'Location',
                    subtitle:
                        'Used to show nearby places and improve route planning. You can change this in iOS Settings.',
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: _borderColor),
                  const SizedBox(height: 12),
                  _infoRow(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    subtitle:
                        'Used for local plan reminders. Remote push notifications are separate.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SlideFadeIn(
              order: 3,
              child: _section(
                title: 'Plan Reminder',
                icon: Icons.alarm_rounded,
                iconColor: const Color(0xFF1976D2),
                children: [
                  _reminderToggle(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SlideFadeIn(
              order: 4,
              child: _section(
                title: 'Guide Mode',
                icon: Icons.school_outlined,
                iconColor: const Color(0xFF1976D2),
                children: [
                  _tutorialToggle(),
                  const SizedBox(height: 12),
                  _replayTutorialButton(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SlideFadeIn(
              order: 5,
              child: _section(
                title: 'Privacy and Account',
                icon: Icons.lock_outline_rounded,
                iconColor: Colors.red,
                children: [
                  _dangerButton(
                    label: _deletingAccount
                        ? 'Deleting account...'
                        : 'Delete Account',
                    onPressed: _deletingAccount ? null : _deleteAccount,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SlideFadeIn(
              order: 6,
              child: _section(
                title: 'App',
                icon: Icons.info_outline_rounded,
                iconColor: const Color(0xFF1976D2),
                children: [
                  _infoRow(
                    icon: Icons.directions_bus_filled_outlined,
                    title: 'HalaPH',
                    subtitle:
                        'Account settings, permissions, and app controls.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1976D2),
            Color(0xFF03A9F4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: _isDark ? 0.12 : 0.20),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final icon = Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.settings_rounded,
              color: Colors.white,
              size: 30,
            ),
          );

          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'App Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Manage reminders, appearance, permissions, and account controls.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );

          if (constraints.maxWidth < 310) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                icon,
                const SizedBox(height: 12),
                copy,
              ],
            );
          }

          return Row(
            children: [
              icon,
              const SizedBox(width: 14),
              Expanded(child: copy),
            ],
          );
        },
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.18 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: _isDark ? 0.16 : 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: _titleColor,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _themeOption(ThemeMode mode, IconData icon) {
    final selected = _themeMode == mode;

    return PressableCard(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _setThemeMode(mode),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color:
              selected ? Colors.blue.withValues(alpha: 0.12) : _softCardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFF1976D2) : _softBorderColor,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? Colors.blue[700] : _subtitleColor,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ThemeModeService.labelFor(mode),
                    style: TextStyle(
                      color: _titleColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    ThemeModeService.descriptionFor(mode),
                    style: TextStyle(
                      color: _subtitleColor,
                      fontSize: 12,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? Colors.blue[700] : Colors.transparent,
                border: Border.all(
                  color: selected ? Colors.blue[700]! : _softBorderColor,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
          ],
        ),
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
        Container(
          height: 36,
          width: 36,
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: _isDark ? 0.14 : 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.blue[700], size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: _titleColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: _subtitleColor,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reminderToggle() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _softCardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _softBorderColor),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: _isDark ? 0.14 : 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.notifications_active_outlined,
              color: Colors.blue[700],
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plan Reminder',
                  style: TextStyle(
                    color: _titleColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Notify 1 hour before the first stop and 30 minutes before each next stop.',
                  style: TextStyle(
                    color: _subtitleColor,
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch(
            value: _notificationsEnabled,
            onChanged: _toggleNotifications,
            activeThumbColor: Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _tutorialToggle() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _softCardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _softBorderColor),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: _isDark ? 0.14 : 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.route_rounded,
              color: Colors.blue[700],
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Show Guide Mode every start',
                  style: TextStyle(
                    color: _titleColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Shows Guide Mode after Start once your account is ready.',
                  style: TextStyle(
                    color: _subtitleColor,
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch(
            value: _tutorialEnabledOnStart,
            onChanged: _toggleTutorialOnStart,
            activeThumbColor: Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _replayTutorialButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _replayTutorial,
        icon: const Icon(Icons.replay_rounded),
        label: const Text(
          'Replay Guide Mode',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.blue[700],
          side: BorderSide(color: Colors.blue.withValues(alpha: 0.45)),
          backgroundColor: Colors.blue.withValues(alpha: _isDark ? 0.10 : 0.04),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
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
        icon: const Icon(Icons.delete_forever_rounded),
        label: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: BorderSide(color: Colors.red.withValues(alpha: 0.45)),
          backgroundColor: Colors.red.withValues(alpha: _isDark ? 0.10 : 0.04),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}
