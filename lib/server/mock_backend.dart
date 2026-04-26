import 'dart:convert';
import 'dart:io';
import 'package:halaph/models/plan.dart';
import 'package:halaph/models/user.dart';

class MockBackendServer {
  final int port;
  HttpServer? _server;
  String? _token;
  final Map<String, User> _tokensToUsers = {};
  final Map<String, TravelPlan> _plansById = {};

  MockBackendServer({this.port = 8080});

  Future<void> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server = server;
    server.listen((HttpRequest request) async {
      final path = request.uri.path;
      final method = request.method;
      request.response.headers.contentType = ContentType.json;
      try {
        if (path == '/login' && method == 'POST') {
          final body = await utf8.decoder.bind(request).join();
          final data = json.decode(body);
          final email = data['email'];
          final name = email != null ? email.toString().split('@').first : 'user';
          final user = User(email: email, name: name);
          final token = 'token_$email';
          _token = token;
          _tokensToUsers[token] = user;
          request.response
            ..statusCode = 200
            ..write(jsonEncode({'token': token, 'user': {'email': user.email, 'name': user.name}}));
        } else if (path == '/register' && method == 'POST') {
          final body = await utf8.decoder.bind(request).join();
          final data = json.decode(body);
          final email = data['email'];
          final name = email != null ? email.toString().split('@').first : 'user';
          final user = User(email: email, name: name);
          final token = 'token_$email';
          _token = token;
          _tokensToUsers[token] = user;
          request.response
            ..statusCode = 200
            ..write(jsonEncode({'token': token, 'user': {'email': user.email, 'name': user.name}}));
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
          request.response ..statusCode = 401;
          request.response.close();
        } else if (path == '/plans' && method == 'GET') {
          final token = request.headers.value('Authorization')?.split(' ' ).last;
          if (token == null || !_tokensToUsers.containsKey(token)) {
            request.response ..statusCode = 401;
            request.response.close();
            return;
          }
          request.response
            ..statusCode = 200
            ..write(jsonEncode(_plansById.values.map((p)=>p.toJson()).toList()));
        } else if (path == '/plans' && method == 'POST') {
          final body = await utf8.decoder.bind(request).join();
          final data = json.decode(body) as Map<String, dynamic>;
          final id = data['id'] ?? 'plan_${DateTime.now().millisecondsSinceEpoch}';
          final plan = TravelPlan.fromJson(data..['id'] = id);
          _plansById[id] = plan;
          request.response
            ..statusCode = 200
            ..write(jsonEncode(plan.toJson()));
        } else if (path.startsWith('/plans/') && path.endsWith('/share') && method == 'POST') {
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
              ..write(jsonEncode(plan.toJson()));
          } else {
            request.response ..statusCode = 404;
          }
        } else {
          request.response ..statusCode = 404;
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
}
