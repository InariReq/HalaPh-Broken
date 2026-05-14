import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BrandColorMode {
  navy,
  burgundy,
  system,
}

class ThemeModeService {
  static const String _preferenceKey = 'hala_theme_mode';
  static const String _brandPreferenceKey = 'hala_brand_color_mode';

  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.system);
  static final ValueNotifier<BrandColorMode> brandColorMode =
      ValueNotifier<BrandColorMode>(BrandColorMode.navy);

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedValue = prefs.getString(_preferenceKey);
    themeMode.value = _parseThemeMode(savedValue);
    brandColorMode.value =
        _parseBrandColorMode(prefs.getString(_brandPreferenceKey));
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferenceKey, mode.name);
  }

  static Future<void> setBrandColorMode(BrandColorMode mode) async {
    brandColorMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_brandPreferenceKey, mode.name);
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

  static String labelForBrand(BrandColorMode mode) {
    switch (mode) {
      case BrandColorMode.navy:
        return 'Navy';
      case BrandColorMode.burgundy:
        return 'Burgundy';
      case BrandColorMode.system:
        return 'System Default';
    }
  }

  static String descriptionForBrand(BrandColorMode mode) {
    switch (mode) {
      case BrandColorMode.navy:
        return 'Default HalaPH transport accent.';
      case BrandColorMode.burgundy:
        return 'Warm premium accent with navy contrast.';
      case BrandColorMode.system:
        return 'Use the recommended HalaPH default: Navy.';
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

  static BrandColorMode _parseBrandColorMode(String? value) {
    switch (value) {
      case 'burgundy':
        return BrandColorMode.burgundy;
      case 'system':
        return BrandColorMode.system;
      case 'navy':
      default:
        return BrandColorMode.navy;
    }
  }
}
