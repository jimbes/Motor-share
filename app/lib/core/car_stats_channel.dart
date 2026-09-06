import 'dart:async';

import 'package:flutter/services.dart';

/// Bridges live ride stats and Start/Pause/Resume/Stop commands to the
/// Android Auto car screen (backlog FEAT-4, V1: stats + controls only, no
/// map). Two Dart-side instances of this class both bind to the same
/// underlying platform channel (Flutter's [MethodChannel] is keyed by
/// name, not object identity), so [pushStats] and [setCommandHandler] can
/// safely be called from different places without needing to share one
/// instance.
///
/// A no-op on platforms without the native car integration (iOS, and
/// Android whenever no car host has connected) - [pushStats] just has no
/// listener on the other end in that case, which is why its failures are
/// swallowed rather than surfaced.
class CarStatsChannel {
  static const _channel = MethodChannel('com.besse.redl/car');

  void pushStats({
    required String state,
    required double speedKmh,
    required double distanceKm,
    required String elapsedLabel,
  }) {
    unawaited(
      _channel
          .invokeMethod('statsUpdated', {
            'state': state,
            'speedKmh': speedKmh,
            'distanceKm': distanceKm,
            'elapsedLabel': elapsedLabel,
          })
          .catchError((_) {}),
    );
  }

  void setCommandHandler({
    required Future<void> Function() onStart,
    required VoidCallback onPause,
    required VoidCallback onResume,
    required VoidCallback onStop,
  }) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'start':
          await onStart();
        case 'pause':
          onPause();
        case 'resume':
          onResume();
        case 'stop':
          onStop();
      }
      return null;
    });
  }
}
