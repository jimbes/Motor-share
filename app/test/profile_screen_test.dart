import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:redl/core/api_client.dart';
import 'package:redl/core/models/badge_info.dart';
import 'package:redl/core/models/bike.dart';
import 'package:redl/core/models/reward_summary.dart';
import 'package:redl/core/models/rider_stats.dart';
import 'package:redl/core/models/user.dart';
import 'package:redl/core/repositories/auth_repository.dart';
import 'package:redl/core/repositories/bike_repository.dart';
import 'package:redl/core/repositories/reward_repository.dart';
import 'package:redl/core/repositories/ride_repository.dart';
import 'package:redl/core/token_storage.dart';
import 'package:redl/l10n/app_localizations.dart';
import 'package:redl/screens/profile_screen.dart';
import 'package:redl/state/auth_provider.dart';
import 'package:redl/state/locale_provider.dart';
import 'package:redl/state/sensor_settings_provider.dart';
import 'package:redl/theme/redl_theme.dart';

class _FakeRideRepository implements RideRepository {
  @override
  Future<RiderStats> myStats() async =>
      const RiderStats(ridesCount: 7, distanceMeters: 148000, weekRidesCount: 0, weekDistanceMeters: 0);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBikeRepository implements BikeRepository {
  @override
  Future<List<Bike>> list() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRewardRepository implements RewardRepository {
  @override
  Future<RewardSummary> mine() async => const RewardSummary(
        xpTotal: 1250,
        level: 4,
        territoriesOwnedCount: 9,
        badges: [BadgeInfo(code: 'first_ride', name: 'First ride', description: 'Finish a ride', earned: true)],
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _profileScreen() {
  final apiClient = ApiClient();
  final auth = AuthProvider(
    apiClient: apiClient,
    authRepository: AuthRepository(apiClient),
    tokenStorage: TokenStorage(),
  )..user = AppUser(id: 1, name: 'Jim', username: 'jimbsse', email: 'jim@example.com', createdAt: DateTime(2026));

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ChangeNotifierProvider(create: (_) => SensorSettingsProvider()),
      Provider<RideRepository>(create: (_) => _FakeRideRepository()),
      Provider<BikeRepository>(create: (_) => _FakeBikeRepository()),
      Provider<RewardRepository>(create: (_) => _FakeRewardRepository()),
    ],
    child: MaterialApp(
      theme: RedlTheme.dark,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ProfileScreen(),
    ),
  );
}

void main() {
  // Regression test: the rewards block used to place an `Expanded` under a
  // `GestureDetector` instead of directly under the `Row`, which throws at
  // build time. Debug builds surface that as the red error screen, but a
  // release build silently paints a plain grey ErrorWidget over the whole
  // section - which is exactly how it reached a real phone unnoticed, since
  // nothing rendered this screen in CI.
  testWidgets('Profile screen renders the rewards block without a build error', (tester) async {
    await tester.pumpWidget(_profileScreen());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(ErrorWidget), findsNothing);

    // The XP/level/territories stats actually render their values.
    expect(find.text('1250'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
  });

  testWidgets('Profile screen renders the rider stats row', (tester) async {
    await tester.pumpWidget(_profileScreen());
    await tester.pumpAndSettle();

    expect(find.text('7'), findsOneWidget);
    expect(find.text('148 km'), findsOneWidget);
  });
}
