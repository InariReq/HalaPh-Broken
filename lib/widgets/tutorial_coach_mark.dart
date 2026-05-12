import 'package:flutter/material.dart';

class TutorialCoachStep {
  final String title;
  final String body;
  final IconData icon;
  final GlobalKey? targetKey;
  final Rect? targetRect;

  const TutorialCoachStep({
    required this.title,
    required this.body,
    required this.icon,
    this.targetKey,
    this.targetRect,
  });
}

class TutorialCoachMark extends StatelessWidget {
  final TutorialCoachStep step;
  final int stepIndex;
  final int totalSteps;
  final bool isFirst;
  final bool isLast;
  final bool isBusy;
  final VoidCallback onSkip;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  const TutorialCoachMark({
    super.key,
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.isFirst,
    required this.isLast,
    required this.isBusy,
    required this.onSkip,
    required this.onBack,
    required this.onNext,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final targetRect = _resolveTargetRect(step);

    return Positioned.fill(
      child: Stack(
        children: [
          CustomPaint(
            painter: _CoachBackdropPainter(
              targetRect: targetRect,
              color: Colors.black.withValues(alpha: 0.68),
            ),
            child: const SizedBox.expand(),
          ),
          if (targetRect != null) _TargetBorder(rect: targetRect),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = constraints.maxWidth.clamp(0.0, 440.0);
                final availableHeight = constraints.maxHeight;
                final card = Align(
                  alignment: _alignmentFor(targetRect, constraints.biggest),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: cardWidth,
                        maxHeight: availableHeight - 24,
                      ),
                      child: _CoachCard(
                        step: step,
                        progressLabel: '${stepIndex + 1} of $totalSteps',
                        progressValue: (stepIndex + 1) / totalSteps,
                        isFirst: isFirst,
                        isLast: isLast,
                        isBusy: isBusy,
                        onSkip: onSkip,
                        onBack: onBack,
                        onNext: onNext,
                        onFinish: onFinish,
                      ),
                    ),
                  ),
                );
                return card;
              },
            ),
          ),
        ],
      ),
    );
  }

  Rect? _resolveTargetRect(TutorialCoachStep step) {
    if (step.targetRect != null) return step.targetRect;
    final key = step.targetKey;
    if (key == null) return null;

    try {
      final targetContext = key.currentContext;
      final renderObject = targetContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) {
        return null;
      }
      final offset = renderObject.localToGlobal(Offset.zero);
      return offset & renderObject.size;
    } catch (_) {
      return null;
    }
  }

  Alignment _alignmentFor(Rect? targetRect, Size size) {
    if (targetRect == null) return Alignment.center;
    if (targetRect.center.dy < size.height * 0.42) {
      return Alignment.bottomCenter;
    }
    if (targetRect.center.dy > size.height * 0.64) {
      return Alignment.topCenter;
    }
    return Alignment.center;
  }
}

class _CoachCard extends StatelessWidget {
  final TutorialCoachStep step;
  final String progressLabel;
  final double progressValue;
  final bool isFirst;
  final bool isLast;
  final bool isBusy;
  final VoidCallback onSkip;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  const _CoachCard({
    required this.step,
    required this.progressLabel,
    required this.progressValue,
    required this.isFirst,
    required this.isLast,
    required this.isBusy,
    required this.onSkip,
    required this.onBack,
    required this.onNext,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF111827) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.26),
              blurRadius: 32,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StepIcon(icon: step.icon),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          progressLabel,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          step.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            height: 1.12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: isBusy ? null : onSkip,
                    child: const Text('Skip'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progressValue,
                  minHeight: 6,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                step.body,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.38,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              const _RouteCue(),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isFirst || isBusy ? null : onBack,
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isBusy ? null : (isLast ? onFinish : onNext),
                      icon: Icon(
                        isLast
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded,
                        size: 18,
                      ),
                      label: Text(isLast ? 'Finish' : 'Next'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepIcon extends StatelessWidget {
  final IconData icon;

  const _StepIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Icon(icon, color: colorScheme.primary, size: 26),
    );
  }
}

class _RouteCue extends StatelessWidget {
  const _RouteCue();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(16),
      ),
      child: CustomPaint(
        painter: _RouteCuePainter(
          color: colorScheme.primary,
          muted: colorScheme.outlineVariant,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _RouteCuePainter extends CustomPainter {
  final Color color;
  final Color muted;

  const _RouteCuePainter({
    required this.color,
    required this.muted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.62)
      ..quadraticBezierTo(
        size.width * 0.33,
        size.height * 0.16,
        size.width * 0.54,
        size.height * 0.50,
      )
      ..quadraticBezierTo(
        size.width * 0.72,
        size.height * 0.78,
        size.width * 0.92,
        size.height * 0.34,
      );

    canvas.drawPath(
      path,
      Paint()
        ..color = muted
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    final metric = path.computeMetrics().first;
    for (final point in const [0.0, 0.36, 0.7, 1.0]) {
      final tangent = metric.getTangentForOffset(metric.length * point);
      if (tangent == null) continue;
      canvas.drawCircle(tangent.position, 6, Paint()..color = Colors.white);
      canvas.drawCircle(tangent.position, 3.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _RouteCuePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.muted != muted;
  }
}

class _TargetBorder extends StatelessWidget {
  final Rect rect;

  const _TargetBorder({required this.rect});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Positioned.fromRect(
      rect: rect.inflate(8),
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color, width: 3),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.28),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoachBackdropPainter extends CustomPainter {
  final Rect? targetRect;
  final Color color;

  const _CoachBackdropPainter({
    required this.targetRect,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backdrop = Path()..addRect(Offset.zero & size);
    final target = targetRect;
    if (target != null) {
      backdrop
        ..fillType = PathFillType.evenOdd
        ..addRRect(
          RRect.fromRectAndRadius(
            target.inflate(10),
            const Radius.circular(20),
          ),
        );
    }
    canvas.drawPath(backdrop, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _CoachBackdropPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect || oldDelegate.color != color;
  }
}
