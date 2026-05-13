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
  static const String reviewFareBreakdown = 'reviewFareBreakdown';
  static const String saveDestinationConcept = 'saveDestinationConcept';
  static const String reviewSavedFavorite = 'reviewSavedFavorite';
  static const String addToSamplePlan = 'addToSamplePlan';
  static const String openPlans = 'openPlans';
  static const String showCollaboration = 'showCollaboration';
  static const String openSettings = 'openSettings';
  static const String selectCommuterType = 'selectCommuterType';
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
        title: 'HalaPH Practice Trip',
        objective: 'Start the Intramuros practice commute.',
        explanation:
            'In this walkthrough, we will plan a sample commute to Intramuros with friends, compare routes, check fares, and turn it into a trip plan.',
        instruction:
            'Tap Start Practice Trip. This is a local Guide Mode demo, so no real favorites, plans, or friend requests are changed.',
        icon: Icons.navigation_rounded,
        type: GuideQuestStepType.explainOnly,
        actionId: GuideQuestActionId.startGuide,
        primaryActionLabel: 'Start Practice Trip',
        reminderText: 'Practice Trip: Start here',
        collapseButtonLabel: 'Start Practice Trip',
        requiresUserAction: false,
        completionMessage: 'Practice Trip started.',
      ),
      GuideQuestStep(
        title: 'Home',
        objective: 'Open Explore.',
        explanation:
            'Home sets the purpose of the trip. For this practice run, you are preparing an Intramuros commute with friends.',
        instruction:
            'After this card moves away, tap Explore in the bottom navigation.',
        icon: Icons.home_rounded,
        type: GuideQuestStepType.tapTarget,
        targetKeyId: exploreTarget,
        actionId: GuideQuestActionId.openExplore,
        isTapTargetStep: true,
        primaryActionLabel: 'Got it',
        reminderText: 'Practice Trip: Tap Explore',
        completionMessage: 'Explore opened.',
      ),
      GuideQuestStep(
        title: 'Explore',
        objective: 'Select Intramuros.',
        explanation:
            'Explore is where the commute story becomes a destination. In Guide Mode it uses local places only, with Intramuros first.',
        instruction:
            'After this card moves away, tap the Intramuros card marked Start here.',
        icon: Icons.explore_rounded,
        type: GuideQuestStepType.liveAction,
        actionId: GuideQuestActionId.selectIntramuros,
        isTapTargetStep: true,
        primaryActionLabel: 'Got it',
        reminderText: 'Practice Trip: Select Intramuros',
        completionMessage: 'Intramuros selected.',
      ),
      GuideQuestStep(
        title: 'Destination Preview',
        objective: 'View route options.',
        explanation:
            'The destination preview turns a place into a decision point: save it, inspect details, or compare commute routes.',
        instruction:
            'Tap View Routes. Guide Mode uses stable local route cards here so the showcase never writes data or runs unstable live route work.',
        icon: Icons.place_rounded,
        type: GuideQuestStepType.liveAction,
        actionId: GuideQuestActionId.viewRoutes,
        demoCardType: GuideQuestDemoCardType.destinationPreview,
        primaryActionLabel: 'Got it',
        reminderText: 'Practice Trip: Tap View Routes',
        completionMessage: 'Route choices opened.',
      ),
      GuideQuestStep(
        title: 'Route Options',
        objective: 'Pick the Jeepney + Train route.',
        explanation:
            'Route cards help commuters compare transport modes, estimated time, fare, confidence labels, and walking effort before leaving.',
        instruction: 'Tap the Recommended Jeepney + Train card.',
        icon: Icons.alt_route_rounded,
        type: GuideQuestStepType.fallbackDemo,
        actionId: GuideQuestActionId.pickRecommendedRoute,
        demoCardType: GuideQuestDemoCardType.routeOptions,
        primaryActionLabel: 'Got it',
        reminderText: 'Practice Trip: Pick recommended route',
        completionMessage: 'Recommended route selected.',
      ),
      GuideQuestStep(
        title: 'Route Guide',
        objective: 'Read route guide steps.',
        explanation:
            'The route guide explains where to board, where to alight, when to transfer, and how walking fits into the commute.',
        instruction: 'Review the steps, then tap Continue to fare breakdown.',
        icon: Icons.directions_rounded,
        type: GuideQuestStepType.fallbackDemo,
        actionId: GuideQuestActionId.continueToFareBreakdown,
        demoCardType: GuideQuestDemoCardType.routeGuide,
        primaryActionLabel: 'Got it',
        reminderText: 'Practice Trip: Continue to fare breakdown',
        completionMessage: 'Route guide reviewed.',
      ),
      GuideQuestStep(
        title: 'Fare Breakdown',
        objective: 'Read the route fare breakdown.',
        explanation:
            'Fare breakdowns separate free walking from paid rides, so commuters can prepare cash and understand the total estimate.',
        instruction:
            'Review the sample fare components, then continue to saving Intramuros.',
        icon: Icons.payments_rounded,
        type: GuideQuestStepType.fallbackDemo,
        actionId: GuideQuestActionId.reviewFareBreakdown,
        demoCardType: GuideQuestDemoCardType.fareBreakdown,
        primaryActionLabel: 'Got it',
        reminderText: 'Practice Trip: Read fare breakdown',
        completionMessage: 'Fare breakdown reviewed.',
      ),
      GuideQuestStep(
        title: 'Save Destination',
        objective: 'Save Intramuros.',
        explanation:
            'Saving a destination keeps it ready for repeat routes, favorites, and future trip plans.',
        instruction:
            'Tap Save destination. This updates Guide Mode state only, not your real account.',
        icon: Icons.favorite_rounded,
        type: GuideQuestStepType.fallbackDemo,
        actionId: GuideQuestActionId.saveDestinationConcept,
        demoCardType: GuideQuestDemoCardType.fareBreakdown,
        primaryActionLabel: 'Got it',
        reminderText: 'Practice Trip: Save Intramuros',
        completionMessage: 'Destination saved in Guide Mode only.',
      ),
      GuideQuestStep(
        title: 'Favorites',
        objective: 'Confirm Intramuros is saved.',
        explanation:
            'Favorites keep useful places ready, so repeat destinations can become routes or trip stops faster.',
        instruction:
            'Review Intramuros in Favorites, then continue to add it to a sample plan.',
        icon: Icons.favorite_rounded,
        type: GuideQuestStepType.fallbackDemo,
        targetKeyId: favoritesTarget,
        actionId: GuideQuestActionId.reviewSavedFavorite,
        demoCardType: GuideQuestDemoCardType.destinationCard,
        primaryActionLabel: 'Continue',
        reminderText: 'Practice Trip: Intramuros is saved',
        completionMessage: 'Saved favorite reviewed.',
        requiresUserAction: false,
      ),
      GuideQuestStep(
        title: 'Add to Plan',
        objective: 'Add Intramuros to a sample plan.',
        explanation:
            'A saved place becomes more useful when it is turned into a trip stop with dates, budget, and reminders.',
        instruction:
            'Tap Add to sample plan. Guide Mode creates only local walkthrough state.',
        icon: Icons.favorite_rounded,
        type: GuideQuestStepType.confirmWriteAction,
        targetKeyId: favoritesTarget,
        actionId: GuideQuestActionId.addToSamplePlan,
        demoCardType: GuideQuestDemoCardType.destinationCard,
        isTapTargetStep: true,
        primaryActionLabel: 'Got it',
        reminderText: 'Practice Trip: Add to sample plan',
        requiresConfirmation: true,
        completionMessage: 'Added to the sample plan in Guide Mode only.',
      ),
      GuideQuestStep(
        title: 'My Plans',
        objective: 'Review the Intramuros Practice Trip.',
        explanation:
            'Plans turn route ideas into an itinerary with stops, travel budget, and reminders.',
        instruction:
            'Review the sample plan, then continue to the collaboration preview.',
        icon: Icons.event_note_rounded,
        type: GuideQuestStepType.fallbackDemo,
        targetKeyId: plansTarget,
        actionId: GuideQuestActionId.openPlans,
        demoCardType: GuideQuestDemoCardType.plan,
        isTapTargetStep: true,
        primaryActionLabel: 'Got it',
        reminderText: 'Practice Trip: Review My Plans',
        completionMessage: 'Sample plan reviewed.',
      ),
      GuideQuestStep(
        title: 'Collaboration',
        objective: 'Preview shared planning with friends.',
        explanation:
            'Shared planning helps friends coordinate the same itinerary while each participant can keep a different starting point.',
        instruction: 'Review the friends preview. No friend request is sent.',
        icon: Icons.groups_rounded,
        type: GuideQuestStepType.fallbackDemo,
        targetKeyId: friendsTarget,
        actionId: GuideQuestActionId.showCollaboration,
        demoCardType: GuideQuestDemoCardType.collaboration,
        isTapTargetStep: true,
        primaryActionLabel: 'Got it',
        reminderText: 'Practice Trip: Preview collaboration',
        completionMessage: 'Collaboration preview reviewed.',
      ),
      GuideQuestStep(
        title: 'Settings and Profile',
        objective: 'Open Profile and Settings controls.',
        explanation:
            'Profile and Settings keep commuter type, account options, reminders, and Guide Mode controls in one place.',
        instruction:
            'Review the Profile screen, then continue to commuter type selection.',
        icon: Icons.settings_rounded,
        type: GuideQuestStepType.explainOnly,
        targetKeyId: profileTarget,
        actionId: GuideQuestActionId.openSettings,
        isTapTargetStep: true,
        primaryActionLabel: 'Continue',
        reminderText: 'Practice Trip: Open Profile',
        requiresUserAction: false,
        completionMessage: 'Profile controls reviewed.',
      ),
      GuideQuestStep(
        title: 'Commuter Type',
        objective: 'Select a local fare type.',
        explanation:
            'Commuter type helps HalaPH explain fare estimates for riders such as students, seniors, PWD commuters, and regular passengers.',
        instruction:
            'Select Student or another commuter type. This changes Guide Mode fare state only.',
        icon: Icons.confirmation_number_rounded,
        type: GuideQuestStepType.confirmWriteAction,
        actionId: GuideQuestActionId.selectCommuterType,
        demoCardType: GuideQuestDemoCardType.fareBreakdown,
        primaryActionLabel: 'Got it',
        reminderText: 'Practice Trip: Select commuter type',
        requiresConfirmation: true,
        completionMessage: 'Commuter type selected in Guide Mode only.',
      ),
      GuideQuestStep(
        title: 'Practice Trip Complete',
        objective: 'Finish the Intramuros Practice Trip.',
        explanation:
            'You completed your Intramuros Practice Trip. You chose a destination, compared routes, checked fares, saved a favorite, created a sample plan, previewed collaboration, and set a commuter type.',
        instruction: 'Start using HalaPH now, or replay the Practice Trip.',
        icon: Icons.emoji_events_rounded,
        type: GuideQuestStepType.finish,
        actionId: GuideQuestActionId.finish,
        demoCardType: GuideQuestDemoCardType.finish,
        completionLabel: 'Practice Trip complete',
        completionMessage:
            'Practice Trip complete. You are ready to use HalaPH.',
        primaryActionLabel: 'Start using HalaPH',
        reminderText: 'Practice Trip: Complete',
        requiresUserAction: false,
      ),
    ];
  }
}
