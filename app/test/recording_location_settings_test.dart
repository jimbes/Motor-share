import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:redl/state/recording_controller.dart';

void main() {
  group('buildRecordingLocationSettings', () {
    // Regression test for rides whose track stopped partway through with
    // the phone locked.
    //
    // foregroundNotificationConfig is what picks geolocator's foreground
    // service code path in StreamHandlerImpl.onListen. The other path
    // builds a locationClient tied to the Activity, and setActivity(null)
    // - fired when Android destroys a backgrounded Activity - calls
    // stopListening() on it, silently killing position updates for the
    // rest of the ride. Dropping this config compiles, passes analysis,
    // and only fails on a real phone twenty minutes into a ride, so it is
    // asserted here instead.
    test('asks for a foreground service so fixes outlive the Activity', () {
      final settings = buildRecordingLocationSettings();

      expect(settings.foregroundNotificationConfig, isNotNull);
    });

    test('holds a wake lock so a sleeping CPU does not batch fixes', () {
      final settings = buildRecordingLocationSettings();

      expect(settings.foregroundNotificationConfig!.enableWakeLock, isTrue);
    });

    // REDL's own flutter_foreground_task notification already carries the
    // live stats and the pause/resume button, so geolocator's second one
    // stays swipeable rather than pinning a duplicate to the shade.
    test('leaves its notification dismissible', () {
      final settings = buildRecordingLocationSettings();

      expect(settings.foregroundNotificationConfig!.setOngoing, isFalse);
    });

    test('keeps high accuracy and an unfiltered stream for track fidelity', () {
      final settings = buildRecordingLocationSettings();

      expect(settings.accuracy, LocationAccuracy.high);
      expect(settings.distanceFilter, 0);
    });
  });
}
