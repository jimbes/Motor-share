import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redl/core/format.dart';
import 'package:redl/l10n/app_localizations.dart';

void main() {
  group('formatDistanceKm', () {
    test('shows two decimals under 10km', () {
      expect(formatDistanceKm(4.567), '4.57 km');
    });

    test('shows one decimal at or above 10km', () {
      expect(formatDistanceKm(45.67), '45.7 km');
    });
  });

  group('formatDuration', () {
    test('formats seconds only', () {
      expect(formatDuration(const Duration(seconds: 42)), '42s');
    });

    test('formats minutes and seconds', () {
      expect(formatDuration(const Duration(minutes: 5, seconds: 9)), '5m 09s');
    });

    test('formats hours and minutes, dropping seconds', () {
      expect(formatDuration(const Duration(hours: 2, minutes: 5, seconds: 30)), '2h 05m');
    });
  });

  group('formatSpeedKmh', () {
    test('rounds to whole km/h', () {
      expect(formatSpeedKmh(65.4), '65 km/h');
      expect(formatSpeedKmh(65.6), '66 km/h');
    });
  });

  group('formatRelativeDate', () {
    testWidgets('labels today', (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(_LocalizedHarness(onBuild: (context) => capturedContext = context));

      expect(formatRelativeDate(capturedContext, DateTime.now()), 'Today');
    });

    testWidgets('labels a date a week+ ago with month/day/year', (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(_LocalizedHarness(onBuild: (context) => capturedContext = context));

      final tenDaysAgo = DateTime.now().subtract(const Duration(days: 10));
      final result = formatRelativeDate(capturedContext, tenDaysAgo);
      expect(result, contains(tenDaysAgo.year.toString()));
    });
  });
}

class _LocalizedHarness extends StatelessWidget {
  const _LocalizedHarness({required this.onBuild});

  final void Function(BuildContext context) onBuild;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          onBuild(context);
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
