import 'package:halaph/server/mock_backend.dart';

void main(List<String> args) async {
  final server = MockBackendServer(port: 8080);
  await server.start();
  print('Mock backend listening on port 8080');
}
