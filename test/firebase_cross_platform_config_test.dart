import 'dart:convert';
import 'dart:io';

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

  test('iOS Firebase options match the Xcode bundle id', () {
    expect(DefaultFirebaseOptions.ios.iosBundleId, 'com.halaph.app');

    final plist = File(
      'ios/Runner/GoogleService-Info.plist',
    ).readAsStringSync();
    expect(plist, contains('<string>com.halaph.app</string>'));
  });

  test('Android Firebase config matches Gradle application id', () {
    final googleServices =
        jsonDecode(File('android/app/google-services.json').readAsStringSync())
            as Map<String, dynamic>;
    final client = (googleServices['client'] as List).first as Map;
    final clientInfo = client['client_info'] as Map;
    final androidInfo = clientInfo['android_client_info'] as Map;
    final packageName = androidInfo['package_name'] as String;

    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(packageName, 'com.example.halaph');
    expect(gradle, contains('applicationId = "$packageName"'));
  });
}
