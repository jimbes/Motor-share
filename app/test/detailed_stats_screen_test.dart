import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:redl/core/models/ride.dart';
import 'package:redl/core/models/track_point.dart';
import 'package:redl/core/models/user_summary.dart';
import 'package:redl/l10n/app_localizations.dart';
import 'package:redl/screens/detailed_stats_screen.dart';
import 'package:redl/theme/redl_theme.dart';
import 'package:redl/widgets/ride_metric_chart.dart';

Ride _ride({List<TrackPoint>? track}) {
  return Ride(
    id: 1,
    title: 'Balade',
    startedAt: DateTime(2026, 9, 7, 10),
    durationSeconds: 3600,
    distanceMeters: 45000,
    avgSpeedKmh: 55.5,
    maxSpeedKmh: 120,
    elevationGainM: 640,
    elevationLossM: 610,
    movingTimeSeconds: 3200,
    user: const UserSummary(id: 1, name: 'Jim'),
    track: track,
    likesCount: 0,
    commentsCount: 0,
    likedByMe: false,
  );
}

List<TrackPoint> _track({bool speed = true, bool alt = true}) {
  return [
    for (var i = 0; i < 60; i++)
      TrackPoint(
        lat: 45.0 + i * 0.001,
        lng: 5.0,
        speed: speed ? 40.0 + (i % 20) * 3 : null,
        alt: alt ? 300.0 + (i % 15) * 8 : null,
      ),
  ];
}

Widget _screen(Ride ride) => MaterialApp(
  theme: RedlTheme.dark,
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: DetailedStatsScreen(ride: ride),
);

void main() {
  // These charts can't be eyeballed from here - there is no emulator in
  // this environment - so rendering them in a test is the only thing
  // standing between a layout mistake and a release build. An earlier bug
  // this session shipped exactly that way.
  testWidgets('renders both curves without a build error', (tester) async {
    await tester.pumpWidget(_screen(_ride(track: _track())));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(ErrorWidget), findsNothing);
    expect(find.byType(RideMetricChart), findsNWidgets(2));
    expect(find.text('SPEED'), findsOneWidget);
    expect(find.text('ELEVATION'), findsOneWidget);
  });

  testWidgets('drops the altitude curve when the ride recorded none', (tester) async {
    await tester.pumpWidget(_screen(_ride(track: _track(alt: false))));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(RideMetricChart), findsOneWidget);
    expect(find.text('SPEED'), findsOneWidget);
    expect(find.text('ELEVATION'), findsNothing);
  });

  testWidgets('explains itself rather than drawing empty axes with no track', (tester) async {
    await tester.pumpWidget(_screen(_ride(track: const [])));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(RideMetricChart), findsNothing);
    expect(
      find.text('Not enough GPS points on this ride to plot any curves.'),
      findsOneWidget,
    );
  });

  testWidgets('still shows the numbers the curves are meant to back', (tester) async {
    await tester.pumpWidget(_screen(_ride(track: _track())));
    await tester.pumpAndSettle();

    expect(find.text('640 m'), findsOneWidget);
    expect(find.text('610 m'), findsOneWidget);
  });
}
