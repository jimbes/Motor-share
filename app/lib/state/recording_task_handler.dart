import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// GPS recording itself stays in the main isolate (RecordingController) -
/// this handler's only job is to be the thing that keeps the app process
/// alive (via the foreground service) and to relay notification button
/// presses back to the main isolate. It does no work of its own.
@pragma('vm:entry-point')
void recordingTaskHandlerCallback() {
  FlutterForegroundTask.setTaskHandler(RecordingTaskHandler());
}

class RecordingTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationButtonPressed(String id) {
    FlutterForegroundTask.sendDataToMain({'buttonPressed': id});
  }
}
