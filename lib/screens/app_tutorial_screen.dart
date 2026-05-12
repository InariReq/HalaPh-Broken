import 'package:flutter/material.dart';

import '../services/app_tutorial_service.dart';
import '../widgets/tutorial_coach_mark.dart';

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
  final _homeKey = GlobalKey();
  final _exploreKey = GlobalKey();
  final _destinationKey = GlobalKey();
  final _routeOptionsKey = GlobalKey();
  final _routeGuideKey = GlobalKey();
  final _favoritesKey = GlobalKey();
  final _plansKey = GlobalKey();
  final _collaborationKey = GlobalKey();
  final _remindersKey = GlobalKey();
  final _historyKey = GlobalKey();
  final _settingsKey = GlobalKey();

  late final List<TutorialCoachStep> _steps = [
    const TutorialCoachStep(
      title: 'Welcome to Guide Mode',
      body:
          'HalaPH helps you plan Philippine commute routes, fares, and trips before you go.',
      icon: Icons.navigation_rounded,
    ),
    TutorialCoachStep(
      title: 'Home',
      body:
          'Home is your starting point for next plans, saved trip tools, and quick commute actions.',
      icon: Icons.home_rounded,
      targetKey: _homeKey,
    ),
    TutorialCoachStep(
      title: 'Explore',
      body:
          'Search destinations and browse categories without needing to know the exact place first.',
      icon: Icons.explore_rounded,
      targetKey: _exploreKey,
    ),
    TutorialCoachStep(
      title: 'Destination cards',
      body:
          'Use destination cards to review place details, save with the heart, and open route options.',
      icon: Icons.place_rounded,
      targetKey: _destinationKey,
    ),
    TutorialCoachStep(
      title: 'Route options',
      body:
          'Compare commute options with transport icons, fare, time, confidence labels, and walking routes when nearby.',
      icon: Icons.alt_route_rounded,
      targetKey: _routeOptionsKey,
    ),
    TutorialCoachStep(
      title: 'Route guide',
      body:
          'Follow step-by-step boarding, alighting, walking instructions, and fare breakdowns.',
      icon: Icons.directions_rounded,
      targetKey: _routeGuideKey,
    ),
    TutorialCoachStep(
      title: 'Favorites',
      body:
          'Saved places stay in Favorites so repeat trips are easier to find.',
      icon: Icons.favorite_rounded,
      targetKey: _favoritesKey,
    ),
    TutorialCoachStep(
      title: 'Plans',
      body:
          'Create trip plans, add destinations, set dates, and estimate the trip budget.',
      icon: Icons.event_note_rounded,
      targetKey: _plansKey,
    ),
    TutorialCoachStep(
      title: 'Collaboration',
      body:
          'Friends can join shared plans with participant start locations for synced planning.',
      icon: Icons.groups_rounded,
      targetKey: _collaborationKey,
    ),
    TutorialCoachStep(
      title: 'Reminders',
      body:
          'Plan reminders use local notifications so you can get ready before trip stops.',
      icon: Icons.notifications_active_rounded,
      targetKey: _remindersKey,
    ),
    TutorialCoachStep(
      title: 'Trip History',
      body:
          'Finished plans and past trips appear in Trip History for later review.',
      icon: Icons.history_rounded,
      targetKey: _historyKey,
    ),
    TutorialCoachStep(
      title: 'Settings',
      body:
          'Manage account options, the Guide Mode toggle, and Replay Guide Mode from Settings.',
      icon: Icons.settings_rounded,
      targetKey: _settingsKey,
    ),
    const TutorialCoachStep(
      title: 'Ready to use HalaPH',
      body:
          'You are ready to search places, compare routes, follow commute steps, and plan trips.',
      icon: Icons.check_circle_rounded,
    ),
  ];

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
    final colorScheme = Theme.of(context).colorScheme;
    final step = _steps[_index];

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          _GuideModeMockApp(
            homeKey: _homeKey,
            exploreKey: _exploreKey,
            destinationKey: _destinationKey,
            routeOptionsKey: _routeOptionsKey,
            routeGuideKey: _routeGuideKey,
            favoritesKey: _favoritesKey,
            plansKey: _plansKey,
            collaborationKey: _collaborationKey,
            remindersKey: _remindersKey,
            historyKey: _historyKey,
            settingsKey: _settingsKey,
            activeStepIndex: _index,
          ),
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
}

class _GuideModeMockApp extends StatelessWidget {
  final GlobalKey homeKey;
  final GlobalKey exploreKey;
  final GlobalKey destinationKey;
  final GlobalKey routeOptionsKey;
  final GlobalKey routeGuideKey;
  final GlobalKey favoritesKey;
  final GlobalKey plansKey;
  final GlobalKey collaborationKey;
  final GlobalKey remindersKey;
  final GlobalKey historyKey;
  final GlobalKey settingsKey;
  final int activeStepIndex;

  const _GuideModeMockApp({
    required this.homeKey,
    required this.exploreKey,
    required this.destinationKey,
    required this.routeOptionsKey,
    required this.routeGuideKey,
    required this.favoritesKey,
    required this.plansKey,
    required this.collaborationKey,
    required this.remindersKey,
    required this.historyKey,
    required this.settingsKey,
    required this.activeStepIndex,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AbsorbPointer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/icons/app_icon.png',
                      width: 40,
                      height: 40,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.navigation_rounded,
                          color: colorScheme.primary,
                          size: 40,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HalaPH Guide Mode',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Static walkthrough preview',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _MiniIconButton(
                    key: settingsKey,
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                children: [
                  _HeroPanel(key: homeKey),
                  const SizedBox(height: 14),
                  _SearchPanel(key: exploreKey),
                  const SizedBox(height: 14),
                  _DestinationPanel(key: destinationKey),
                  const SizedBox(height: 14),
                  _RouteOptionsPanel(key: routeOptionsKey),
                  const SizedBox(height: 14),
                  _RouteGuidePanel(key: routeGuideKey),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _FeatureTile(
                          key: favoritesKey,
                          icon: Icons.favorite_rounded,
                          title: 'Favorites',
                          subtitle: 'Saved places',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FeatureTile(
                          key: plansKey,
                          icon: Icons.event_note_rounded,
                          title: 'Plans',
                          subtitle: 'Dates and budget',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _FeatureTile(
                          key: collaborationKey,
                          icon: Icons.groups_rounded,
                          title: 'Friends',
                          subtitle: 'Shared planning',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FeatureTile(
                          key: remindersKey,
                          icon: Icons.notifications_active_rounded,
                          title: 'Reminders',
                          subtitle: 'Local alerts',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _FeatureTile(
                    key: historyKey,
                    icon: Icons.history_rounded,
                    title: 'Trip History',
                    subtitle: 'Finished plans and past trips',
                  ),
                  SizedBox(height: activeStepIndex > 9 ? 160 : 80),
                ],
              ),
            ),
            _MockBottomNav(),
          ],
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _MockPanel(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plan your next commute',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Routes, fares, plans, and reminders in one place.',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            Icons.navigation_rounded,
            color: colorScheme.primary,
            size: 42,
          ),
        ],
      ),
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _MockPanel(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Search malls, parks, stations, and landmarks',
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

class _DestinationPanel extends StatelessWidget {
  const _DestinationPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _MockPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.place_rounded, color: colorScheme.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Destination card',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Icon(Icons.favorite_border_rounded, color: colorScheme.primary),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Place details, save action, and route entry point.',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteOptionsPanel extends StatelessWidget {
  const _RouteOptionsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _MockPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Route options',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _ModeChip(icon: Icons.directions_walk_rounded, label: 'Walk'),
              const SizedBox(width: 8),
              _ModeChip(
                  icon: Icons.directions_bus_filled_rounded, label: 'Jeepney'),
              const SizedBox(width: 8),
              _ModeChip(icon: Icons.train_rounded, label: 'Train'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '₱41 estimate - 38 min - Live transit estimate',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteGuidePanel extends StatelessWidget {
  const _RouteGuidePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _MockPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Step-by-step guide',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          _GuideStep(
            number: '1',
            icon: Icons.directions_walk_rounded,
            text: 'Walk to the stop',
          ),
          _GuideStep(
            number: '2',
            icon: Icons.directions_bus_filled_rounded,
            text: 'Ride jeepney toward the station',
          ),
          _GuideStep(
            number: '3',
            icon: Icons.flag_rounded,
            text: 'Alight near destination',
            color: colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _MockPanel(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

class _MockPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _MockPanel({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF263244) : const Color(0xFFE5EAF3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ModeChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ModeChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Flexible(
      child: Container(
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
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  final String number;
  final IconData icon;
  final String text;
  final Color? color;

  const _GuideStep({
    required this.number,
    required this.icon,
    required this.text,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final stepColor = color ?? colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: stepColor.withValues(alpha: 0.14),
            child: Text(
              number,
              style: TextStyle(
                color: stepColor,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Icon(icon, color: stepColor, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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

class _MiniIconButton extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniIconButton({
    super.key,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Tooltip(
        message: label,
        child: Icon(icon, color: colorScheme.primary, size: 22),
      ),
    );
  }
}

class _MockBottomNav extends StatelessWidget {
  const _MockBottomNav();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark ? const Color(0xFF263244) : const Color(0xFFE3ECF8),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _NavPreviewItem(
              icon: Icons.home_rounded, label: 'Home', active: true),
          _NavPreviewItem(icon: Icons.explore_rounded, label: 'Explore'),
          _NavPreviewItem(icon: Icons.event_note_rounded, label: 'Plans'),
          _NavPreviewItem(icon: Icons.favorite_rounded, label: 'Saved'),
          _NavPreviewItem(icon: Icons.person_rounded, label: 'Profile'),
        ],
      ),
    );
  }
}

class _NavPreviewItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const _NavPreviewItem({
    required this.icon,
    required this.label,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = active ? colorScheme.primary : colorScheme.onSurfaceVariant;
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: active ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
