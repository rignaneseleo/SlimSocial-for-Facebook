package it.rignanese.leo.slim.platform

import android.content.Context
import io.mockk.mockk
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertDoesNotThrow

/**
 * Smoke test only — we cannot stand up a real BillingClient connection in a
 * JVM unit test (it requires an attached Play Services binder). The deeper
 * coverage lives in instrumentation tests (post-Phase 11).
 *
 * What this asserts:
 *   - The class can be constructed with a mocked Context (verifies imports
 *     and the proprietary dep landed)
 */
class PlayBillingDonationLauncherTest {

    @Test
    fun `can be constructed`() {
        val context: Context = mockk(relaxed = true)
        assertDoesNotThrow { PlayBillingDonationLauncher(context) }
    }
}
