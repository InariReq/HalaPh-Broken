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
      if (_notificationMessage == 'Checking notifications') {
        _notificationMessage = 'Notifications checked';
      }
      if (_locationMessage == 'Checking location') {
        _locationMessage = 'Location checked';
      }
      _accountMessage = 'Account session checked';
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
      _accountMessage = 'Account session checked';
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
          animation: Listenable.merge([_introController, _routeController]),
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
                      _LaunchRouteBoard(
                        introProgress: _introController.value,
                        routeProgress: _routeController.value,
                        logoScale: _logoScale,
                        colorScheme: colorScheme,
                        isDark: isDark,
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
                                    label: _animationComplete
                                        ? 'Route guide ready'
                                        : 'Preparing route guide',
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
                                transitionBuilder: (child, animation) {
                                  final offset = Tween<Offset>(
                                    begin: const Offset(0, 0.14),
                                    end: Offset.zero,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeOutCubic,
                                    ),
                                  );
                                  final scale = Tween<double>(
                                    begin: 0.96,
                                    end: 1,
                                  ).animate(animation);
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: offset,
                                      child: ScaleTransition(
                                        scale: scale,
                                        child: child,
                                      ),
                                    ),
                                  );
                                },
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
  final double size;

  const _LogoCard({
    required this.colorScheme,
    this.size = 110,
  });

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.25;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.11),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(radius),
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
        borderRadius: BorderRadius.circular(size * 0.18),
        child: Image.asset(
          'assets/icons/app_icon.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.explore_rounded,
              color: colorScheme.primary,
              size: size * 0.52,
            );
          },
        ),
      ),
    );
  }
}

class _LaunchRouteBoard extends StatelessWidget {
  final double introProgress;
  final double routeProgress;
  final Animation<double> logoScale;
  final ColorScheme colorScheme;
  final bool isDark;

  const _LaunchRouteBoard({
    required this.introProgress,
    required this.routeProgress,
    required this.logoScale,
    required this.colorScheme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final routeDraw = _phase(introProgress, 0.20, 0.72);
    final pinsIn = _phase(introProgress, 0.08, 0.36);
    final chipsIn = _phase(introProgress, 0.48, 0.86);
    final cardsIn = _phase(introProgress, 0.62, 1);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: isDark ? 0.88 : 0.96),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.10),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ScaleTransition(
                scale: logoScale,
                child: _LogoCard(colorScheme: colorScheme, size: 60),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Commute preflight',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Route, fare, and trip tools are getting ready.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              _BoardBadge(
                colorScheme: colorScheme,
                progress: routeDraw,
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 145,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _RouteBoardPainter(
                          drawProgress: routeDraw,
                          pulseProgress: routeProgress,
                          primary: colorScheme.primary,
                          secondary: colorScheme.secondary,
                          surface:
                              isDark ? const Color(0xFF101B2B) : Colors.white,
                          lineBase: isDark
                              ? const Color(0xFF2B3A55)
                              : const Color(0xFFD6E8FF),
                        ),
                      ),
                    ),
                    _BoardPin(
                      left: size.width * 0.05,
                      top: size.height * 0.63,
                      progress: pinsIn,
                      icon: Icons.location_on_rounded,
                      label: 'Origin',
                      color: colorScheme.primary,
                    ),
                    _BoardPin(
                      left: size.width * 0.73,
                      top: size.height * 0.08,
                      progress: _phase(introProgress, 0.18, 0.42),
                      icon: Icons.flag_rounded,
                      label: 'Destination',
                      color: colorScheme.tertiary,
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _ModePrepChip(
                icon: Icons.directions_walk_rounded,
                label: 'Walk',
                progress: chipsIn,
                color: colorScheme.primary,
              ),
              _ModePrepChip(
                icon: Icons.directions_bus_filled_rounded,
                label: 'Jeepney',
                progress: _phase(introProgress, 0.54, 0.88),
                color: colorScheme.secondary,
              ),
              _ModePrepChip(
                icon: Icons.train_rounded,
                label: 'Train',
                progress: _phase(introProgress, 0.60, 0.92),
                color: colorScheme.tertiary,
              ),
              _ModePrepChip(
                icon: Icons.payments_rounded,
                label: 'Fare',
                progress: _phase(introProgress, 0.66, 0.96),
                color: Colors.green[700]!,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ReadyPreviewCard(
                  icon: Icons.alt_route_rounded,
                  label: 'Route guide',
                  progress: cardsIn,
                  colorScheme: colorScheme,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ReadyPreviewCard(
                  icon: Icons.local_atm_rounded,
                  label: 'Fare tools',
                  progress: _phase(introProgress, 0.68, 1),
                  colorScheme: colorScheme,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ReadyPreviewCard(
                  icon: Icons.event_available_rounded,
                  label: 'Plans',
                  progress: _phase(introProgress, 0.74, 1),
                  colorScheme: colorScheme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BoardBadge extends StatelessWidget {
  final ColorScheme colorScheme;
  final double progress;

  const _BoardBadge({
    required this.colorScheme,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final ready = progress >= 0.98;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: (ready ? Colors.green : colorScheme.primary)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: (ready ? Colors.green : colorScheme.primary)
              .withValues(alpha: 0.25),
        ),
      ),
      child: Icon(
        ready ? Icons.check_rounded : Icons.route_rounded,
        size: 18,
        color: ready ? Colors.green[700] : colorScheme.primary,
      ),
    );
  }
}

class _BoardPin extends StatelessWidget {
  final double left;
  final double top;
  final double progress;
  final IconData icon;
  final String label;
  final Color color;

  const _BoardPin({
    required this.left,
    required this.top,
    required this.progress,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final clamped = progress.clamp(0.0, 1.0);
    return Positioned(
      left: left,
      top: top - (1 - clamped) * 8,
      child: Opacity(
        opacity: clamped,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 17),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModePrepChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final double progress;
  final Color color;

  const _ModePrepChip({
    required this.icon,
    required this.label,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final clamped = progress.clamp(0.0, 1.0);
    return Opacity(
      opacity: clamped,
      child: Transform.translate(
        offset: Offset(0, (1 - clamped) * 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadyPreviewCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final double progress;
  final ColorScheme colorScheme;

  const _ReadyPreviewCard({
    required this.icon,
    required this.label,
    required this.progress,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    return Opacity(
      opacity: clamped,
      child: Transform.translate(
        offset: Offset(0, (1 - clamped) * 10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: colorScheme.primary),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteBoardPainter extends CustomPainter {
  final double drawProgress;
  final double pulseProgress;
  final Color primary;
  final Color secondary;
  final Color surface;
  final Color lineBase;

  const _RouteBoardPainter({
    required this.drawProgress,
    required this.pulseProgress,
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.lineBase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final panel = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(22),
    );
    canvas.drawRRect(
      panel,
      Paint()..color = surface.withValues(alpha: 0.62),
    );

    final gridPaint = Paint()
      ..color = lineBase.withValues(alpha: 0.32)
      ..strokeWidth = 1;
    for (var x = size.width * 0.12; x < size.width; x += size.width * 0.18) {
      canvas.drawLine(Offset(x, 10), Offset(x, size.height - 10), gridPaint);
    }
    for (var y = size.height * 0.18; y < size.height; y += size.height * 0.24) {
      canvas.drawLine(Offset(10, y), Offset(size.width - 10, y), gridPaint);
    }

    final route = Path()
      ..moveTo(size.width * 0.15, size.height * 0.74)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.42,
        size.width * 0.40,
        size.height * 0.86,
        size.width * 0.53,
        size.height * 0.55,
      )
      ..cubicTo(
        size.width * 0.64,
        size.height * 0.30,
        size.width * 0.73,
        size.height * 0.28,
        size.width * 0.86,
        size.height * 0.20,
      );

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(route.shift(const Offset(0, 8)), shadowPaint);

    final basePaint = Paint()
      ..color = lineBase
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(route, basePaint);

    final metric = route.computeMetrics().first;
    final activeLength = metric.length * drawProgress.clamp(0.0, 1.0);
    final activePath = metric.extractPath(0, activeLength);
    final activePaint = Paint()
      ..shader = LinearGradient(colors: [primary, secondary]).createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(activePath, activePaint);

    final waypoints = const [0.0, 0.30, 0.55, 0.76, 1.0];
    for (var i = 0; i < waypoints.length; i++) {
      final tangent = metric.getTangentForOffset(metric.length * waypoints[i]);
      if (tangent == null) continue;
      final localPulse =
          (math.sin((pulseProgress * 2 * math.pi) - i * 1.05) + 1) / 2;
      final reached = drawProgress >= waypoints[i] || i == 0;
      final dotPaint = Paint()
        ..color = reached ? primary : surface.withValues(alpha: 0.95)
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

    final markerProgress = drawProgress < 0.98
        ? drawProgress.clamp(0.06, 0.94)
        : (0.08 + pulseProgress * 0.84) % 1.0;
    final vehicleTangent =
        metric.getTangentForOffset(metric.length * markerProgress);
    if (vehicleTangent != null) {
      _drawVehicle(canvas, vehicleTangent.position, vehicleTangent.angle);
    }
  }

  void _drawVehicle(Canvas canvas, Offset center, double angle) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 34, height: 20),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      body.shift(const Offset(0, 2)),
      Paint()..color = Colors.black.withValues(alpha: 0.12),
    );
    canvas.drawRRect(body, Paint()..color = secondary);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-15, -11, 30, 6),
        const Radius.circular(4),
      ),
      Paint()..color = primary,
    );
    canvas.drawRect(
      const Rect.fromLTWH(-10, -6, 7, 5),
      Paint()..color = Colors.white.withValues(alpha: 0.82),
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, -6, 7, 5),
      Paint()..color = Colors.white.withValues(alpha: 0.82),
    );
    canvas.drawRect(
      const Rect.fromLTWH(9, -6, 5, 5),
      Paint()..color = Colors.white.withValues(alpha: 0.82),
    );
    canvas.drawCircle(
        const Offset(-10, 9), 2.7, Paint()..color = Colors.black87);
    canvas.drawCircle(
        const Offset(10, 9), 2.7, Paint()..color = Colors.black87);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RouteBoardPainter oldDelegate) {
    return oldDelegate.drawProgress != drawProgress ||
        oldDelegate.pulseProgress != pulseProgress ||
        oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary ||
        oldDelegate.surface != surface ||
        oldDelegate.lineBase != lineBase;
  }
}

double _phase(double value, double start, double end) {
  if (value <= start) return 0;
  if (value >= end) return 1;
  return Curves.easeOutCubic.transform((value - start) / (end - start));
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
