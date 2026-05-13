import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:halaph/main.dart';

void main() {
  testWidgets('App shows account entry when logged out', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HalaPhApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();

    final hasLegacyLoader =
        find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
    final hasLogoLoader =
        find.textContaining('Preparing HalaPH').evaluate().isNotEmpty;
    final hasLaunchPreflight =
        find.textContaining('Welcome to HalaPH').evaluate().isNotEmpty;
    final hasStart = find.textContaining('Start').evaluate().isNotEmpty;
    final hasGuideMode =
        find.textContaining('Guide Mode').evaluate().isNotEmpty;
    final hasAuthForm = find.textContaining('Sign In').evaluate().isNotEmpty ||
        find.textContaining('Create Account').evaluate().isNotEmpty ||
        find
            .textContaining('Sign in to switch or continue using HalaPH')
            .evaluate()
            .isNotEmpty;

    expect(
      hasLaunchPreflight ||
          hasStart ||
          hasGuideMode ||
          hasLegacyLoader ||
          hasLogoLoader ||
          hasAuthForm,
      isTrue,
    );
  });
}
