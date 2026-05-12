import 'package:flutter/material.dart';

import '../services/app_tutorial_service.dart';
import '../services/guide_quest_controller.dart';
import '../widgets/guide_quest_overlay.dart';

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
    return _GuideExampleCard(
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.place_rounded, color: colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Intramuros',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Details, save, then view routes',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.favorite_border_rounded, color: colorScheme.primary),
          const SizedBox(width: 8),
          Icon(Icons.directions_rounded, color: colorScheme.primary),
        ],
      ),
    );
  }

  Widget _buildRouteOptionsExample(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _GuideExampleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _MiniModeChip(
                icon: Icons.directions_walk_rounded,
                label: 'Walk',
              ),
              _MiniModeChip(
                icon: Icons.directions_bus_filled_rounded,
                label: 'Jeepney',
              ),
              _MiniModeChip(icon: Icons.train_rounded, label: 'Train'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '₱41 estimate • 38 min • Live transit estimate',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.verified_rounded,
                size: 17,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Walking appears first when the destination is nearby.',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRouteGuideExample(BuildContext context) {
    return _GuideExampleCard(
      child: Column(
        children: const [
          _MiniGuideStep(
            number: '1',
            icon: Icons.directions_walk_rounded,
            text: 'Walk to the stop',
          ),
          _MiniGuideStep(
            number: '2',
            icon: Icons.directions_bus_filled_rounded,
            text: 'Ride jeepney toward the station',
          ),
          _MiniGuideStep(
            number: '3',
            icon: Icons.flag_rounded,
            text: 'Alight near destination',
          ),
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
          const _MiniFareRow(label: 'Walk', amount: '₱0'),
          const _MiniFareRow(label: 'Jeepney', amount: '₱13'),
          const _MiniFareRow(label: 'Train', amount: '₱28'),
          Divider(color: colorScheme.outlineVariant),
          const _MiniFareRow(
              label: 'Total estimate', amount: '₱41', bold: true),
        ],
      ),
    );
  }

  Widget _buildReminderExample(BuildContext context) {
    return const _GuideExampleCard(
      child: Row(
        children: [
          Icon(Icons.notifications_active_rounded),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Local plan reminders stay optional and can be changed in Settings.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryExample(BuildContext context) {
    return const _GuideExampleCard(
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Finished trips appear as completed plan cards.',
              style: TextStyle(fontWeight: FontWeight.w700),
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
          const Expanded(
            child: Text(
              'Finish Guide Mode to return to the app.',
              style: TextStyle(fontWeight: FontWeight.w800),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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

class _MiniModeChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniModeChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: 5),
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

class _MiniGuideStep extends StatelessWidget {
  final String number;
  final IconData icon;
  final String text;

  const _MiniGuideStep({
    required this.number,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: colorScheme.primary.withValues(alpha: 0.14),
            child: Text(
              number,
              style: TextStyle(
                color: colorScheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Icon(icon, color: colorScheme.primary, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
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
