import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../firebase_options.dart';
import 'package:halaph/utils/firebase_modes.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

class FirebaseAppService {
  FirebaseAppService._();

  static bool get isInitialized => Firebase.apps.isNotEmpty;

  static bool get hasEnvConfiguration {
    return _env('FIREBASE_API_KEY').isNotEmpty &&
        _env('FIREBASE_PROJECT_ID').isNotEmpty &&
        _env('FIREBASE_APP_ID').isNotEmpty &&
        _env('FIREBASE_MESSAGING_SENDER_ID').isNotEmpty;
  }

  static Future<bool> initialize({bool forceRetry = false}) async {
    if (Firebase.apps.isNotEmpty) {
      // Ensure Realtime Database URL is set
      _initializeDatabase();
      return true;
    }
    if (forceRetry) _initialization = null;

    final initialization = _initialization ??= _doInitialize();
    final success = await initialization;
    if (!success && identical(_initialization, initialization)) {
      _initialization = null;
    }
    // If Firebase failed to initialize, enable offline mode to keep app usable
    if (!success) {
      FirebaseModes.offline = true;
    }
    return success;
  }

  static Future<bool>? _initialization;
  static Future<bool> _doInitialize() async {
    if (Firebase.apps.isNotEmpty) return true;

    try {
      final options = _optionsFromEnv() ?? _optionsFromGeneratedConfig();
      if (options != null) {
        await Firebase.initializeApp(options: options);
        debugPrint('Firebase initialized for project ${options.projectId}.');
      } else {
        await Firebase.initializeApp();
        debugPrint('Firebase initialized with native platform config.');
      }
      
      // Enable Firestore offline persistence
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      
      // Initialize Realtime Database
      _initializeDatabase();
      // Optionally connect to Firebase emulators if configured and not offline
      if (!FirebaseModes.offline && _shouldUseEmulators()) {
        try {
          FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
        } catch (_) {
          // ignore emulator connection errors
        }
        try {
          firebase_auth.FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
        } catch (_) {
          // ignore emulator connection errors
        }
        try {
          FirebaseDatabase.instance.useDatabaseEmulator('localhost', 9000);
        } catch (_) {
          // ignore emulator connection errors
        }
      }
      return true;
    } catch (error) {
      debugPrint('Firebase not configured; cloud sync disabled: $error');
      return false;
    }
  }

  static bool _shouldUseEmulators() {
    final v1 = (dotenv.env['USE_FIREBASE_EMULATORS'] ?? '').toLowerCase();
    final v2 = (dotenv.env['FIREBASE_EMULATORS'] ?? '').toLowerCase();
    if (v1 == 'true' || v2 == 'true') return true;
    // Default: do not use emulators unless explicitly enabled
    return false;
  }

  static void _initializeDatabase() {
    try {
      FirebaseDatabase.instance.databaseURL =
          'https://halaph-d4eaa-default-rtdb.asia-southeast1.firebasedatabase.app/';
    } catch (e) {
      debugPrint('Realtime Database initialization skipped: $e');
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
