import 'package:flutter/foundation.dart';

enum DevMode { online, offline, emulator }

class DevModeService {
  static const bool paidGoogleApisEnabled = false;

  static bool get allowPaidGoogleApis => paidGoogleApisEnabled;

  static final ValueNotifier<DevMode> current =
      ValueNotifier<DevMode>(DevMode.online);

  static void set(DevMode mode) {
    current.value = mode;
  }
}
