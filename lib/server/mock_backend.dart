import 'dart:convert';
import 'dart:io';
import 'package:halaph/models/user.dart';

class MockBackendServer {
  final int port;
  HttpServer? _server;
  // ignore: unused_field
  String? _token;
  final Map<String, User> _tokensToUsers = {};
  final Map<String, Map<String, dynamic>> _plansById = {};
  final Map<String, Map<String, dynamic>> _syncPayloads = {};
  late final File _storageFile;

  MockBackendServer({this.port = 8080, File? storageFile}) {
    _storageFile = storageFile ?? File('.halaph_mock_backend.json');
  }

  Future<void> start() async {
    await _loadFromDisk();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server = server;
    server.listen((HttpRequest request) async {
      final path = request.uri.path;
      final method = request.method;
      request.response.headers.contentType = ContentType.json;
      try {
        if (method == 'OPTIONS') {
          request.response.statusCode = 204;
        } else if (path == '/login' && method == 'POST') {
          final body = await utf8.decoder.bind(request).join();
          final data = json.decode(body);
          final email = data['email'];
          final name = email != null
              ? email.toString().split('@').first
              : 'user';
          final user = User(email: email, name: name);
          final token = 'token_$email';
          _token = token;
          _tokensToUsers[token] = user;
          request.response
            ..statusCode = 200
            ..write(
              jsonEncode({
                'token': token,
                'user': {'email': user.email, 'name': user.name},
              }),
            );
        } else if (path == '/register' && method == 'POST') {
          final body = await utf8.decoder.bind(request).join();
          final data = json.decode(body);
          final email = data['email'];
          final name = email != null
              ? email.toString().split('@').first
              : 'user';
          final user = User(email: email, name: name);
          final token = 'token_$email';
          _token = token;
          _tokensToUsers[token] = user;
          request.response
            ..statusCode = 200
            ..write(
              jsonEncode({
                'token': token,
                'user': {'email': user.email, 'name': user.name},
              }),
            );
        } else if (path == '/me' && method == 'GET') {
          final auth = request.headers.value('Authorization');
          if (auth != null && auth.startsWith('Bearer ')) {
            final token = auth.substring(7);
            final user = _tokensToUsers[token];
            if (user != null) {
              request.response
                ..statusCode = 200
                ..write(jsonEncode({'email': user.email, 'name': user.name}));
              return;
            }
          }
          request.response.statusCode = 401;
          request.response.close();
        } else if (path == '/plans' && method == 'GET') {
          final token = request.headers.value('Authorization')?.split(' ').last;
          if (token == null || !_tokensToUsers.containsKey(token)) {
            request.response.statusCode = 401;
            request.response.close();
            return;
          }
          request.response
            ..statusCode = 200
            ..write(jsonEncode(_plansById.values.toList()));
        } else if (path == '/plans' && method == 'POST') {
          final body = await utf8.decoder.bind(request).join();
          final data = json.decode(body) as Map<String, dynamic>;
          final id =
              data['id'] ?? 'plan_${DateTime.now().millisecondsSinceEpoch}';
          data['id'] = id;
          _plansById[id] = data;
          await _saveToDisk();
          request.response
            ..statusCode = 200
            ..write(jsonEncode(data));
        } else if (path.startsWith('/plans/') &&
            path.endsWith('/share') &&
            method == 'POST') {
          final segments = path.split('/');
          final planId = segments.length > 2 ? segments[2] : '';
          final link = 'http://localhost:$port/plans/$planId';
          request.response
            ..statusCode = 200
            ..write(jsonEncode({'link': link}));
        } else if (path.startsWith('/plans/') && method == 'GET') {
          final segments = path.split('/');
          final id = segments.length > 2 ? segments[2] : '';
          final plan = _plansById[id];
          if (plan != null) {
            request.response
              ..statusCode = 200
              ..write(jsonEncode(plan));
          } else {
            request.response.statusCode = 404;
          }
        } else if (path.startsWith('/sync/') && method == 'GET') {
          final key = _syncKeyFromPath(path);
          final payload = _syncPayloads[key];
          if (payload == null) {
            request.response.statusCode = 404;
          } else {
            request.response
              ..statusCode = 200
              ..write(jsonEncode(payload));
          }
        } else if (path.startsWith('/sync/') && method == 'PUT') {
          final key = _syncKeyFromPath(path);
          final body = await utf8.decoder.bind(request).join();
          final decoded = jsonDecode(body);
          if (decoded is! Map) {
            request.response.statusCode = 400;
          } else {
            final payload = Map<String, dynamic>.from(decoded);
            _syncPayloads[key] = payload;
            await _saveToDisk();
            request.response
              ..statusCode = 200
              ..write(jsonEncode(payload));
          }
        } else {
          request.response.statusCode = 404;
        }
      } catch (e) {
        request.response
          ..statusCode = 500
          ..write(jsonEncode({'error': e.toString()}));
      } finally {
        request.response.close();
      }
    });
  }

  Future<void> stop() async {
    await _server?.close();
  }

  String _syncKeyFromPath(String path) {
    final segments = path.split('/');
    if (segments.length < 4) {
      throw const FormatException('Expected /sync/<userId>/<namespace>');
    }
    final userId = Uri.decodeComponent(segments[2]);
    final namespace = Uri.decodeComponent(segments[3]);
    return '$userId::$namespace';
  }

  Future<void> _loadFromDisk() async {
    if (!await _storageFile.exists()) return;
    try {
      final decoded = jsonDecode(await _storageFile.readAsString());
      if (decoded is! Map) return;

      final plans = decoded['plans'];
      if (plans is List) {
        for (final entry in plans.whereType<Map>()) {
          final plan = Map<String, dynamic>.from(entry);
          final id = plan['id']?.toString();
          if (id != null && id.isNotEmpty) {
            _plansById[id] = plan;
          }
        }
      }

      final sync = decoded['sync'];
      if (sync is Map) {
        for (final entry in sync.entries) {
          if (entry.value is Map) {
            _syncPayloads[entry.key.toString()] = Map<String, dynamic>.from(
              entry.value as Map,
            );
          }
        }
      }
    } catch (_) {
      // Corrupt dev storage should not prevent the mock backend from starting.
    }
  }

  Future<void> _saveToDisk() async {
    final payload = {
      'plans': _plansById.values.toList(),
      'sync': _syncPayloads,
    };
    await _storageFile.writeAsString(jsonEncode(payload));
  }
}
