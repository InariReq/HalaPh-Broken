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
  static const String openExplore = 'openExplore';
  static const String selectIntramuros = 'selectIntramuros';
  static const String viewRoutes = 'viewRoutes';
  static const String pickRecommendedRoute = 'pickRecommendedRoute';
  static const String continueToFareBreakdown = 'continueToFareBreakdown';
  static const String saveDestinationConcept = 'saveDestinationConcept';
  static const String addToSamplePlan = 'addToSamplePlan';
  static const String showCollaboration = 'showCollaboration';
  static const String showReminders = 'showReminders';
  static const String finishTripPreview = 'finishTripPreview';
  static const String openSettings = 'openSettings';
  static const String reviewSettings = 'reviewSettings';
  static const String finish = 'finish';
}

enum GuideQuestDemoCardType {
  none,
  destinationCard,
  destinationPreview,
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
  final String reminderText;
  final String collapseButtonLabel;
  final bool requiresUserAction;

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
    this.reminderText = 'Guide Mode: Complete the objective',
    this.collapseButtonLabel = 'Got it',
    this.requiresUserAction = true,
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
            'In this walkthrough, we will plan a sample commute to Intramuros, compare routes, check fares, and turn it into a trip plan.',
        instruction:
            'Start the walkthrough. HalaPH will guide you through the app like a presenter.',
        icon: Icons.navigation_rounded,
        type: GuideQuestStepType.explainOnly,
        actionId: GuideQuestActionId.startGuide,
        primaryActionLabel: 'Start walkthrough',
        reminderText: 'Guide Mode: Start walkthrough',
        collapseButtonLabel: 'Start walkthrough',
        requiresUserAction: false,
        completionMessage: 'Walkthrough started.',
      ),
      GuideQuestStep(
        title: 'Home',
        objective: 'Open Explore from Home.',
        explanation:
            'Home is the command center. It keeps trip tools and suggested places close so commuters can start planning quickly.',
        instruction:
            'After this card moves away, tap the highlighted Explore tab.',
        icon: Icons.home_rounded,
        type: GuideQuestStepType.tapTarget,
        targetKeyId: exploreTarget,
        actionId: GuideQuestActionId.openExplore,
        isTapTargetStep: true,
        primaryActionLabel: 'Got it',
        reminderText: 'Guide Mode: Tap Explore',
        completionMessage: 'Explore opened.',
      ),
      GuideQuestStep(
        title: 'Explore',
        objective: 'Select Intramuros.',
        explanation:
            'Explore is where the trip starts. It helps users search destinations, browse categories, and choose a place worth planning around.',
        instruction:
            'After this card moves away, select Intramuros from the Explore list.',
        icon: Icons.explore_rounded,
        type: GuideQuestStepType.liveAction,
        actionId: GuideQuestActionId.selectIntramuros,
        isTapTargetStep: true,
        primaryActionLabel: 'Got it',
        reminderText: 'Guide Mode: Select Intramuros',
        completionMessage: 'Intramuros selected.',
      ),
      GuideQuestStep(
        title: 'Destination Preview',
        objective: 'Open route choices.',
        explanation:
            'A destination preview shows why the place matters, whether it is saved, and the route action that turns browsing into a commute plan.',
        instruction:
            'Tap View Routes in the preview. Live route loading can run only after this tap; if it fails, the guide keeps an offline example.',
        icon: Icons.place_rounded,
        type: GuideQuestStepType.liveAction,
        actionId: GuideQuestActionId.viewRoutes,
        demoCardType: GuideQuestDemoCardType.destinationPreview,
        allowsApiCalls: true,
        primaryActionLabel: 'Got it',
        reminderText: 'Guide Mode: Tap View Routes',
        completionMessage: 'Route choices opened.',
      ),
      GuideQuestStep(
        title: 'Route Options',
        objective: 'Pick the Jeepney + Train route.',
        explanation:
            'Route cards help commuters compare cost, time, walking, transport icons, and confidence labels before leaving.',
        instruction:
            'Pick the recommended Jeepney + Train route to see how mixed commutes are explained.',
        icon: Icons.alt_route_rounded,
        type: GuideQuestStepType.fallbackDemo,
        actionId: GuideQuestActionId.pickRecommendedRoute,
        demoCardType: GuideQuestDemoCardType.routeOptions,
        primaryActionLabel: 'Got it',
        reminderText: 'Guide Mode: Pick the Jeepney + Train route',
        completionMessage: 'Recommended route selected.',
      ),
      GuideQuestStep(
        title: 'Route Guide',
        objective: 'Continue to fare breakdown.',
        explanation:
            'The route guide shows where to board, transfer, alight, and walk so the commute feels followable.',
        instruction: 'Review the steps, then continue to the fare breakdown.',
        icon: Icons.directions_rounded,
        type: GuideQuestStepType.fallbackDemo,
        actionId: GuideQuestActionId.continueToFareBreakdown,
        demoCardType: GuideQuestDemoCardType.routeGuide,
        primaryActionLabel: 'Got it',
        reminderText: 'Guide Mode: Continue to fare breakdown',
        completionMessage: 'Route guide reviewed.',
      ),
      GuideQuestStep(
        title: 'Fare Breakdown',
        objective: 'Save the destination concept.',
        explanation:
            'Fare breakdowns separate walking from paid segments so commuters can prepare cash and compare route value.',
        instruction:
            'Tap Save destination. In Guide Mode this updates local walkthrough state only.',
        icon: Icons.payments_rounded,
        type: GuideQuestStepType.fallbackDemo,
        actionId: GuideQuestActionId.saveDestinationConcept,
        demoCardType: GuideQuestDemoCardType.fareBreakdown,
        primaryActionLabel: 'Got it',
        reminderText: 'Guide Mode: Save destination',
        completionMessage: 'Destination saved in Guide Mode only.',
      ),
      GuideQuestStep(
        title: 'Favorites',
        objective: 'Add Intramuros to a sample plan.',
        explanation:
            'Favorites keep useful places ready, so repeat destinations can become routes or trip stops faster.',
        instruction:
            'Tap Add to sample plan. This updates walkthrough state only and does not write a real plan.',
        icon: Icons.favorite_rounded,
        type: GuideQuestStepType.confirmWriteAction,
        targetKeyId: favoritesTarget,
        actionId: GuideQuestActionId.addToSamplePlan,
        demoCardType: GuideQuestDemoCardType.destinationCard,
        isTapTargetStep: true,
        primaryActionLabel: 'Got it',
        reminderText: 'Guide Mode: Add to sample plan',
        requiresConfirmation: true,
        completionMessage: 'Added to the sample plan in Guide Mode only.',
      ),
      GuideQuestStep(
        title: 'Plans',
        objective: 'Show collaboration.',
        explanation:
            'Plans turn route ideas into dated itineraries with stops, budget, and reminders.',
        instruction:
            'Review the Manila Day Trip preview, then show how collaboration works.',
        icon: Icons.event_note_rounded,
        type: GuideQuestStepType.fallbackDemo,
        targetKeyId: plansTarget,
        actionId: GuideQuestActionId.showCollaboration,
        demoCardType: GuideQuestDemoCardType.plan,
        isTapTargetStep: true,
        primaryActionLabel: 'Got it',
        reminderText: 'Guide Mode: Show collaboration',
        completionMessage: 'Collaboration preview opened.',
      ),
      GuideQuestStep(
        title: 'Collaboration',
        objective: 'Show reminders.',
        explanation:
            'Shared plans let participants coordinate while each person keeps their own starting point.',
        instruction:
            'Review the shared plan preview, then show reminders. No friend request is sent.',
        icon: Icons.groups_rounded,
        type: GuideQuestStepType.fallbackDemo,
        targetKeyId: friendsTarget,
        actionId: GuideQuestActionId.showReminders,
        demoCardType: GuideQuestDemoCardType.collaboration,
        isTapTargetStep: true,
        primaryActionLabel: 'Got it',
        reminderText: 'Guide Mode: Show reminders',
        completionMessage: 'Reminder preview opened.',
      ),
      GuideQuestStep(
        title: 'Reminders',
        objective: 'Finish trip preview.',
        explanation:
            'Reminders help commuters leave before scheduled stops without needing to keep checking the plan.',
        instruction:
            'Finish the trip preview. Guide Mode does not request notification permission here.',
        icon: Icons.notifications_active_rounded,
        type: GuideQuestStepType.fallbackDemo,
        actionId: GuideQuestActionId.finishTripPreview,
        demoCardType: GuideQuestDemoCardType.reminders,
        primaryActionLabel: 'Got it',
        reminderText: 'Guide Mode: Finish trip preview',
        completionMessage: 'Trip preview finished.',
      ),
      GuideQuestStep(
        title: 'Trip History',
        objective: 'Open Settings.',
        explanation:
            'Completed trips move into History, giving users a record of past plans and finished routes.',
        instruction: 'Review the history preview, then open Settings.',
        icon: Icons.history_rounded,
        type: GuideQuestStepType.fallbackDemo,
        actionId: GuideQuestActionId.openSettings,
        demoCardType: GuideQuestDemoCardType.tripHistory,
        primaryActionLabel: 'Got it',
        reminderText: 'Guide Mode: Open Settings',
        completionMessage: 'Settings opened.',
      ),
      GuideQuestStep(
        title: 'Settings',
        objective: 'Finish the walkthrough.',
        explanation:
            'Settings is where users control reminders, account options, and whether Guide Mode replays every start.',
        instruction: 'Review the Guide Mode controls, then finish.',
        icon: Icons.settings_rounded,
        type: GuideQuestStepType.explainOnly,
        targetKeyId: profileTarget,
        actionId: GuideQuestActionId.reviewSettings,
        isTapTargetStep: true,
        primaryActionLabel: 'Finish walkthrough',
        reminderText: 'Guide Mode: Finish',
        requiresUserAction: false,
        completionMessage: 'Settings controls reviewed.',
      ),
      GuideQuestStep(
        title: 'Finish',
        objective: 'Start using HalaPH.',
        explanation:
            'You are ready to use HalaPH. Search a place, compare routes, or create your first trip plan.',
        instruction:
            'Start using HalaPH now, or replay this walkthrough for practice.',
        icon: Icons.emoji_events_rounded,
        type: GuideQuestStepType.finish,
        actionId: GuideQuestActionId.finish,
        demoCardType: GuideQuestDemoCardType.finish,
        completionLabel: 'Guide complete',
        completionMessage: 'Guide complete. You are ready to use HalaPH.',
        primaryActionLabel: 'Start using HalaPH',
        reminderText: 'Guide Mode: Complete',
        requiresUserAction: false,
      ),
    ];
  }
}
