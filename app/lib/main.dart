import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'app.dart';

void main() {
  // Required for the ride-recording foreground service (RecordingController)
  // to relay notification button presses back to the main isolate.
  FlutterForegroundTask.initCommunicationPort();
  runApp(const RedlApp());
}
