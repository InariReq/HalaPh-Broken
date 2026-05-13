import 'package:flutter/foundation.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/services/guide_mode_demo_data.dart';

class GuideModeDemoState {
  static final ValueNotifier<int> version = ValueNotifier<int>(0);

  static bool _intramurosSaved = false;

  static bool get intramurosSaved => _intramurosSaved;

  static void reset() {
    _intramurosSaved = false;
    version.value += 1;
    debugPrint('Guide Mode demo state: reset');
  }

  static void saveIntramurosFavorite() {
    _intramurosSaved = true;
    version.value += 1;
    debugPrint('Guide Mode demo state: Intramuros saved to demo favorites');
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
}
