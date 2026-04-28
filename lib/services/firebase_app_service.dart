import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../firebase_options.dart';

class FirebaseAppService {
  FirebaseAppService._();

  static Future<bool>? _initialization;

  static bool get isInitialized => Firebase.apps.isNotEmpty;

  static bool get hasEnvConfiguration {
    return _env('FIREBASE_API_KEY').isNotEmpty &&
        _env('FIREBASE_PROJECT_ID').isNotEmpty &&
        _env('FIREBASE_APP_ID').isNotEmpty &&
        _env('FIREBASE_MESSAGING_SENDER_ID').isNotEmpty;
  }

  static Future<bool> initialize() {
    return _initialization ??= _initialize();
  }

  static Future<bool> _initialize() async {
    if (Firebase.apps.isNotEmpty) return true;

    try {
      final options = _optionsFromEnv() ?? _optionsFromGeneratedConfig();
      if (options != null) {
        await Firebase.initializeApp(options: options);
      } else {
        await Firebase.initializeApp();
      }
      debugPrint('Firebase initialized.');
      return true;
    } catch (error) {
      debugPrint('Firebase not configured; cloud sync disabled: $error');
      return false;
    }
  }

  static FirebaseOptions? _optionsFromEnv() {
    if (!hasEnvConfiguration) return null;

    return FirebaseOptions(
      apiKey: _env('FIREBASE_API_KEY'),
      appId: _env('FIREBASE_APP_ID'),
      messagingSenderId: _env('FIREBASE_MESSAGING_SENDER_ID'),
      projectId: _env('FIREBASE_PROJECT_ID'),
      authDomain: _emptyToNull(_env('FIREBASE_AUTH_DOMAIN')),
      storageBucket: _emptyToNull(_env('FIREBASE_STORAGE_BUCKET')),
      measurementId: _emptyToNull(_env('FIREBASE_MEASUREMENT_ID')),
      iosBundleId: _emptyToNull(_env('FIREBASE_IOS_BUNDLE_ID')),
      androidClientId: _emptyToNull(_env('FIREBASE_ANDROID_CLIENT_ID')),
    );
  }

  static FirebaseOptions? _optionsFromGeneratedConfig() {
    try {
      return DefaultFirebaseOptions.currentPlatform;
    } catch (error) {
      debugPrint('Generated Firebase options unavailable: $error');
      return null;
    }
  }

  static String _env(String key) {
    try {
      return (dotenv.env[key] ?? '').trim();
    } catch (_) {
      return '';
    }
  }

  static String? _emptyToNull(String value) {
    return value.isEmpty ? null : value;
  }
}
