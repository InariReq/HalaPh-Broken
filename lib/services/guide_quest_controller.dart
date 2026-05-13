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
  static const String createSamplePlan = 'createSamplePlan';
  static const String addCollaborators = 'addCollaborators';
  static const String reviewSamplePlan = 'reviewSamplePlan';
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
        title: 'Intramuros Details',
        objective: 'View route options.',
        explanation:
            'The destination preview turns a place into a decision point: save it, inspect details, or compare commute routes.',
        instruction:
            'Tap View Routes in the Intramuros details sheet. Guide Mode uses stable local route cards here, while normal mode still uses live routes.',
        icon: Icons.place_rounded,
        type: GuideQuestStepType.liveAction,
        actionId: GuideQuestActionId.viewRoutes,
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
        primaryActionLabel: 'Got it',
        reminderText: 'Practice Trip: Continue to fare breakdown',
        completionMessage: 'Route guide reviewed.',
      ),
      GuideQuestStep(
        title: 'Fare Breakdown',
        objective: 'Check the fare estimate and save Intramuros.',
        explanation:
            'Fare breakdowns separate free walking from paid rides, so commuters can prepare cash and understand the total estimate.',
        instruction:
            'Review the fare components, then tap Save Destination. This saves only Guide Mode state.',
        icon: Icons.payments_rounded,
        type: GuideQuestStepType.fallbackDemo,
        actionId: GuideQuestActionId.saveDestinationConcept,
        primaryActionLabel: 'Got it',
        reminderText: 'Practice Trip: Save Intramuros',
        completionMessage: 'Destination saved in Guide Mode only.',
      ),
      GuideQuestStep(
        title: 'Favorites',
        objective: 'Add Intramuros to a plan.',
        explanation:
            'Favorites keep useful places ready, so repeat destinations can become routes or trip stops faster.',
        instruction:
            'Intramuros appears here only because you tapped Save Destination. Tap Add to Plan.',
        icon: Icons.favorite_rounded,
        type: GuideQuestStepType.confirmWriteAction,
        targetKeyId: favoritesTarget,
        actionId: GuideQuestActionId.addToSamplePlan,
        isTapTargetStep: true,
        primaryActionLabel: 'Got it',
        reminderText: 'Practice Trip: Add to sample plan',
        requiresConfirmation: true,
        completionMessage: 'Plan creation opened.',
      ),
      GuideQuestStep(
        title: 'Create Plan',
        objective: 'Create the Intramuros Practice Trip.',
        explanation:
            'A plan turns the destination into a scheduled trip with stops, budget, and reminders.',
        instruction:
            'Review the prefilled local fields, then tap Create Plan. No Firestore document is written.',
        icon: Icons.add_task_rounded,
        type: GuideQuestStepType.confirmWriteAction,
        actionId: GuideQuestActionId.createSamplePlan,
        primaryActionLabel: 'Got it',
        reminderText: 'Practice Trip: Tap Create Plan',
        requiresConfirmation: true,
        completionMessage: 'Sample plan created locally.',
      ),
      GuideQuestStep(
        title: 'Add Collaborators',
        objective: 'Invite demo collaborators.',
        explanation:
            'Shared plans help friends coordinate the same trip while keeping each person’s starting point flexible.',
        instruction:
            'Tap Add Collaborators, select at least one demo friend, then confirm.',
        icon: Icons.group_add_rounded,
        type: GuideQuestStepType.confirmWriteAction,
        targetKeyId: plansTarget,
        actionId: GuideQuestActionId.addCollaborators,
        primaryActionLabel: 'Got it',
        reminderText: 'Practice Trip: Add collaborators',
        requiresConfirmation: true,
        completionMessage: 'Demo collaborators added locally.',
      ),
      GuideQuestStep(
        title: 'My Plans',
        objective: 'Review the Intramuros Practice Trip.',
        explanation:
            'Plans show the date, reminders, saved stops, and collaboration context for a trip.',
        instruction: 'Tap the Intramuros Practice Trip card or Continue.',
        icon: Icons.event_note_rounded,
        type: GuideQuestStepType.fallbackDemo,
        targetKeyId: plansTarget,
        actionId: GuideQuestActionId.reviewSamplePlan,
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
        isTapTargetStep: true,
        primaryActionLabel: 'Got it',
        reminderText: 'Practice Trip: Preview collaboration',
        completionMessage: 'Collaboration preview reviewed.',
      ),
      GuideQuestStep(
        title: 'Settings and Profile',
        objective: 'Select a local fare type.',
        explanation:
            'Commuter type helps HalaPH explain fare estimates for riders such as students, seniors, PWD commuters, and regular passengers.',
        instruction:
            'Select Student or another commuter type. This updates Guide Mode state only.',
        icon: Icons.confirmation_number_rounded,
        type: GuideQuestStepType.confirmWriteAction,
        targetKeyId: profileTarget,
        actionId: GuideQuestActionId.selectCommuterType,
        isTapTargetStep: true,
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
