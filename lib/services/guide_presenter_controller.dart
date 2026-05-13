import 'package:flutter/foundation.dart';

import '../models/destination.dart';

enum GuidePresenterScene {
  practiceIntro,
  homeIntro,
  explore,
  chooseDestination,
  destinationPreview,
  routeOptions,
  routeGuide,
  fareBreakdown,
  saveDestination,
  favorites,
  addToPlan,
  plans,
  collaboration,
  profile,
  commuterType,
  finishSummary,
}

enum GuidePresenterSignal {
  openExplore,
  selectIntramuros,
  destinationDetailsOpened,
  viewRoutesTapped,
  routeSelected,
  fareBreakdownOpened,
  destinationSaved,
  openFavorites,
  addToPlanStarted,
  samplePlanCreated,
  collaboratorsOpened,
  collaboratorsConfirmed,
  samplePlanReviewed,
  openPlans,
  collaborationPreviewSeen,
  openFriends,
  openSettings,
  commuterTypeSelected,
}

class GuidePresenterController extends ChangeNotifier {
  GuidePresenterSignal? _lastSignal;
  Destination? _selectedDestination;

  GuidePresenterSignal? get lastSignal => _lastSignal;
  Destination? get selectedDestination => _selectedDestination;

  void signal(GuidePresenterSignal signal) {
    _lastSignal = signal;
    notifyListeners();
  }

  void selectDestination(Destination destination) {
    _selectedDestination = destination;
    signal(GuidePresenterSignal.selectIntramuros);
  }

  void clearSignal() {
    _lastSignal = null;
  }
}
