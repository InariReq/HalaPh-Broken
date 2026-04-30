class AppConfig {
  static bool testModeEnabled = false;
  static bool get disableAllApiCalls => testModeEnabled;

  static void setTestMode(bool enabled) {
    testModeEnabled = enabled;
    print('🧪 AppConfig: Test Mode ${enabled ? 'ENABLED' : 'DISABLED'}');
  }
}
