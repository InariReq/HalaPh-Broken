import 'package:flutter/material.dart';

import '../services/app_tutorial_service.dart';

class AppTutorialScreen extends StatefulWidget {
  final bool launchedFromSettings;
  final VoidCallback onFinish;
  final VoidCallback onSkip;

  const AppTutorialScreen({
    super.key,
    required this.launchedFromSettings,
    required this.onFinish,
    required this.onSkip,
  });

  @override
  State<AppTutorialScreen> createState() => _AppTutorialScreenState();
}

class _AppTutorialScreenState extends State<AppTutorialScreen> {
  int _index = 0;
  bool _closing = false;

  bool get _isFirst => _index == 0;
  bool get _isLast => _index == _steps.length - 1;

  Future<void> _close({required bool skipped}) async {
    if (_closing) return;
    setState(() => _closing = true);
    await AppTutorialService.setTutorialCompleted(true);
    if (!mounted) return;
    if (skipped) {
      widget.onSkip();
    } else {
      widget.onFinish();
    }
  }

  void _next() {
    if (_isLast) {
      _close(skipped: false);
      return;
    }
    setState(() => _index += 1);
  }

  void _back() {
    if (_isFirst) return;
    setState(() => _index -= 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final step = _steps[_index];

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 6),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/icons/app_icon.png',
                      width: 34,
                      height: 34,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.explore_rounded,
                          color: colorScheme.primary,
                          size: 34,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'HalaPH guide',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _closing ? null : () => _close(skipped: true),
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: LinearProgressIndicator(
                value: (_index + 1) / _steps.length,
                minHeight: 6,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TutorialVisual(step: step),
                      const SizedBox(height: 28),
                      Text(
                        '${_index + 1} of ${_steps.length}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Column(
                          key: ValueKey(step.title),
                          children: [
                            Text(
                              step.title,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              step.body,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                height: 1.38,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isFirst || _closing ? null : _back,
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _closing ? null : _next,
                      child: Text(_isLast ? 'Finish' : 'Next'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorialVisual extends StatelessWidget {
  final _TutorialStep step;

  const _TutorialVisual({required this.step});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 210,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: CustomPaint(
              painter: _TutorialRoutePainter(
                color: colorScheme.primary,
                muted: colorScheme.outlineVariant,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(step.icon, color: colorScheme.primary, size: 42),
            ),
          ),
        ],
      ),
    );
  }
}

class _TutorialRoutePainter extends CustomPainter {
  final Color color;
  final Color muted;

  const _TutorialRoutePainter({
    required this.color,
    required this.muted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.70)
      ..quadraticBezierTo(
        size.width * 0.30,
        size.height * 0.24,
        size.width * 0.50,
        size.height * 0.56,
      )
      ..quadraticBezierTo(
        size.width * 0.70,
        size.height * 0.86,
        size.width * 0.92,
        size.height * 0.30,
      );

    canvas.drawPath(
      path,
      Paint()
        ..color = muted
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );

    final metric = path.computeMetrics().first;
    for (final point in [0.0, 0.36, 0.68, 1.0]) {
      final tangent = metric.getTangentForOffset(metric.length * point);
      if (tangent == null) continue;
      canvas.drawCircle(tangent.position, 10, Paint()..color = Colors.white);
      canvas.drawCircle(tangent.position, 6, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _TutorialRoutePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.muted != muted;
  }
}

class _TutorialStep {
  final String title;
  final String body;
  final IconData icon;

  const _TutorialStep({
    required this.title,
    required this.body,
    required this.icon,
  });
}

const _steps = [
  _TutorialStep(
    title: 'Welcome to HalaPH',
    body: 'HalaPH helps you plan Philippine commute routes, fares, and trips.',
    icon: Icons.waving_hand_rounded,
  ),
  _TutorialStep(
    title: 'Explore',
    body: 'Search destinations and browse places before choosing where to go.',
    icon: Icons.explore_rounded,
  ),
  _TutorialStep(
    title: 'Route Options',
    body:
        'Compare commute options with route titles, travel modes, and estimated fares.',
    icon: Icons.alt_route_rounded,
  ),
  _TutorialStep(
    title: 'Step-by-step Route Guide',
    body:
        'Follow boarding, alighting, walking steps, route details, and map guidance.',
    icon: Icons.directions_rounded,
  ),
  _TutorialStep(
    title: 'Fare Estimates',
    body:
        'Review fare estimates, budget views, and passenger-type fare support.',
    icon: Icons.payments_rounded,
  ),
  _TutorialStep(
    title: 'Favorites',
    body:
        'Save destinations with the heart button so you can find them again quickly.',
    icon: Icons.favorite_rounded,
  ),
  _TutorialStep(
    title: 'Trip Plans',
    body:
        'Create plans, add destinations, set dates, and estimate your trip budget.',
    icon: Icons.event_note_rounded,
  ),
  _TutorialStep(
    title: 'Collaboration',
    body:
        'Add friends, share plans, set participant start locations, and plan together.',
    icon: Icons.groups_rounded,
  ),
  _TutorialStep(
    title: 'Reminders',
    body:
        'Turn on plan reminders to get local notifications before trip stops.',
    icon: Icons.notifications_active_rounded,
  ),
  _TutorialStep(
    title: 'Trip History',
    body: 'Review finished plans and past trips when you need them later.',
    icon: Icons.history_rounded,
  ),
  _TutorialStep(
    title: 'Settings and Account',
    body:
        'Manage your profile, account options, app settings, and replay this tutorial.',
    icon: Icons.manage_accounts_rounded,
  ),
];
