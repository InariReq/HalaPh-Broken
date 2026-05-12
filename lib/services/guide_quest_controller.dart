import 'package:flutter/material.dart';

enum GuideQuestStepType {
  target,
  fallback,
  finish,
}

enum GuideQuestDemoCardType {
  none,
  destinationCard,
  routeOptions,
  routeGuide,
  fareBreakdown,
  plan,
  collaboration,
  reminders,
  tripHistory,
  finish,
}

class GuideQuestStep {
  final String title;
  final String objective;
  final String explanation;
  final IconData icon;
  final GuideQuestStepType type;
  final String? targetKeyId;
  final GuideQuestDemoCardType demoCardType;
  final bool isTapTargetStep;
  final String completionLabel;

  const GuideQuestStep({
    required this.title,
    required this.objective,
    required this.explanation,
    required this.icon,
    required this.type,
    this.targetKeyId,
    this.demoCardType = GuideQuestDemoCardType.none,
    this.isTapTargetStep = false,
    this.completionLabel = 'Objective complete',
  });
}

class GuideQuestController {
  static const String homeTarget = 'home';
  static const String exploreTarget = 'explore';
  static const String plansTarget = 'plans';
  static const String favoritesTarget = 'favorites';
  static const String friendsTarget = 'friends';
  static const String profileTarget = 'profile';

  static List<GuideQuestStep> buildSteps() {
    return const [
      GuideQuestStep(
        title: 'Welcome to Guide Mode',
        objective: 'Learn the HalaPH flow.',
        explanation:
            'We will guide you through routes, fares, plans, and collaboration.',
        icon: Icons.navigation_rounded,
        type: GuideQuestStepType.fallback,
      ),
      GuideQuestStep(
        title: 'Home',
        objective: 'Start from Home.',
        explanation: 'Home shows your next trip and quick planning tools.',
        icon: Icons.home_rounded,
        type: GuideQuestStepType.target,
        targetKeyId: homeTarget,
        isTapTargetStep: true,
      ),
      GuideQuestStep(
        title: 'Explore',
        objective: 'Find a destination.',
        explanation: 'Explore helps you search places and browse categories.',
        icon: Icons.explore_rounded,
        type: GuideQuestStepType.target,
        targetKeyId: exploreTarget,
        isTapTargetStep: true,
      ),
      GuideQuestStep(
        title: 'Destination Cards',
        objective: 'Learn destination actions.',
        explanation:
            'Destination cards show details, saving, and route actions.',
        icon: Icons.place_rounded,
        type: GuideQuestStepType.fallback,
        demoCardType: GuideQuestDemoCardType.destinationCard,
      ),
      GuideQuestStep(
        title: 'Route Options',
        objective: 'Compare commute choices.',
        explanation:
            'Route cards show transport icons, walking routes, fares, and confidence labels.',
        icon: Icons.alt_route_rounded,
        type: GuideQuestStepType.fallback,
        demoCardType: GuideQuestDemoCardType.routeOptions,
      ),
      GuideQuestStep(
        title: 'Route Guide',
        objective: 'Follow the step-by-step guide.',
        explanation:
            'Route guides explain where to board, transfer, and alight.',
        icon: Icons.directions_rounded,
        type: GuideQuestStepType.fallback,
        demoCardType: GuideQuestDemoCardType.routeGuide,
      ),
      GuideQuestStep(
        title: 'Fare Breakdown',
        objective: 'Check commute cost.',
        explanation: 'Fare breakdowns help you prepare your budget.',
        icon: Icons.payments_rounded,
        type: GuideQuestStepType.fallback,
        demoCardType: GuideQuestDemoCardType.fareBreakdown,
      ),
      GuideQuestStep(
        title: 'Favorites',
        objective: 'Save places.',
        explanation: 'Favorites keep saved destinations ready.',
        icon: Icons.favorite_rounded,
        type: GuideQuestStepType.target,
        targetKeyId: favoritesTarget,
        isTapTargetStep: true,
      ),
      GuideQuestStep(
        title: 'Plans',
        objective: 'Build a trip plan.',
        explanation: 'Plans organize stops, dates, and estimated budget.',
        icon: Icons.event_note_rounded,
        type: GuideQuestStepType.target,
        targetKeyId: plansTarget,
        demoCardType: GuideQuestDemoCardType.plan,
        isTapTargetStep: true,
      ),
      GuideQuestStep(
        title: 'Collaboration',
        objective: 'Plan with friends.',
        explanation:
            'Shared plans let participants coordinate and set starting points.',
        icon: Icons.groups_rounded,
        type: GuideQuestStepType.target,
        targetKeyId: friendsTarget,
        demoCardType: GuideQuestDemoCardType.collaboration,
        isTapTargetStep: true,
      ),
      GuideQuestStep(
        title: 'Reminders',
        objective: 'Leave on time.',
        explanation: 'Plan reminders help you prepare before each stop.',
        icon: Icons.notifications_active_rounded,
        type: GuideQuestStepType.fallback,
        demoCardType: GuideQuestDemoCardType.reminders,
      ),
      GuideQuestStep(
        title: 'Trip History',
        objective: 'Review finished trips.',
        explanation: 'Completed trips appear in Trip History.',
        icon: Icons.history_rounded,
        type: GuideQuestStepType.fallback,
        demoCardType: GuideQuestDemoCardType.tripHistory,
      ),
      GuideQuestStep(
        title: 'Settings',
        objective: 'Control Guide Mode.',
        explanation: 'Replay or turn off Guide Mode in Settings.',
        icon: Icons.settings_rounded,
        type: GuideQuestStepType.target,
        targetKeyId: profileTarget,
        isTapTargetStep: true,
      ),
      GuideQuestStep(
        title: 'Finish',
        objective: 'Start using HalaPH.',
        explanation:
            'You are ready to search, compare routes, and build your first trip plan.',
        icon: Icons.emoji_events_rounded,
        type: GuideQuestStepType.finish,
        demoCardType: GuideQuestDemoCardType.finish,
        completionLabel: 'Guide complete',
      ),
    ];
  }
}
