package it.rignanese.leo.slim.platform

import io.kotest.matchers.shouldBe
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Test

/**
 * The F-Droid build has no billing, therefore no PRO: the entitlement is a
 * hard constant `false`. All PRO UI is compiled out of this flavor, but the
 * constant also defends the shared gating logic (RuleRegistry) in depth.
 */
class NoProEntitlementTest {

    @Test
    fun `isPro is false`() {
        NoProEntitlement.isPro.value shouldBe false
    }

    @Test
    fun `refresh does not throw and stays false`() {
        runBlocking { NoProEntitlement.refresh() }
        NoProEntitlement.isPro.value shouldBe false
    }
}
