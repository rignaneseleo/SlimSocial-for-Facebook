package it.rignanese.leo.slim.platform

import android.content.Context
import io.mockk.mockk
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertDoesNotThrow

/**
 * Smoke test only — a real BillingClient connection needs an attached Play
 * Services binder which the JVM doesn't have. Deeper coverage is the manual
 * purchase/restore matrix in TESTING.md; the mapping/cache logic is covered
 * by [PlayBillingProEntitlementTest] via [BillingConnector] fakes.
 */
class PlayBillingConnectorTest {

    @Test
    fun `can be constructed`() {
        val context: Context = mockk(relaxed = true)
        assertDoesNotThrow { PlayBillingConnector(context) }
    }
}
