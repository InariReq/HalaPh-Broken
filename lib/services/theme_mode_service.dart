import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeModeService {
  static const String _preferenceKey = 'hala_theme_mode';

  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedValue = prefs.getString(_preferenceKey);
    themeMode.value = _parseThemeMode(savedValue);
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferenceKey, mode.name);
  }

  static String labelFor(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System Default';
      case ThemeMode.light:
        return 'Light Mode';
      case ThemeMode.dark:
        return 'Dark Mode';
    }
  }

  static String descriptionFor(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Follow your device appearance.';
      case ThemeMode.light:
        return 'Use the bright white theme.';
      case ThemeMode.dark:
        return 'Use the black and grey theme.';
    }
  }

  static ThemeMode _parseThemeMode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}
