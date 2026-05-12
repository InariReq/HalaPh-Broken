import 'package:flutter/material.dart';

import '../services/app_tutorial_service.dart';
import '../widgets/tutorial_coach_mark.dart';

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
  late final List<TutorialCoachStep> _steps = [
    TutorialCoachStep(
      title: 'Home',
      body:
          'Home is the starting point for your next plans, trip tools, and commute shortcuts.',
      icon: Icons.home_rounded,
      targetKey: widget.targetKeys.homeNavKey,
    ),
    TutorialCoachStep(
      title: 'Explore',
      body:
          'Use Explore to search destinations and browse categories. Guide Mode will not run a real search.',
      icon: Icons.explore_rounded,
      targetKey: widget.targetKeys.exploreNavKey,
    ),
    TutorialCoachStep(
      title: 'Destination cards',
      body:
          'Destination cards show place details, a heart for saving, and View Routes when you are ready.',
      icon: Icons.place_rounded,
      exampleBuilder: _buildDestinationExample,
    ),
    TutorialCoachStep(
      title: 'Route options',
      body:
          'Compare transport icons, walking routes, fare, time, and confidence labels before opening a guide.',
      icon: Icons.alt_route_rounded,
      exampleBuilder: _buildRouteOptionsExample,
    ),
    TutorialCoachStep(
      title: 'Route guide',
      body:
          'Route guides break the commute into boarding, alighting, walking steps, and fare breakdowns.',
      icon: Icons.directions_rounded,
      exampleBuilder: _buildRouteGuideExample,
    ),
    TutorialCoachStep(
      title: 'Favorites',
      body: 'Favorites keeps saved places close for repeat trips.',
      icon: Icons.favorite_rounded,
      targetKey: widget.targetKeys.favoritesNavKey,
    ),
    TutorialCoachStep(
      title: 'Plans',
      body:
          'Plans help you group destinations, set dates, and estimate trip budget before you go.',
      icon: Icons.event_note_rounded,
      targetKey: widget.targetKeys.plansNavKey,
    ),
    TutorialCoachStep(
      title: 'Collaboration',
      body:
          'Friends and shared plans support group planning with participant start locations.',
      icon: Icons.groups_rounded,
      targetKey: widget.targetKeys.friendsNavKey,
    ),
    TutorialCoachStep(
      title: 'Reminders',
      body:
          'Plan reminders can notify you before trip stops. Guide Mode does not request notification permission.',
      icon: Icons.notifications_active_rounded,
      exampleBuilder: _buildReminderExample,
    ),
    TutorialCoachStep(
      title: 'Trip History',
      body:
          'Finished plans move to Trip History so past trips stay available for review.',
      icon: Icons.history_rounded,
      exampleBuilder: _buildHistoryExample,
    ),
    TutorialCoachStep(
      title: 'Settings',
      body:
          'Open Profile for account options, app settings, the Guide Mode toggle, and Replay Guide Mode.',
      icon: Icons.settings_rounded,
      targetKey: widget.targetKeys.profileNavKey,
    ),
    TutorialCoachStep(
      title: 'Ready to use HalaPH',
      body:
          'You are ready to search places, compare routes, follow commute steps, and plan trips.',
      icon: Icons.check_circle_rounded,
      exampleBuilder: _buildFinishExample,
    ),
  ];

  int _index = 0;
  bool _closing = false;

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

  void _next() {
    if (_isLast) {
      _close(skipped: false);
      return;
    }
    setState(() => _index += 1);
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyStepChanged());
  }

  void _back() {
    if (_isFirst) return;
    setState(() => _index -= 1);
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyStepChanged());
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_index];

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          TutorialCoachMark(
            step: step,
            stepIndex: _index,
            totalSteps: _steps.length,
            isFirst: _isFirst,
            isLast: _isLast,
            isBusy: _closing,
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
