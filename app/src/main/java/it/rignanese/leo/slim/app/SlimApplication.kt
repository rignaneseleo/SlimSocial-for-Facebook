package it.rignanese.leo.slim.app

import android.app.Application

/**
 * Application subclass that owns the [AppContainer] for the life of the process.
 *
 * Registered in `AndroidManifest.xml` via `android:name=".app.SlimApplication"`.
 */
class SlimApplication : Application() {

    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        container = AppContainer(this)
    }
}
