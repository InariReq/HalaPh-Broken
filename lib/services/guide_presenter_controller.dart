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
  bool _isDisposed = false;

  GuidePresenterSignal? get lastSignal => _lastSignal;
  Destination? get selectedDestination => _selectedDestination;
  bool get isDisposed => _isDisposed;

  bool signal(GuidePresenterSignal signal) {
    if (_isDisposed) {
      debugPrint('GuidePresenterController: ignored $signal after dispose');
      return false;
    }
    _lastSignal = signal;
    notifyListeners();
    return true;
  }

  bool signalSafely(GuidePresenterSignal signal) {
    return this.signal(signal);
  }

  void selectDestination(Destination destination) {
    if (_isDisposed) {
      debugPrint(
        'GuidePresenterController: ignored destination selection after dispose',
      );
      return;
    }
    _selectedDestination = destination;
    signal(GuidePresenterSignal.selectIntramuros);
  }

  void clearSignal() {
    if (_isDisposed) return;
    _lastSignal = null;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _lastSignal = null;
    _selectedDestination = null;
    super.dispose();
  }
}
