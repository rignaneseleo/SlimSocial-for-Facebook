package it.rignanese.leo.slim.platform

import io.mockk.mockk
import org.junit.jupiter.api.Test

/**
 * Sanity check: the F-Droid no-op crash reporter must not throw under any
 * circumstance. The whole point of this implementation is that the F-Droid
 * APK never reaches Sentry code, so swallowing every call is the contract.
 */
class NoOpCrashReporterTest {

    private val reporter = NoOpCrashReporter()

    @Test
    fun `init does not throw when sentry enabled`() {
        reporter.init(mockk(relaxed = true), sentryEnabled = true)
    }

    @Test
    fun `init does not throw when sentry disabled`() {
        reporter.init(mockk(relaxed = true), sentryEnabled = false)
    }

    @Test
    fun `reportNonFatal does not throw`() {
        reporter.reportNonFatal(IllegalStateException("boom"), mapOf("k" to "v"))
    }

    @Test
    fun `setEnabled does not throw`() {
        reporter.setEnabled(true)
        reporter.setEnabled(false)
    }
}
