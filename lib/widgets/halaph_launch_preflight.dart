import 'dart:async';
import 'dart:math' as math;

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
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _ambientController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _logoSlide;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;

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

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat();

    _logoScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.70, end: 1.10)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 62,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.10, end: 1.00)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 38,
      ),
    ]).animate(_introController);

    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0, 0.58, curve: Curves.easeOut),
      ),
    );

    _logoSlide = Tween<Offset>(
      begin: const Offset(0, 0.16),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0, 0.70, curve: Curves.easeOutCubic),
      ),
    );

    _contentFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.38, 1, curve: Curves.easeOut),
      ),
    );

    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.38, 1, curve: Curves.easeOutCubic),
      ),
    );

    _introController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _animationComplete = true);
      }
    });

    unawaited(_introController.forward());
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
    _introController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _ambientController,
        builder: (context, child) {
          final t = _ambientController.value * math.pi * 2;

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [
                        Color(0xFF07111F),
                        Color(0xFF10243D),
                        Color(0xFF07111F),
                      ]
                    : const [
                        Color(0xFFEFF6FF),
                        Color(0xFFFFFFFF),
                        Color(0xFFEAF2FF),
                      ],
              ),
            ),
            child: Stack(
              children: [
                _FloatingGlow(
                  alignment: Alignment(-0.90 + math.sin(t) * 0.08, -0.82),
                  size: 210,
                  color: colorScheme.primary.withValues(alpha: 0.16),
                ),
                _FloatingGlow(
                  alignment: Alignment(0.90, -0.10 + math.cos(t) * 0.10),
                  size: 170,
                  color: colorScheme.secondary.withValues(alpha: 0.12),
                ),
                _FloatingGlow(
                  alignment: Alignment(-0.70, 0.86 + math.sin(t) * 0.05),
                  size: 150,
                  color: colorScheme.primary.withValues(alpha: 0.10),
                ),
                SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 28,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SlideTransition(
                              position: _logoSlide,
                              child: FadeTransition(
                                opacity: _logoFade,
                                child: ScaleTransition(
                                  scale: _logoScale,
                                  child: _LogoOrb(
                                    colorScheme: colorScheme,
                                    pulse: (math.sin(t) + 1) / 2,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            FadeTransition(
                              opacity: _contentFade,
                              child: SlideTransition(
                                position: _contentSlide,
                                child: Column(
                                  children: [
                                    Text(
                                      'Welcome to HalaPH',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "We'll prepare your trip tools first.",
                                      textAlign: TextAlign.center,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 26),
                                    AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 420),
                                      curve: Curves.easeOutCubic,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: colorScheme.surface
                                            .withValues(alpha: 0.86),
                                        borderRadius: BorderRadius.circular(26),
                                        border: Border.all(
                                          color: colorScheme.outlineVariant
                                              .withValues(alpha: 0.36),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.10),
                                            blurRadius: 24,
                                            offset: const Offset(0, 12),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        children: [
                                          _AnimatedStatusRow(
                                            delay:
                                                const Duration(milliseconds: 0),
                                            icon: _animationComplete
                                                ? Icons.check_circle_rounded
                                                : Icons.auto_awesome_rounded,
                                            iconColor: _animationComplete
                                                ? Colors.green[700]!
                                                : colorScheme.primary,
                                            text: _animationComplete
                                                ? 'Logo animation ready'
                                                : 'Playing launch animation...',
                                          ),
                                          const SizedBox(height: 10),
                                          _AnimatedStatusRow(
                                            delay: const Duration(
                                              milliseconds: 100,
                                            ),
                                            icon: _notificationsReady
                                                ? Icons.check_circle_rounded
                                                : Icons.info_rounded,
                                            iconColor: _notificationsReady
                                                ? Colors.green[700]!
                                                : Colors.orange[700]!,
                                            text: _notificationMessage,
                                          ),
                                          const SizedBox(height: 10),
                                          _AnimatedStatusRow(
                                            delay: const Duration(
                                              milliseconds: 200,
                                            ),
                                            icon: _locationReady
                                                ? Icons.check_circle_rounded
                                                : Icons.info_rounded,
                                            iconColor: _locationReady
                                                ? Colors.green[700]!
                                                : Colors.orange[700]!,
                                            text: _locationMessage,
                                          ),
                                          const SizedBox(height: 10),
                                          _AnimatedStatusRow(
                                            delay: const Duration(
                                              milliseconds: 300,
                                            ),
                                            icon: _accountChecked
                                                ? Icons.check_circle_rounded
                                                : Icons.hourglass_top_rounded,
                                            iconColor: _accountChecked
                                                ? Colors.green[700]!
                                                : colorScheme.primary,
                                            text: _accountMessage,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 340),
                                      switchInCurve: Curves.easeOutBack,
                                      switchOutCurve: Curves.easeInCubic,
                                      child: _canStart
                                          ? ScaleTransition(
                                              key: const ValueKey(
                                                'start-ready',
                                              ),
                                              scale: CurvedAnimation(
                                                parent: _ambientController,
                                                curve: Curves.easeInOut,
                                              ).drive(
                                                Tween<double>(
                                                  begin: 0.98,
                                                  end: 1.02,
                                                ),
                                              ),
                                              child: ElevatedButton.icon(
                                                onPressed: widget.onStart,
                                                icon: const Icon(
                                                  Icons.arrow_forward_rounded,
                                                ),
                                                label: const Text('Start'),
                                                style: ElevatedButton.styleFrom(
                                                  minimumSize:
                                                      const Size(170, 52),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      18,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            )
                                          : _PreparingPill(
                                              key: const ValueKey(
                                                'start-waiting',
                                              ),
                                              colorScheme: colorScheme,
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LogoOrb extends StatelessWidget {
  final ColorScheme colorScheme;
  final double pulse;

  const _LogoOrb({
    required this.colorScheme,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      height: 132,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            colorScheme.primary.withValues(alpha: 0.18 + pulse * 0.08),
            colorScheme.primary.withValues(alpha: 0.04),
            Colors.transparent,
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.22),
              blurRadius: 26 + pulse * 10,
              spreadRadius: 1 + pulse * 2,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Image.asset(
            'assets/icons/app_icon.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.explore_rounded,
                color: colorScheme.primary,
                size: 66,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FloatingGlow extends StatelessWidget {
  final Alignment alignment;
  final double size;
  final Color color;

  const _FloatingGlow({
    required this.alignment,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _AnimatedStatusRow extends StatefulWidget {
  final Duration delay;
  final IconData icon;
  final Color iconColor;
  final String text;

  const _AnimatedStatusRow({
    required this.delay,
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  @override
  State<_AnimatedStatusRow> createState() => _AnimatedStatusRowState();
}

class _AnimatedStatusRowState extends State<_AnimatedStatusRow> {
  bool _visible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (!mounted) return;
      setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOut,
      opacity: _visible ? 1 : 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        offset: _visible ? Offset.zero : const Offset(0.08, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: Icon(
                widget.icon,
                key: ValueKey('${widget.icon.codePoint}-${widget.text}'),
                size: 22,
                color: widget.iconColor,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                widget.text,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreparingPill extends StatelessWidget {
  final ColorScheme colorScheme;

  const _PreparingPill({
    super.key,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.34),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Preparing launch...',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
