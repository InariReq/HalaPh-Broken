import 'package:flutter/material.dart';

enum GuideQuestStepType {
  explainOnly,
  tapTarget,
  liveAction,
  fallbackDemo,
  confirmWriteAction,
  finish,
}

class GuideQuestActionId {
  static const String startGuide = 'startGuide';
  static const String reviewHome = 'reviewHome';
  static const String openExplore = 'openExplore';
  static const String useSampleDestination = 'useSampleDestination';
  static const String previewLiveRoutes = 'previewLiveRoutes';
  static const String chooseDemoRoute = 'chooseDemoRoute';
  static const String reviewFareBreakdown = 'reviewFareBreakdown';
  static const String openFavorites = 'openFavorites';
  static const String openPlans = 'openPlans';
  static const String openFriends = 'openFriends';
  static const String reviewReminders = 'reviewReminders';
  static const String reviewTripHistory = 'reviewTripHistory';
  static const String openSettings = 'openSettings';
  static const String finish = 'finish';
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
  final String instruction;
  final IconData icon;
  final GuideQuestStepType type;
  final String? targetKeyId;
  final String? actionId;
  final GuideQuestDemoCardType demoCardType;
  final bool isTapTargetStep;
  final bool allowsApiCalls;
  final bool requiresConfirmation;
  final String completionLabel;
  final String completionMessage;
  final String? primaryActionLabel;

  const GuideQuestStep({
    required this.title,
    required this.objective,
    required this.explanation,
    required this.instruction,
    required this.icon,
    required this.type,
    this.targetKeyId,
    this.actionId,
    this.demoCardType = GuideQuestDemoCardType.none,
    this.isTapTargetStep = false,
    this.allowsApiCalls = false,
    this.requiresConfirmation = false,
    this.completionLabel = 'Objective complete',
    this.completionMessage = 'You completed this guide objective.',
    this.primaryActionLabel,
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
        objective: 'Start your first HalaPH walkthrough.',
        explanation:
            'We will guide you through routes, fares, plans, and collaboration.',
        instruction: 'Press Start Guide to begin the walkthrough.',
        icon: Icons.navigation_rounded,
        type: GuideQuestStepType.explainOnly,
        actionId: GuideQuestActionId.startGuide,
        primaryActionLabel: 'Start Guide',
        completionMessage: 'Guide started.',
      ),
      GuideQuestStep(
        title: 'Home',
        objective: 'Review your starting screen.',
        explanation: 'Home shows your next trip and quick planning tools.',
        instruction: 'Review the highlighted Home area, then continue.',
        icon: Icons.home_rounded,
        type: GuideQuestStepType.tapTarget,
        targetKeyId: homeTarget,
        actionId: GuideQuestActionId.reviewHome,
        isTapTargetStep: true,
        primaryActionLabel: 'Continue',
        completionMessage: 'Home reviewed.',
      ),
      GuideQuestStep(
        title: 'Explore',
        objective: 'Open Explore.',
        explanation: 'Explore helps you search places and browse categories.',
        instruction: 'Use the guided action or the highlighted Explore tab.',
        icon: Icons.explore_rounded,
        type: GuideQuestStepType.tapTarget,
        targetKeyId: exploreTarget,
        actionId: GuideQuestActionId.openExplore,
        isTapTargetStep: true,
        primaryActionLabel: 'Open Explore',
        completionMessage: 'Explore opened.',
      ),
      GuideQuestStep(
        title: 'Find a Destination',
        objective: 'Find a destination.',
        explanation:
            'Destination cards show details, saving, and route actions.',
        instruction:
            'Use a sample destination now, or try live search in Explore after the guide.',
        icon: Icons.place_rounded,
        type: GuideQuestStepType.liveAction,
        actionId: GuideQuestActionId.useSampleDestination,
        demoCardType: GuideQuestDemoCardType.destinationCard,
        primaryActionLabel: 'Use sample destination',
        completionMessage: 'Sample destination selected.',
      ),
      GuideQuestStep(
        title: 'Route Options',
        objective: 'Compare commute choices.',
        explanation:
            'Route cards show transport icons, walking routes, fares, and confidence labels.',
        instruction:
            'Preview live route options only when you choose to. If live data is unavailable, the guide uses the offline route panel.',
        icon: Icons.alt_route_rounded,
        type: GuideQuestStepType.liveAction,
        actionId: GuideQuestActionId.previewLiveRoutes,
        demoCardType: GuideQuestDemoCardType.routeOptions,
        allowsApiCalls: true,
        primaryActionLabel: 'Preview live route options',
        completionMessage: 'Route options reviewed.',
      ),
      GuideQuestStep(
        title: 'Route Guide',
        objective: 'Follow the step-by-step guide.',
        explanation:
            'Route guides explain where to board, transfer, and alight.',
        instruction:
            'Study the guide steps. A real route guide opens from a selected live route.',
        icon: Icons.directions_rounded,
        type: GuideQuestStepType.fallbackDemo,
        actionId: GuideQuestActionId.chooseDemoRoute,
        demoCardType: GuideQuestDemoCardType.routeGuide,
        primaryActionLabel: 'Review route steps',
        completionMessage: 'Route guide reviewed.',
      ),
      GuideQuestStep(
        title: 'Fare Breakdown',
        objective: 'Check commute cost.',
        explanation: 'Fare breakdowns help you prepare your budget.',
        instruction: 'Review how HalaPH separates walking and paid segments.',
        icon: Icons.payments_rounded,
        type: GuideQuestStepType.fallbackDemo,
        actionId: GuideQuestActionId.reviewFareBreakdown,
        demoCardType: GuideQuestDemoCardType.fareBreakdown,
        primaryActionLabel: 'Check fare estimate',
        completionMessage: 'Fare estimate checked.',
      ),
      GuideQuestStep(
        title: 'Favorites',
        objective: 'Save places.',
        explanation: 'Favorites keep saved destinations ready.',
        instruction:
            'Open Favorites to see saved places. Guide Mode will not add or remove favorites.',
        icon: Icons.favorite_rounded,
        type: GuideQuestStepType.tapTarget,
        targetKeyId: favoritesTarget,
        actionId: GuideQuestActionId.openFavorites,
        isTapTargetStep: true,
        primaryActionLabel: 'Open Favorites',
        completionMessage: 'Favorites opened.',
      ),
      GuideQuestStep(
        title: 'Plans',
        objective: 'Build a trip plan.',
        explanation: 'Plans organize stops, dates, and estimated budget.',
        instruction:
            'Open My Plans. Creating a real plan always stays under your control.',
        icon: Icons.event_note_rounded,
        type: GuideQuestStepType.tapTarget,
        targetKeyId: plansTarget,
        actionId: GuideQuestActionId.openPlans,
        demoCardType: GuideQuestDemoCardType.plan,
        isTapTargetStep: true,
        primaryActionLabel: 'Open Plans',
        completionMessage: 'Plans opened.',
      ),
      GuideQuestStep(
        title: 'Collaboration',
        objective: 'Plan with friends.',
        explanation:
            'Shared plans let participants coordinate and set starting points.',
        instruction:
            'Open Friends to learn where collaboration starts. Guide Mode will not send requests.',
        icon: Icons.groups_rounded,
        type: GuideQuestStepType.tapTarget,
        targetKeyId: friendsTarget,
        actionId: GuideQuestActionId.openFriends,
        demoCardType: GuideQuestDemoCardType.collaboration,
        isTapTargetStep: true,
        primaryActionLabel: 'Open Friends',
        completionMessage: 'Friends opened.',
      ),
      GuideQuestStep(
        title: 'Reminders',
        objective: 'Leave on time.',
        explanation: 'Plan reminders help you prepare before each stop.',
        instruction:
            'Review the reminder preview. Guide Mode does not request notification permission.',
        icon: Icons.notifications_active_rounded,
        type: GuideQuestStepType.fallbackDemo,
        actionId: GuideQuestActionId.reviewReminders,
        demoCardType: GuideQuestDemoCardType.reminders,
        primaryActionLabel: 'Review reminders',
        completionMessage: 'Reminders reviewed.',
      ),
      GuideQuestStep(
        title: 'Trip History',
        objective: 'Review finished trips.',
        explanation: 'Completed trips appear in Trip History.',
        instruction: 'Review where finished plans appear after completion.',
        icon: Icons.history_rounded,
        type: GuideQuestStepType.fallbackDemo,
        actionId: GuideQuestActionId.reviewTripHistory,
        demoCardType: GuideQuestDemoCardType.tripHistory,
        primaryActionLabel: 'Review history',
        completionMessage: 'Trip History reviewed.',
      ),
      GuideQuestStep(
        title: 'Settings',
        objective: 'Control Guide Mode.',
        explanation: 'Replay or turn off Guide Mode in Settings.',
        instruction: 'Open Profile/Settings to find Guide Mode controls.',
        icon: Icons.settings_rounded,
        type: GuideQuestStepType.tapTarget,
        targetKeyId: profileTarget,
        actionId: GuideQuestActionId.openSettings,
        isTapTargetStep: true,
        primaryActionLabel: 'Open Profile',
        completionMessage: 'Settings controls located.',
      ),
      GuideQuestStep(
        title: 'Finish',
        objective: 'Start using HalaPH.',
        explanation:
            'You are ready to search, compare routes, and build your first trip plan.',
        instruction:
            'Finish the walkthrough or practice again later from Settings.',
        icon: Icons.emoji_events_rounded,
        type: GuideQuestStepType.finish,
        actionId: GuideQuestActionId.finish,
        demoCardType: GuideQuestDemoCardType.finish,
        completionLabel: 'Guide complete',
        completionMessage: 'Guide complete. You are ready to use HalaPH.',
        primaryActionLabel: 'Finish',
      ),
    ];
  }
}
