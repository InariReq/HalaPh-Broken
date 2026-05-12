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
  late final AnimationController _routeController;
  late final Animation<double> _logoScale;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;

  bool _animationComplete = false;
  bool _checksComplete = false;
  bool _accountChecked = false;
  bool _notificationsReady = false;
  bool _locationReady = false;

  String _notificationMessage = 'Checking notifications';
  String _locationMessage = 'Checking location';
  String _accountMessage = 'Checking account session';

  bool get _canStart => _animationComplete && _checksComplete;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );
    _routeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();

    _logoScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.86, end: 1.06)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 58,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.06, end: 1)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 42,
      ),
    ]).animate(_introController);

    _contentFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.24, 1, curve: Curves.easeOut),
      ),
    );
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.10),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.24, 1, curve: Curves.easeOutCubic),
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
          if (_notificationMessage == 'Checking notifications') {
            _notificationMessage = 'Notifications checked';
          }
          if (_locationMessage == 'Checking location') {
            _locationMessage = 'Location checked';
          }
          _accountMessage = 'Checking account session';
          _accountChecked = true;
        });
        return <void>[];
      },
    );

    if (!mounted) return;
    setState(() {
      _checksComplete = true;
      _accountChecked = true;
      if (_notificationMessage == 'Checking notifications') {
        _notificationMessage = 'Notifications checked';
      }
      if (_locationMessage == 'Checking location') {
        _locationMessage = 'Location checked';
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
            ? 'Notifications checked'
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
            ? 'Location checked'
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
      _accountMessage = 'Checking account session';
    });
  }

  @override
  void dispose() {
    _introController.dispose();
    _routeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF08111F) : const Color(0xFFF7FBFF),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _routeController,
          builder: (context, child) {
            return Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 210,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(
                              child: _RouteMotionMap(
                                progress: _routeController.value,
                                colorScheme: colorScheme,
                                isDark: isDark,
                              ),
                            ),
                            ScaleTransition(
                              scale: _logoScale,
                              child: _LogoCard(colorScheme: colorScheme),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      FadeTransition(
                        opacity: _contentFade,
                        child: SlideTransition(
                          position: _contentSlide,
                          child: Column(
                            children: [
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
                                'Plan routes, fares, and trips before you go.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 24),
                              _StatusPanel(
                                colorScheme: colorScheme,
                                children: [
                                  _StatusRow(
                                    icon: _animationComplete
                                        ? Icons.check_circle_rounded
                                        : Icons.route_rounded,
                                    iconColor: _animationComplete
                                        ? Colors.green[700]!
                                        : colorScheme.primary,
                                    label: 'Preparing route guide',
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
                                ],
                              ),
                              const SizedBox(height: 24),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 260),
                                switchInCurve: Curves.easeOutBack,
                                child: _canStart
                                    ? SizedBox(
                                        key: const ValueKey('start-ready'),
                                        width: double.infinity,
                                        child: FilledButton.icon(
                                          onPressed: widget.onStart,
                                          icon: const Icon(
                                            Icons.arrow_forward_rounded,
                                          ),
                                          label: const Text('Start'),
                                        ),
                                      )
                                    : _PreparingPill(
                                        key: const ValueKey('start-waiting'),
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
            );
          },
        ),
      ),
    );
  }
}

class _LogoCard extends StatelessWidget {
  final ColorScheme colorScheme;

  const _LogoCard({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.13),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
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
    );
  }
}

class _RouteMotionMap extends StatelessWidget {
  final double progress;
  final ColorScheme colorScheme;
  final bool isDark;

  const _RouteMotionMap({
    required this.progress,
    required this.colorScheme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RouteMotionPainter(
        progress: progress,
        primary: colorScheme.primary,
        secondary: colorScheme.secondary,
        surface: isDark ? const Color(0xFF101B2B) : Colors.white,
        lineBase: isDark ? const Color(0xFF2B3A55) : const Color(0xFFD6E8FF),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _RouteMotionPainter extends CustomPainter {
  final double progress;
  final Color primary;
  final Color secondary;
  final Color surface;
  final Color lineBase;

  const _RouteMotionPainter({
    required this.progress,
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.lineBase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final route = Path()
      ..moveTo(size.width * 0.10, size.height * 0.72)
      ..cubicTo(
        size.width * 0.23,
        size.height * 0.36,
        size.width * 0.36,
        size.height * 0.86,
        size.width * 0.50,
        size.height * 0.52,
      )
      ..cubicTo(
        size.width * 0.64,
        size.height * 0.20,
        size.width * 0.76,
        size.height * 0.74,
        size.width * 0.90,
        size.height * 0.34,
      );

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(route.shift(const Offset(0, 8)), shadowPaint);

    final basePaint = Paint()
      ..color = lineBase
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(route, basePaint);

    final metric = route.computeMetrics().first;
    final activeLength = metric.length * progress;
    final activePath = metric.extractPath(0, activeLength);
    final activePaint = Paint()
      ..shader = LinearGradient(colors: [primary, secondary]).createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(activePath, activePaint);

    final waypoints = const [0.0, 0.32, 0.62, 1.0];
    for (var i = 0; i < waypoints.length; i++) {
      final tangent = metric.getTangentForOffset(metric.length * waypoints[i]);
      if (tangent == null) continue;
      final localPulse = (math.sin((progress * 2 * math.pi) + i * 1.1) + 1) / 2;
      final reached = progress >= waypoints[i] || progress < 0.05 && i == 0;
      final dotPaint = Paint()
        ..color = reached ? primary : surface
        ..style = PaintingStyle.fill;
      final ringPaint = Paint()
        ..color = reached
            ? primary.withValues(alpha: 0.18 + localPulse * 0.14)
            : lineBase
        ..style = PaintingStyle.fill;
      canvas.drawCircle(tangent.position, 13 + localPulse * 3, ringPaint);
      canvas.drawCircle(tangent.position, 7, dotPaint);
      canvas.drawCircle(
        tangent.position,
        7,
        Paint()
          ..color = reached ? Colors.white : lineBase
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    final vehicleTangent =
        metric.getTangentForOffset(metric.length * ((progress + 0.03) % 1));
    if (vehicleTangent != null) {
      _drawVehicle(canvas, vehicleTangent.position, vehicleTangent.angle);
    }
  }

  void _drawVehicle(Canvas canvas, Offset center, double angle) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 30, height: 18),
      const Radius.circular(7),
    );
    canvas.drawRRect(
      body.shift(const Offset(0, 2)),
      Paint()..color = Colors.black.withValues(alpha: 0.12),
    );
    canvas.drawRRect(body, Paint()..color = secondary);
    canvas.drawRect(
      const Rect.fromLTWH(-8, -6, 8, 5),
      Paint()..color = Colors.white.withValues(alpha: 0.82),
    );
    canvas.drawRect(
      const Rect.fromLTWH(2, -6, 8, 5),
      Paint()..color = Colors.white.withValues(alpha: 0.82),
    );
    canvas.drawCircle(
        const Offset(-9, 8), 2.5, Paint()..color = Colors.black87);
    canvas.drawCircle(const Offset(9, 8), 2.5, Paint()..color = Colors.black87);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RouteMotionPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary ||
        oldDelegate.surface != surface ||
        oldDelegate.lineBase != lineBase;
  }
}

class _StatusPanel extends StatelessWidget {
  final ColorScheme colorScheme;
  final List<Widget> children;

  const _StatusPanel({
    required this.colorScheme,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const SizedBox(height: 10),
          ],
        ],
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
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Icon(
            icon,
            key: ValueKey('${icon.codePoint}-$label'),
            color: iconColor,
            size: 22,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
        ),
      ],
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
        color: colorScheme.surface.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.42),
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
            'Preparing route guide...',
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
