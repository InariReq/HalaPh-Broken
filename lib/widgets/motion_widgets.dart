import 'package:flutter/material.dart';

import 'halaph_logo_loading.dart';

class FadeInPage extends StatelessWidget {
  final Widget child;
  final Duration duration;

  const FadeInPage({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 320),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(opacity: value, child: child);
      },
      child: child,
    );
  }
}

class SlideFadeIn extends StatelessWidget {
  final Widget child;
  final int order;
  final double offset;
  final Duration baseDuration;

  const SlideFadeIn({
    super.key,
    required this.child,
    this.order = 0,
    this.offset = 18,
    this.baseDuration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: baseDuration + Duration(milliseconds: order.clamp(0, 6) * 70),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, offset * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class PressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? splashColor;
  final Color? highlightColor;
  final double pressedScale;
  final Duration duration;

  const PressableCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.padding,
    this.splashColor,
    this.highlightColor,
    this.pressedScale = 0.982,
    this.duration = const Duration(milliseconds: 130),
  });

  @override
  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedScale(
      scale: _pressed ? widget.pressedScale : 1,
      duration: widget.duration,
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        borderRadius: widget.borderRadius,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: widget.borderRadius,
          splashColor:
              widget.splashColor ?? Colors.blue.withValues(alpha: 0.10),
          highlightColor: widget.highlightColor ??
              colorScheme.primary.withValues(alpha: 0.06),
          onHighlightChanged: widget.onTap == null ? null : _setPressed,
          child: Padding(
            padding: widget.padding ?? EdgeInsets.zero,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class EmptyStatePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final Widget? secondaryAction;
  final bool compact;

  const EmptyStatePanel({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.secondaryAction,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 16 : 22),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(compact ? 18 : 22),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: compact ? 48 : 58,
            width: compact ? 48 : 58,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(compact ? 16 : 20),
            ),
            child:
                Icon(icon, size: compact ? 26 : 30, color: colorScheme.primary),
          ),
          SizedBox(height: compact ? 10 : 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 15 : 17,
              fontWeight: FontWeight.w900,
              color: colorScheme.onSurface,
            ),
          ),
          SizedBox(height: compact ? 5 : 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 12 : 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (action != null || secondaryAction != null) ...[
            SizedBox(height: compact ? 12 : 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                if (action != null) action!,
                if (secondaryAction != null) secondaryAction!,
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class LoadingStatePanel extends StatelessWidget {
  final String label;

  const LoadingStatePanel({
    super.key,
    this.label = 'Loading...',
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.96, end: 1),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.scale(scale: value, child: child);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: HalaPhLogoLoading(
            label: label,
            logoSize: 54,
          ),
        ),
      ),
    );
  }
}
