package com.besse.redl.car

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.Pane
import androidx.car.app.model.PaneTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import com.besse.redl.MainActivity
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

/**
 * Live ride stats + Start/Pause/Resume/Stop, shown on the car's screen
 * while the phone is projecting via Android Auto (backlog FEAT-4, V1). No
 * map/route here - that's explicitly a later, separate piece of work.
 *
 * PaneTemplate is the simplest template that fits a few rows of text plus
 * a couple of actions, and (unlike NavigationTemplate) doesn't require the
 * app to belong to the NAVIGATION category.
 *
 * Talks to the same running Dart isolate the phone screen uses (see
 * MainActivity.CAR_ENGINE_ID) over a MethodChannel, rather than spinning
 * up a second Flutter engine: Dart pushes stat updates in on
 * "statsUpdated" (see CarStatsChannel.pushStats in the app), and this
 * sends "start"/"pause"/"resume"/"stop" back out for RecordingController
 * to act on. If the phone app's Flutter engine hasn't been created yet in
 * this process (the car connected before the app was ever opened this
 * session), [channel] is null and the screen falls back to showing
 * whatever defaults it was constructed with, with buttons that don't do
 * anything until the app is opened on the phone at least once.
 */
class RecordingScreen(carContext: CarContext) : Screen(carContext) {
    companion object {
        private const val CHANNEL_NAME = "com.besse.redl/car"
    }

    private var recordingState = "idle" // idle | recording | paused | stopped
    private var speedKmh = 0.0
    private var distanceKm = 0.0
    private var elapsedLabel = "0:00"

    private val channel: MethodChannel? =
        FlutterEngineCache.getInstance().get(MainActivity.CAR_ENGINE_ID)?.let {
            MethodChannel(it.dartExecutor.binaryMessenger, CHANNEL_NAME)
        }

    init {
        channel?.setMethodCallHandler { call, result ->
            if (call.method == "statsUpdated") {
                @Suppress("UNCHECKED_CAST")
                val args = call.arguments as? Map<String, Any?>
                recordingState = args?.get("state") as? String ?: recordingState
                speedKmh = (args?.get("speedKmh") as? Number)?.toDouble() ?: speedKmh
                distanceKm = (args?.get("distanceKm") as? Number)?.toDouble() ?: distanceKm
                elapsedLabel = args?.get("elapsedLabel") as? String ?: elapsedLabel
                invalidate()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
        // Lets the Dart side know a car screen is now listening, in case it
        // wants to push the current state right away rather than waiting
        // for the next tick.
        channel?.invokeMethod("subscribe", null)
    }

    override fun onGetTemplate(): Template {
        val pane = Pane.Builder()
            .addRow(
                Row.Builder()
                    .setTitle("Speed")
                    .addText(String.format("%.0f km/h", speedKmh))
                    .build(),
            )
            .addRow(
                Row.Builder()
                    .setTitle("Distance")
                    .addText(String.format("%.1f km", distanceKm))
                    .build(),
            )
            .addRow(
                Row.Builder()
                    .setTitle("Duration")
                    .addText(elapsedLabel)
                    .build(),
            )
            .addAction(primaryAction())

        if (recordingState == "recording" || recordingState == "paused") {
            pane.addAction(stopAction())
        }

        return PaneTemplate.Builder(pane.build())
            .setHeaderAction(Action.APP_ICON)
            .setTitle(headerTitle())
            .build()
    }

    private fun headerTitle(): String = when (recordingState) {
        "recording" -> "Recording your ride"
        "paused" -> "Ride paused"
        "stopped" -> "Ride stopped - finish saving on your phone"
        else -> "REDL"
    }

    private fun primaryAction(): Action {
        return when (recordingState) {
            "recording" ->
                Action.Builder()
                    .setTitle("Pause")
                    .setOnClickListener { channel?.invokeMethod("pause", null) }
                    .build()
            "paused" ->
                Action.Builder()
                    .setTitle("Resume")
                    .setOnClickListener { channel?.invokeMethod("resume", null) }
                    .build()
            else ->
                Action.Builder()
                    .setTitle("Start")
                    .setOnClickListener { channel?.invokeMethod("start", null) }
                    .build()
        }
    }

    private fun stopAction(): Action {
        return Action.Builder()
            .setTitle("Stop")
            .setOnClickListener { channel?.invokeMethod("stop", null) }
            .build()
    }
}
