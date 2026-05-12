import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/plan_notification_service.dart';

class HalaPhLaunchPreflight extends StatefulWidget {
  final VoidCallback onStart;

  const HalaPhLaunchPreflight({
    super.key,
    required this.onStart,
  });

  @override
  State<HalaPhLaunchPreflight> createState() => _HalaPhLaunchPreflightState();
}

class _HalaPhLaunchPreflightState extends State<HalaPhLaunchPreflight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  bool _animationComplete = false;
  bool _checksComplete = false;
  bool _accountChecked = false;
  bool _notificationsReady = false;
  bool _locationReady = false;

  String _notificationMessage = 'Checking notifications...';
  String _locationMessage = 'Checking location...';
  String _accountMessage = 'Checking account session...';

  bool get _canStart => _animationComplete && _checksComplete;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.82, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 1)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 45,
      ),
    ]).animate(_controller);

    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _animationComplete = true;
        });
      }
    });

    unawaited(_controller.forward());
    unawaited(_runChecks());
  }

  Future<void> _runChecks() async {
    await Future.wait<void>([
      _checkNotifications(),
      _checkLocation(),
      _checkAccountSession(),
    ]).timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        if (!mounted) return <void>[];
        setState(() {
          _notificationMessage = _notificationsReady
              ? _notificationMessage
              : 'Notifications checked';
          _locationMessage =
              _locationReady ? _locationMessage : 'Location checked';
          _accountMessage = 'Account session checked';
          _accountChecked = true;
        });
        return <void>[];
      },
    );

    if (!mounted) return;
    setState(() {
      _checksComplete = true;
      _accountChecked = true;
      if (_notificationMessage.startsWith('Checking')) {
        _notificationMessage = 'Notifications checked';
      }
      if (_locationMessage.startsWith('Checking')) {
        _locationMessage = 'Location checked';
      }
      if (_accountMessage.startsWith('Checking')) {
        _accountMessage = 'Account session checked';
      }
    });
  }

  Future<void> _checkNotifications() async {
    try {
      await PlanNotificationService.initialize()
          .timeout(const Duration(milliseconds: 900));
      final remindersEnabled =
          await PlanNotificationService.arePlanRemindersEnabled()
              .timeout(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() {
        _notificationsReady = remindersEnabled;
        _notificationMessage = remindersEnabled
            ? 'Notifications ready'
            : 'Notifications not enabled. You can turn them on later.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notificationsReady = false;
        _notificationMessage =
            'Notifications will be requested when reminders are enabled.';
      });
    }
  }

  Future<void> _checkLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled()
          .timeout(const Duration(milliseconds: 900));
      final permission = await Geolocator.checkPermission()
          .timeout(const Duration(milliseconds: 900));
      final ready = serviceEnabled &&
          (permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse);

      if (!mounted) return;
      setState(() {
        _locationReady = ready;
        _locationMessage = ready
            ? 'Location ready'
            : 'Location not enabled. You can continue and allow it later.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationReady = false;
        _locationMessage = 'Location will be requested when needed.';
      });
    }
  }

  Future<void> _checkAccountSession() async {
    try {
      firebase_auth.FirebaseAuth.instance.currentUser;
    } catch (_) {
      // AuthWrapper owns the real auth flow after Start.
    }

    if (!mounted) return;
    setState(() {
      _accountChecked = true;
      _accountMessage = 'Account session checked';
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: _fade,
                    child: ScaleTransition(
                      scale: _scale,
                      child: Container(
                        width: 112,
                        height: 112,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.14),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset(
                            'assets/icons/app_icon.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.explore_rounded,
                                color: colorScheme.primary,
                                size: 58,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Welcome to HalaPH',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "We'll prepare your trip tools first.",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _StatusRow(
                    icon: _animationComplete
                        ? Icons.check_circle_rounded
                        : Icons.hourglass_top_rounded,
                    iconColor: _animationComplete
                        ? Colors.green[700]!
                        : colorScheme.primary,
                    label: _animationComplete
                        ? 'Logo animation ready'
                        : 'Playing logo animation...',
                  ),
                  _StatusRow(
                    icon: _notificationsReady
                        ? Icons.check_circle_rounded
                        : Icons.info_rounded,
                    iconColor: _notificationsReady
                        ? Colors.green[700]!
                        : Colors.orange[700]!,
                    label: _notificationMessage,
                  ),
                  _StatusRow(
                    icon: _locationReady
                        ? Icons.check_circle_rounded
                        : Icons.info_rounded,
                    iconColor: _locationReady
                        ? Colors.green[700]!
                        : Colors.orange[700]!,
                    label: _locationMessage,
                  ),
                  _StatusRow(
                    icon: _accountChecked
                        ? Icons.check_circle_rounded
                        : Icons.hourglass_top_rounded,
                    iconColor: _accountChecked
                        ? Colors.green[700]!
                        : colorScheme.primary,
                    label: _accountMessage,
                  ),
                  const SizedBox(height: 28),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _canStart
                        ? SizedBox(
                            key: const ValueKey('start-button'),
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: widget.onStart,
                              child: const Text('Start'),
                            ),
                          )
                        : const SizedBox(
                            key: ValueKey('start-placeholder'),
                            height: 48,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;

  const _StatusRow({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
