import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTutorialService {
  static final ValueNotifier<int> guideReplayRequests = ValueNotifier<int>(0);

  static void requestGuideModeReplayFromSettings() {
    debugPrint('Guide Mode replay: requested through global app shell');
    guideReplayRequests.value += 1;
  }

  static const String _enabledKey = 'app_tutorial_enabled_on_start';
  static const String _completedKey = 'app_tutorial_completed';

  static Future<bool> isTutorialEnabledOnStart() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  static Future<bool> isGuideModeEnabledOnStart() {
    return isTutorialEnabledOnStart();
  }

  static Future<void> setTutorialEnabledOnStart(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  static Future<void> setGuideModeEnabledOnStart(bool enabled) {
    return setTutorialEnabledOnStart(enabled);
  }

  static Future<bool> isTutorialCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_completedKey) ?? false;
  }

  static Future<void> setTutorialCompleted(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completedKey, completed);
  }

  static Future<bool> shouldShowTutorialOnStart() async {
    return isTutorialEnabledOnStart();
  }

  static Future<bool> shouldShowGuideModeOnStart() {
    return shouldShowTutorialOnStart();
  }
}
