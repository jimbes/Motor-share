package com.besse.redl.car

import android.content.Intent
import androidx.car.app.Screen
import androidx.car.app.Session

/**
 * One car-side session for the REDL Android Auto integration (backlog
 * FEAT-4). REDL only has one screen for V1 - live ride stats - so this
 * just hands off to it.
 */
class RedlCarSession : Session() {
    override fun onCreateScreen(intent: Intent): Screen = RecordingScreen(carContext)
}
