import 'package:flutter/material.dart';

import '../services/app_tutorial_service.dart';
import '../services/guide_mode_demo_data.dart';
import '../services/guide_quest_controller.dart';
import '../widgets/guide_quest_overlay.dart';
import '../widgets/transport_mode_widgets.dart';

class GuideModeTargetKeys {
  final GlobalKey? homeNavKey;
  final GlobalKey? exploreNavKey;
  final GlobalKey? plansNavKey;
  final GlobalKey? favoritesNavKey;
  final GlobalKey? friendsNavKey;
  final GlobalKey? profileNavKey;

  const GuideModeTargetKeys({
    this.homeNavKey,
    this.exploreNavKey,
    this.plansNavKey,
    this.favoritesNavKey,
    this.friendsNavKey,
    this.profileNavKey,
  });
}

class AppTutorialScreen extends StatefulWidget {
  final bool launchedFromSettings;
  final VoidCallback onFinish;
  final VoidCallback onSkip;
  final GuideModeTargetKeys targetKeys;
  final ValueChanged<int>? onStepChanged;

  const AppTutorialScreen({
    super.key,
    required this.launchedFromSettings,
    required this.onFinish,
    required this.onSkip,
    this.targetKeys = const GuideModeTargetKeys(),
    this.onStepChanged,
  });

  @override
  State<AppTutorialScreen> createState() => _AppTutorialScreenState();
}

class _AppTutorialScreenState extends State<AppTutorialScreen> {
  late final List<GuideQuestStep> _steps = GuideQuestController.buildSteps();

  int _index = 0;
  bool _closing = false;
  bool _showObjectiveComplete = false;

  bool get _isFirst => _index == 0;
  bool get _isLast => _index == _steps.length - 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyStepChanged());
  }

  void _notifyStepChanged() {
    widget.onStepChanged?.call(_index);
  }

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

  Future<void> _next() async {
    if (_isLast) {
      _close(skipped: false);
      return;
    }
    setState(() => _showObjectiveComplete = true);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    setState(() {
      _index += 1;
      _showObjectiveComplete = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyStepChanged());
  }

  void _back() {
    if (_isFirst) return;
    setState(() {
      _index -= 1;
      _showObjectiveComplete = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyStepChanged());
  }

  GlobalKey? _targetKeyFor(GuideQuestStep step) {
    return switch (step.targetKeyId) {
      GuideQuestController.homeTarget => widget.targetKeys.homeNavKey,
      GuideQuestController.exploreTarget => widget.targetKeys.exploreNavKey,
      GuideQuestController.plansTarget => widget.targetKeys.plansNavKey,
      GuideQuestController.favoritesTarget => widget.targetKeys.favoritesNavKey,
      GuideQuestController.friendsTarget => widget.targetKeys.friendsNavKey,
      GuideQuestController.profileTarget => widget.targetKeys.profileNavKey,
      _ => null,
    };
  }

  WidgetBuilder? _demoBuilderFor(GuideQuestDemoCardType type) {
    return switch (type) {
      GuideQuestDemoCardType.destinationCard => _buildDestinationExample,
      GuideQuestDemoCardType.routeOptions => _buildRouteOptionsExample,
      GuideQuestDemoCardType.routeGuide => _buildRouteGuideExample,
      GuideQuestDemoCardType.fareBreakdown => _buildFareBreakdownExample,
      GuideQuestDemoCardType.plan => _buildPlanExample,
      GuideQuestDemoCardType.collaboration => _buildCollaborationExample,
      GuideQuestDemoCardType.reminders => _buildReminderExample,
      GuideQuestDemoCardType.tripHistory => _buildHistoryExample,
      GuideQuestDemoCardType.finish => _buildFinishExample,
      GuideQuestDemoCardType.none => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_index];

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          GuideQuestOverlay(
            step: step,
            stepIndex: _index,
            totalSteps: _steps.length,
            targetKey: _targetKeyFor(step),
            demoBuilder: _demoBuilderFor(step.demoCardType),
            isFirst: _isFirst,
            isLast: _isLast,
            isBusy: _closing,
            showObjectiveComplete: _showObjectiveComplete,
            onSkip: () => _close(skipped: true),
            onBack: _back,
            onNext: _next,
            onFinish: () => _close(skipped: false),
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationExample(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final destinations = GuideModeDemoData.destinations.take(2).toList();
    return _GuideExampleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < destinations.length; i++) ...[
            _DestinationPreview(destination: destinations[i]),
            if (i != destinations.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: colorScheme.outlineVariant),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildRouteOptionsExample(BuildContext context) {
    return _GuideExampleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final route in GuideModeDemoData.routeOptions) ...[
            _DemoRouteOptionCard(route: route),
            if (route != GuideModeDemoData.routeOptions.last)
              const SizedBox(height: 9),
          ],
        ],
      ),
    );
  }

  Widget _buildRouteGuideExample(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _GuideExampleCard(
      child: Column(
        children: [
          for (final step in GuideModeDemoData.routeGuideSteps) ...[
            _MiniGuideStep(step: step),
            if (step != GuideModeDemoData.routeGuideSteps.last)
              Divider(height: 14, color: colorScheme.outlineVariant),
          ],
        ],
      ),
    );
  }

  Widget _buildFareBreakdownExample(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _GuideExampleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fare breakdown',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          for (final line in GuideModeDemoData.fareBreakdown) ...[
            if (line.isTotal) Divider(color: colorScheme.outlineVariant),
            _MiniFareRow(
              label: line.label,
              amount: line.amount,
              bold: line.isTotal,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanExample(BuildContext context) {
    final plan = GuideModeDemoData.plan;
    final colorScheme = Theme.of(context).colorScheme;
    return _GuideExampleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _DemoBadge(icon: Icons.calendar_month_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  plan.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              _MiniInfoPill(
                icon: Icons.account_balance_wallet_rounded,
                label: plan.estimatedBudget,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${plan.stopCount} stops • Shared: ${plan.shared ? 'Yes' : 'No'}',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [for (final stop in plan.stops) _TextChip(label: stop)],
          ),
        ],
      ),
    );
  }

  Widget _buildCollaborationExample(BuildContext context) {
    final collaboration = GuideModeDemoData.collaboration;
    final colorScheme = Theme.of(context).colorScheme;
    return _GuideExampleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _DemoBadge(icon: Icons.groups_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  collaboration.planTitle,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              _MiniInfoPill(
                icon: Icons.people_alt_rounded,
                label: '${collaboration.participants.length} people',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final participant in collaboration.participants)
                _ParticipantAvatar(label: participant),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            collaboration.note,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderExample(BuildContext context) {
    final reminder = GuideModeDemoData.reminder;
    final colorScheme = Theme.of(context).colorScheme;
    return _GuideExampleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              _DemoBadge(icon: Icons.notifications_active_rounded),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Plan reminders',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ReminderLine(text: reminder.primary),
          const SizedBox(height: 8),
          _ReminderLine(text: reminder.secondary),
          const SizedBox(height: 10),
          Text(
            'Preview only. Guide Mode does not request notification permission.',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryExample(BuildContext context) {
    final trip = GuideModeDemoData.tripHistory;
    final colorScheme = Theme.of(context).colorScheme;
    return _GuideExampleCard(
      child: Row(
        children: [
          const _DemoBadge(icon: Icons.check_circle_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '${trip.stopCount} stops • ${trip.finishedLabel}',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinishExample(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _GuideExampleCard(
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              'assets/icons/app_icon.png',
              width: 44,
              height: 44,
              errorBuilder: (context, error, stackTrace) {
                return Icon(Icons.navigation_rounded,
                    color: colorScheme.primary);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Guide complete',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'You can now search places, compare routes, and plan trips.',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
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

class _GuideExampleCard extends StatelessWidget {
  final Widget child;

  const _GuideExampleCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: child,
    );
  }
}

class _DestinationPreview extends StatelessWidget {
  final GuideModeDemoDestination destination;

  const _DestinationPreview({required this.destination});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(destination.icon, color: colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                destination.name,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                '${destination.type} • ${destination.locationLabel}',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                destination.ratingDisplay,
                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _DecorativeIconButton(
          icon: Icons.favorite_border_rounded,
          color: colorScheme.primary,
        ),
        const SizedBox(width: 6),
        _DecorativeIconButton(
          icon: Icons.directions_rounded,
          color: colorScheme.primary,
        ),
      ],
    );
  }
}

class _DemoRouteOptionCard extends StatelessWidget {
  final GuideModeDemoRouteOption route;

  const _DemoRouteOptionCard({required this.route});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  route.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                route.fare,
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TransportModeSequence(modes: route.modes, compact: true),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _MiniInfoPill(icon: Icons.schedule_rounded, label: route.time),
              _MiniInfoPill(icon: Icons.verified_rounded, label: route.source),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            route.reason,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DecorativeIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _DecorativeIconButton({
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _MiniGuideStep extends StatelessWidget {
  final GuideModeDemoRouteStep step;

  const _MiniGuideStep({required this.step});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final modeColor = colorForTravelMode(context, step.mode);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: colorScheme.primary.withValues(alpha: 0.14),
          child: Text(
            '${step.number}',
            style: TextStyle(
              color: colorScheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Icon(iconForTravelMode(step.mode), color: modeColor, size: 20),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      step.instruction,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (step.fare != null)
                    Text(
                      step.fare!,
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                step.transferHint ?? step.modeLabel,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniFareRow extends StatelessWidget {
  final String label;
  final String amount;
  final bool bold;

  const _MiniFareRow({
    required this.label,
    required this.amount,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              color: bold ? colorScheme.primary : colorScheme.onSurface,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniInfoPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: colorScheme.primary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TextChip extends StatelessWidget {
  final String label;

  const _TextChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DemoBadge extends StatelessWidget {
  final IconData icon;

  const _DemoBadge({required this.icon});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: colorScheme.primary, size: 22),
    );
  }
}

class _ParticipantAvatar extends StatelessWidget {
  final String label;

  const _ParticipantAvatar({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: colorScheme.primary,
            child: Text(
              label.isEmpty ? '?' : label.substring(0, 1),
              style: TextStyle(
                color: colorScheme.onPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: colorScheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderLine extends StatelessWidget {
  final String text;

  const _ReminderLine({required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.schedule_rounded, size: 17, color: colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
