package com.besse.redl

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache

class MainActivity : FlutterActivity() {
    companion object {
        // Shared with the Android Auto integration (see the car/ package) so
        // it can reach the same running Dart isolate/RecordingController the
        // phone screen uses, instead of spinning up a second Flutter engine
        // (backlog FEAT-4).
        const val CAR_ENGINE_ID = "redl_main_engine"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        FlutterEngineCache.getInstance().put(CAR_ENGINE_ID, flutterEngine)
    }
}
