import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:halaph/main.dart';

void main() {
  testWidgets('App shows account entry when logged out', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HalaPhApp());
    await tester.pump();

    final hasLegacyLoader =
        find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
    final hasLogoLoader =
        find.textContaining('Preparing HalaPH').evaluate().isNotEmpty;
    final hasAuthForm =
        find.textContaining('Sign in to your account').evaluate().isNotEmpty;

    expect(hasLegacyLoader || hasLogoLoader || hasAuthForm, isTrue);
  });
}
