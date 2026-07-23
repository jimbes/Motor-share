import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:redl/l10n/app_localizations.dart';
import 'package:redl/screens/onboarding_screen.dart';
import 'package:redl/theme/redl_theme.dart';

MaterialApp _app(Widget home) => MaterialApp(
      theme: RedlTheme.dark,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void main() {
  testWidgets('Onboarding screen shows the REDL wordmark and both entry buttons', (tester) async {
    await tester.pumpWidget(_app(const OnboardingScreen()));

    expect(find.text('REDL'), findsOneWidget);
    expect(find.text('Track every apex.'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
  });

  testWidgets('Tapping Create Account navigates to the register screen', (tester) async {
    await tester.pumpWidget(_app(const OnboardingScreen()));

    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('Join REDL.'), findsOneWidget);
  });

  testWidgets('Tapping Log In navigates to the login screen', (tester) async {
    await tester.pumpWidget(_app(const OnboardingScreen()));

    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back.'), findsOneWidget);
  });
}
