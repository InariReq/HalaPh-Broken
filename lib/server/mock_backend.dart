import 'dart:convert';
import 'dart:io';

class MockBackendServer {
  final int port;
  HttpServer? _server;

  MockBackendServer({required this.port});

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server!.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'ok': true}));
      await request.response.close();
    });
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }
}
