import 'package:flutter/foundation.dart';

import '../models/destination.dart';

enum GuidePresenterScene {
  welcome,
  home,
  explore,
  destinationPreview,
  routeOptions,
  routeGuide,
  fareBreakdown,
  favorites,
  plans,
  collaboration,
  reminders,
  tripHistory,
  settings,
  finish,
}

enum GuidePresenterSignal {
  openExplore,
  selectIntramuros,
  openFavorites,
  openPlans,
  openFriends,
  openSettings,
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
