// Global toggles to adapt app behavior when Firebase is unavailable/disabled.
// This helps the autonomous mode preserve usability with offline, in-memory data.
class FirebaseModes {
  // When true, the app should operate in an offline/memory-only mode.
  static bool offline = false;
}
