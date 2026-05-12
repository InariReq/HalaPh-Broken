import 'package:shared_preferences/shared_preferences.dart';

class AppTutorialService {
  static const String _enabledKey = 'app_tutorial_enabled_on_start';
  static const String _completedKey = 'app_tutorial_completed';

  static Future<bool> isTutorialEnabledOnStart() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  static Future<void> setTutorialEnabledOnStart(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
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
    final enabled = await isTutorialEnabledOnStart();
    if (!enabled) return false;
    return !await isTutorialCompleted();
  }
}
