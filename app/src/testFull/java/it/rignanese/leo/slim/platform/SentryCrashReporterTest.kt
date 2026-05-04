package it.rignanese.leo.slim.platform

import android.app.Application
import io.mockk.mockk
import org.junit.jupiter.api.Test

/**
 * Sanity-only tests for the Sentry-backed reporter.
 *
 * The full test surface for Sentry's BeforeSend pipeline lives in
 * `SentryEventScrubberTest` (pure logic). Here we exercise the two
 * early-exit branches of [SentryCrashReporter.init]:
 *
 *  1. user opted out  →  must not call SentryAndroid.init
 *  2. DSN is blank    →  must not call SentryAndroid.init
 *
 * If either path actually reached `SentryAndroid.init` it would throw on
 * Robolectric-less JVM unit tests because no Android Looper is attached, so
 * "does not throw" is a sufficient assertion.
 */
class SentryCrashReporterTest {

    private val reporter = SentryCrashReporter()

    @Test
    fun `init is a no-op when sentry disabled`() {
        reporter.init(mockk<Application>(relaxed = true), sentryEnabled = false)
    }

    @Test
    fun `init is a no-op when DSN is blank`() {
        // BuildConfig.SENTRY_DSN defaults to "" in dev / local builds.
        reporter.init(mockk<Application>(relaxed = true), sentryEnabled = true)
    }

    @Test
    fun `reportNonFatal before init is a no-op`() {
        // Not initialised → must not throw, must not call Sentry.captureException.
        reporter.reportNonFatal(RuntimeException("boom"), mapOf("k" to "v"))
    }

    @Test
    fun `setEnabled false before init is a no-op`() {
        reporter.setEnabled(false)
    }
}
