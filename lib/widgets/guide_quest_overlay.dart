import 'package:flutter/material.dart';

import '../services/guide_quest_controller.dart';

class GuideQuestOverlay extends StatelessWidget {
  final GuideQuestStep step;
  final int stepIndex;
  final int totalSteps;
  final GlobalKey? targetKey;
  final Rect? targetRect;
  final WidgetBuilder? demoBuilder;
  final bool isFirst;
  final bool isLast;
  final bool isBusy;
  final bool showObjectiveComplete;
  final VoidCallback onSkip;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  const GuideQuestOverlay({
    super.key,
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    this.targetKey,
    this.targetRect,
    this.demoBuilder,
    required this.isFirst,
    required this.isLast,
    required this.isBusy,
    required this.showObjectiveComplete,
    required this.onSkip,
    required this.onBack,
    required this.onNext,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedTarget = _visibleTargetRect(
      context,
      targetRect ?? _resolveTargetRect(targetKey),
    );

    return Positioned.fill(
      child: Stack(
        children: [
          const ModalBarrier(dismissible: false, color: Colors.transparent),
          CustomPaint(
            painter: _GuideBackdropPainter(
              targetRect: resolvedTarget,
              color: Colors.black.withValues(alpha: 0.72),
            ),
            child: const SizedBox.expand(),
          ),
          if (resolvedTarget != null)
            _QuestTargetRing(
              rect: resolvedTarget,
              showComplete: showObjectiveComplete,
            ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = constraints.maxWidth.clamp(0.0, 460.0);
                return Align(
                  alignment: _alignmentFor(resolvedTarget, constraints.biggest),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: cardWidth,
                        maxHeight: constraints.maxHeight - 24,
                      ),
                      child: _QuestCard(
                        step: step,
                        stepIndex: stepIndex,
                        totalSteps: totalSteps,
                        hasTarget: resolvedTarget != null,
                        demoBuilder: demoBuilder,
                        isFirst: isFirst,
                        isLast: isLast,
                        isBusy: isBusy,
                        showObjectiveComplete: showObjectiveComplete,
                        onSkip: onSkip,
                        onBack: onBack,
                        onNext: onNext,
                        onFinish: onFinish,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Rect? _visibleTargetRect(BuildContext context, Rect? rect) {
    if (rect == null) return null;
    final size = MediaQuery.sizeOf(context);
    final viewport = Offset.zero & size;
    if (!rect.overlaps(viewport.deflate(8))) return null;
    return rect;
  }

  Rect? _resolveTargetRect(GlobalKey? key) {
    if (key == null) return null;
    try {
      final targetContext = key.currentContext;
      final renderObject = targetContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) return null;
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

class _QuestCard extends StatelessWidget {
  final GuideQuestStep step;
  final int stepIndex;
  final int totalSteps;
  final bool hasTarget;
  final WidgetBuilder? demoBuilder;
  final bool isFirst;
  final bool isLast;
  final bool isBusy;
  final bool showObjectiveComplete;
  final VoidCallback onSkip;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  const _QuestCard({
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.hasTarget,
    required this.demoBuilder,
    required this.isFirst,
    required this.isLast,
    required this.isBusy,
    required this.showObjectiveComplete,
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
    final cardColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFDDE8F7);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.30),
              blurRadius: 34,
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
                  _QuestIcon(icon: step.icon),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Guide Mode',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
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
              const SizedBox(height: 14),
              _QuestProgress(
                stepIndex: stepIndex,
                totalSteps: totalSteps,
              ),
              const SizedBox(height: 16),
              _ObjectivePanel(
                objective: step.objective,
                showComplete: showObjectiveComplete,
                completionLabel: step.completionLabel,
              ),
              const SizedBox(height: 14),
              Text(
                step.explanation,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.38,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (step.isTapTargetStep && hasTarget) ...[
                const SizedBox(height: 14),
                _TapPrompt(),
              ],
              const SizedBox(height: 16),
              demoBuilder?.call(context) ?? const _QuestRouteCue(),
              const SizedBox(height: 18),
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
                            ? Icons.check_circle_rounded
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

class _QuestIcon extends StatelessWidget {
  final IconData icon;

  const _QuestIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.20),
        ),
      ),
      child: Icon(icon, color: colorScheme.primary, size: 27),
    );
  }
}

class _QuestProgress extends StatelessWidget {
  final int stepIndex;
  final int totalSteps;

  const _QuestProgress({
    required this.stepIndex,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final value = (stepIndex + 1) / totalSteps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.route_rounded, size: 18, color: colorScheme.primary),
            const SizedBox(width: 7),
            Text(
              'Quest ${stepIndex + 1} of $totalSteps',
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 7,
            backgroundColor: colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

class _ObjectivePanel extends StatelessWidget {
  final String objective;
  final bool showComplete;
  final String completionLabel;

  const _ObjectivePanel({
    required this.objective,
    required this.showComplete,
    required this.completionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: showComplete
            ? Colors.green.withValues(alpha: 0.12)
            : colorScheme.primaryContainer.withValues(alpha: 0.44),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: showComplete
              ? Colors.green.withValues(alpha: 0.38)
              : colorScheme.primary.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            showComplete
                ? Icons.check_circle_rounded
                : Icons.flag_circle_rounded,
            color: showComplete ? Colors.green[700] : colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  showComplete ? completionLabel : 'Objective',
                  style: TextStyle(
                    color:
                        showComplete ? Colors.green[800] : colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  objective,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TapPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app_rounded, size: 17, color: colorScheme.secondary),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              'Target highlighted. Use Next to continue safely.',
              style: TextStyle(
                color: colorScheme.onSecondaryContainer,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestRouteCue extends StatelessWidget {
  const _QuestRouteCue();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(18),
      ),
      child: CustomPaint(
        painter: _QuestRouteCuePainter(
          color: colorScheme.primary,
          muted: colorScheme.outlineVariant,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _QuestRouteCuePainter extends CustomPainter {
  final Color color;
  final Color muted;

  const _QuestRouteCuePainter({
    required this.color,
    required this.muted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.62)
      ..cubicTo(
        size.width * 0.24,
        size.height * 0.14,
        size.width * 0.42,
        size.height * 0.18,
        size.width * 0.55,
        size.height * 0.52,
      )
      ..quadraticBezierTo(
        size.width * 0.72,
        size.height * 0.88,
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
    for (final point in const [0.0, 0.35, 0.68, 1.0]) {
      final tangent = metric.getTangentForOffset(metric.length * point);
      if (tangent == null) continue;
      canvas.drawCircle(tangent.position, 6.5, Paint()..color = Colors.white);
      canvas.drawCircle(tangent.position, 3.7, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _QuestRouteCuePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.muted != muted;
  }
}

class _QuestTargetRing extends StatelessWidget {
  final Rect rect;
  final bool showComplete;

  const _QuestTargetRing({
    required this.rect,
    required this.showComplete,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        showComplete ? Colors.green : Theme.of(context).colorScheme.primary;
    return Positioned.fromRect(
      rect: rect.inflate(9),
      child: IgnorePointer(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color, width: showComplete ? 4 : 3),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.32),
                blurRadius: 22,
                spreadRadius: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideBackdropPainter extends CustomPainter {
  final Rect? targetRect;
  final Color color;

  const _GuideBackdropPainter({
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
            target.inflate(11),
            const Radius.circular(22),
          ),
        );
    }
    canvas.drawPath(backdrop, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _GuideBackdropPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect || oldDelegate.color != color;
  }
}
