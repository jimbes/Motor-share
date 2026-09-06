import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:redl/core/models/badge_info.dart';
import 'package:redl/core/repositories/reward_repository.dart';
import 'package:redl/l10n/app_localizations.dart';
import 'package:redl/screens/badge_catalog_screen.dart';
import 'package:redl/theme/redl_theme.dart';

class _FakeRewardRepository implements RewardRepository {
  _FakeRewardRepository(this._badges);

  final List<BadgeInfo> _badges;

  @override
  Future<List<BadgeInfo>> catalog() async => _badges;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _catalogScreen(List<BadgeInfo> badges) {
  return Provider<RewardRepository>(
    create: (_) => _FakeRewardRepository(badges),
    child: MaterialApp(
      theme: RedlTheme.dark,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const BadgeCatalogScreen(),
    ),
  );
}

final _earned = BadgeInfo(
  code: 'first_ride',
  name: 'First ride',
  description: 'Publish a ride',
  earned: true,
  earnedAt: DateTime(2026, 3, 14),
);

const _locked = BadgeInfo(
  code: 'rides_25',
  name: 'Regular',
  description: '25 rides published',
  progress: 1,
  threshold: 25,
);

void main() {
  testWidgets('The catalog splits earned badges from the ones left to unlock', (tester) async {
    await tester.pumpWidget(_catalogScreen([_earned, _locked]));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(ErrorWidget), findsNothing);
    expect(find.text('EARNED'), findsOneWidget);
    expect(find.text('TO UNLOCK'), findsOneWidget);
    expect(find.text('First ride'), findsOneWidget);
    expect(find.text('Regular'), findsOneWidget);
  });

  testWidgets('An unearned badge shows how far along the rider is', (tester) async {
    await tester.pumpWidget(_catalogScreen([_earned, _locked]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Regular'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 25'), findsOneWidget);
    expect(find.text('Not earned yet'), findsOneWidget);
    // The catalog header carries one bar; the detail sheet adds its own.
    expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
  });

  testWidgets('An earned badge shows no progress bar of its own', (tester) async {
    await tester.pumpWidget(_catalogScreen([_earned, _locked]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('First ride'));
    await tester.pumpAndSettle();

    expect(find.text('Earned on 14/3/2026'), findsOneWidget);
    // Only the catalog header's bar - the sheet adds none.
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('With everything earned the locked section says so instead of showing an empty grid', (tester) async {
    await tester.pumpWidget(_catalogScreen([_earned]));
    await tester.pumpAndSettle();

    expect(find.text('Every badge earned. Hats off.'), findsOneWidget);
  });
}
