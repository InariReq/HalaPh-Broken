import 'package:flutter/foundation.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/services/guide_mode_demo_data.dart';

class GuideModeDemoState {
  static final ValueNotifier<int> version = ValueNotifier<int>(0);

  static GuideModeDemoDestination? _selectedDestination;
  static GuideModeDemoRouteOption? _selectedRoute;
  static bool _destinationDetailsOpened = false;
  static bool _viewRoutesTapped = false;
  static bool _routeViewed = false;
  static bool _fareViewed = false;
  static bool _intramurosSaved = false;
  static bool _createPlanStarted = false;
  static bool _samplePlanAdded = false;
  static bool _collaboratorsOpened = false;
  static List<String> _selectedCollaborators = const [];
  static bool _collaborationPreviewSeen = false;
  static bool _guideFinished = false;
  static String _commuterType = 'Regular';
  static String _currentObjective = 'Start Practice Trip';

  static GuideModeDemoDestination? get selectedDestination =>
      _selectedDestination;
  static GuideModeDemoRouteOption? get selectedRoute => _selectedRoute;
  static bool get destinationDetailsOpened => _destinationDetailsOpened;
  static bool get viewRoutesTapped => _viewRoutesTapped;
  static bool get routeViewed => _routeViewed;
  static bool get fareViewed => _fareViewed;
  static bool get intramurosSaved => _intramurosSaved;
  static bool get createPlanStarted => _createPlanStarted;
  static bool get samplePlanAdded => _samplePlanAdded;
  static bool get collaboratorsOpened => _collaboratorsOpened;
  static List<String> get selectedCollaborators =>
      List<String>.unmodifiable(_selectedCollaborators);
  static bool get hasSelectedCollaborators => _selectedCollaborators.isNotEmpty;
  static bool get collaborationPreviewSeen => _collaborationPreviewSeen;
  static bool get guideFinished => _guideFinished;
  static String get commuterType => _commuterType;
  static bool get commuterTypeSelected => _commuterType != 'Regular';
  static String get currentObjective => _currentObjective;

  static void reset() {
    _selectedDestination = null;
    _selectedRoute = null;
    _destinationDetailsOpened = false;
    _viewRoutesTapped = false;
    _routeViewed = false;
    _fareViewed = false;
    _intramurosSaved = false;
    _createPlanStarted = false;
    _samplePlanAdded = false;
    _collaboratorsOpened = false;
    _selectedCollaborators = const [];
    _collaborationPreviewSeen = false;
    _guideFinished = false;
    _commuterType = 'Regular';
    _currentObjective = 'Start Practice Trip';
    version.value += 1;
    debugPrint('Guide Mode demo state: reset');
  }

  static void setObjective(String objective) {
    _currentObjective = objective;
    version.value += 1;
  }

  static void selectIntramuros() {
    _selectedDestination = GuideModeDemoData.destinations.first;
    _currentObjective = 'Open Intramuros details';
    version.value += 1;
    debugPrint('Guide Mode demo state: Intramuros selected');
  }

  static void openDestinationDetails() {
    if (_destinationDetailsOpened) {
      return;
    }
    _destinationDetailsOpened = true;
    _currentObjective = 'Tap View Routes';
    version.value += 1;
    debugPrint('Guide Mode demo state: Intramuros details opened');
  }

  static void viewRoutes() {
    _viewRoutesTapped = true;
    _routeViewed = true;
    _currentObjective = 'Pick recommended route';
    version.value += 1;
    debugPrint('Guide Mode demo state: route options viewed');
  }

  static void selectRecommendedRoute() {
    _selectedRoute =
        GuideModeDemoData.routeOptions.firstWhere((route) => route.recommended);
    _currentObjective = 'Read route guide';
    version.value += 1;
    debugPrint('Guide Mode demo state: recommended route selected');
  }

  static void viewFareBreakdown() {
    _fareViewed = true;
    _currentObjective = 'Save destination';
    version.value += 1;
    debugPrint('Guide Mode demo state: fare breakdown viewed');
  }

  static void saveIntramurosFavorite() {
    _intramurosSaved = true;
    _currentObjective = 'Visit Favorites';
    version.value += 1;
    debugPrint('Guide Mode demo state: Intramuros saved to demo favorites');
  }

  static void addSamplePlan() {
    _createPlanStarted = true;
    _samplePlanAdded = true;
    _currentObjective = 'Add demo collaborators';
    version.value += 1;
    debugPrint('Guide Mode demo state: sample plan added');
  }

  static void startCreatePlan() {
    _createPlanStarted = true;
    _currentObjective = 'Create Intramuros Practice Trip';
    version.value += 1;
    debugPrint('Guide Mode demo state: plan creation started');
  }

  static void openCollaborators() {
    _collaboratorsOpened = true;
    _currentObjective = 'Select demo collaborators';
    version.value += 1;
    debugPrint('Guide Mode demo state: collaborators opened');
  }

  static void setSelectedCollaborators(List<String> names) {
    _collaboratorsOpened = true;
    _selectedCollaborators = List<String>.unmodifiable(names);
    _currentObjective = 'Review My Plans';
    version.value += 1;
    debugPrint(
      'Guide Mode demo state: collaborators selected: ${names.join(', ')}',
    );
  }

  static void showCollaborationPreview() {
    _collaborationPreviewSeen = true;
    _currentObjective = 'Open Settings';
    version.value += 1;
    debugPrint('Guide Mode demo state: collaboration preview seen');
  }

  static void selectCommuterType(String type) {
    _commuterType = type;
    _currentObjective = 'Finish Practice Trip';
    version.value += 1;
    debugPrint('Guide Mode demo state: commuter type selected: $type');
  }

  static void finishGuide() {
    _guideFinished = true;
    _currentObjective = 'Practice Trip complete';
    version.value += 1;
    debugPrint('Guide Mode demo state: Practice Trip finished');
  }

  static void restoreForStep(int stepIndex) {
    final preservedCommuterType = _commuterType;
    reset();
    if (stepIndex >= 2) selectIntramuros();
    if (stepIndex >= 2) openDestinationDetails();
    if (stepIndex >= 3) viewRoutes();
    if (stepIndex >= 4) selectRecommendedRoute();
    if (stepIndex >= 5) viewFareBreakdown();
    if (stepIndex >= 6) saveIntramurosFavorite();
    if (stepIndex >= 8) addSamplePlan();
    if (stepIndex >= 9) setSelectedCollaborators(const ['Alex']);
    if (stepIndex >= 10) showCollaborationPreview();
    if (stepIndex >= 11) selectCommuterType(preservedCommuterType);
  }

  static List<Destination> favoriteDestinations() {
    if (!_intramurosSaved) return const [];
    final destinations = GuideModeDemoData.destinationsForGuideExplore();
    return destinations
        .where((destination) =>
            destination.name.toLowerCase().contains('intramuros'))
        .take(1)
        .toList(growable: false);
  }

  static List<GuideModeDemoFareLine> fareBreakdown() {
    return GuideModeDemoData.fareBreakdownForCommuterType(_commuterType);
  }
}
