import 'package:flutter_test/flutter_test.dart';
import 'package:halaph/firebase_options.dart';

void main() {
  test('all platform Firebase apps use the same project', () {
    final projectIds = {
      DefaultFirebaseOptions.android.projectId,
      DefaultFirebaseOptions.ios.projectId,
      DefaultFirebaseOptions.macos.projectId,
      DefaultFirebaseOptions.web.projectId,
      DefaultFirebaseOptions.windows.projectId,
    };

    expect(projectIds, {'halaph-d4eaa'});
  });
}
