package it.rignanese.leo.slim.app

import android.app.Application
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking

/**
 * Application subclass that owns the [AppContainer] for the life of the process.
 *
 * Registered in `AndroidManifest.xml` via `android:name=".app.SlimApplication"`.
 *
 * After constructing the container, the flavor-provided crash reporter is
 * initialised with the user's current Sentry opt-in. Reading DataStore once at
 * startup via [runBlocking] is acceptable here — DataStore reads are fast and
 * this completes well before the first Activity is shown.
 */
class SlimApplication : Application() {

    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        container = AppContainer(this)

        val sentryEnabled = runBlocking {
            container.settingsRepository.settings.first().privacy.sentryEnabled
        }
        container.platform.crashReporter.init(this, sentryEnabled)
    }
}
