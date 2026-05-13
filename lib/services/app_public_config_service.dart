import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:halaph/models/app_public_config.dart';

class AppPublicConfigService {
  static const Duration _readTimeout = Duration(seconds: 4);
  static AppPublicConfig _cachedConfig = const AppPublicConfig.defaults();

  final FirebaseFirestore _firestore;

  AppPublicConfigService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static AppPublicConfig get cachedConfig => _cachedConfig;

  DocumentReference<Map<String, dynamic>> get _document => _firestore
      .collection(AppPublicConfig.collectionPath)
      .doc(AppPublicConfig.documentId);

  Future<AppPublicConfig> loadPublicConfig() async {
    try {
      final snapshot = await _document.get().timeout(_readTimeout);
      final config = AppPublicConfig.fromSnapshot(snapshot);
      _cachedConfig = config;
      return config;
    } on TimeoutException catch (error) {
      debugPrint('App public config read timed out: $error');
      return const AppPublicConfig.defaults();
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        debugPrint('App public config read denied; using defaults.');
      } else {
        debugPrint('App public config read failed: ${error.code}');
      }
      return const AppPublicConfig.defaults();
    } catch (error) {
      debugPrint('App public config read failed: $error');
      return const AppPublicConfig.defaults();
    }
  }
}
