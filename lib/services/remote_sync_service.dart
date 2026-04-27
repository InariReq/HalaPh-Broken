import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:halaph/services/auth_service.dart';
import 'package:http/http.dart' as http;

class RemoteSyncService {
  RemoteSyncService._internal();
  static final RemoteSyncService instance = RemoteSyncService._internal();

  static const Duration _timeout = Duration(seconds: 5);

  String get _baseUrl {
    try {
      return (dotenv.env['API_BASE_URL'] ?? '').trim();
    } catch (_) {
      return '';
    }
  }

  bool get isConfigured => _baseUrl.isNotEmpty;

  Future<Map<String, dynamic>?> loadNamespace(String namespace) async {
    if (!isConfigured) return null;
    try {
      final uri = await _syncUri(namespace);
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode == 404) return <String, dynamic>{};
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (error) {
      debugPrint('Remote sync load failed for $namespace: $error');
    }
    return null;
  }

  Future<bool> saveNamespace(
    String namespace,
    Map<String, dynamic> payload,
  ) async {
    if (!isConfigured) return false;
    try {
      final uri = await _syncUri(namespace);
      final response = await http
          .put(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(_timeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (error) {
      debugPrint('Remote sync save failed for $namespace: $error');
      return false;
    }
  }

  Future<Uri> _syncUri(String namespace) async {
    final userId = await AuthService().getCurrentUserIdentifier();
    final base = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    return Uri.parse(
      '$base/sync/${Uri.encodeComponent(userId)}/${Uri.encodeComponent(namespace)}',
    );
  }
}
