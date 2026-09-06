package com.besse.redl.car

import androidx.car.app.CarAppService
import androidx.car.app.Session
import androidx.car.app.validation.HostValidator

/**
 * Entry point for the Android Auto integration (backlog FEAT-4, V1: live
 * ride stats and Start/Pause/Resume/Stop only, no map). Discovered by the
 * car host via the androidx.car.app.CarAppService intent-filter declared
 * on this service in AndroidManifest.xml.
 */
class RedlCarAppService : CarAppService() {
    override fun createHostValidator(): HostValidator {
        // TODO before any public release: replace with a real allow-list
        // (HostValidator.Builder, restricted to known car hosts). Accepting
        // any host is only appropriate while developing/testing against the
        // Desktop Head Unit.
        return HostValidator.ALLOW_ALL_HOSTS_VALIDATOR
    }

    override fun onCreateSession(): Session = RedlCarSession()
}
