package it.rignanese.leo.slim.rules

import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import org.junit.jupiter.api.Test

class FixedBarRuleTest {
    private val rule = FixedBarRule()

    @Test
    fun `id matches`() {
        rule.id shouldBe "fixed_bar"
    }

    @Test
    fun `applies on facebook and preserves the spx token verbatim`() {
        val css = rule.cssFor("https://m.facebook.com/foo")!!
        css shouldContain "#header { position: fixed"
        // The Flutter source used a Dart raw string with literal `${'$'}spx`;
        // it must round-trip verbatim because the legacy build relied on that
        // string showing up in injected CSS.
        css shouldContain "${'$'}spx"
    }

    @Test
    fun `does not apply on messenger`() {
        rule.cssFor("https://www.messenger.com/inbox") shouldBe null
    }

    @Test
    fun `does not apply on unknown hosts`() {
        rule.cssFor("https://example.com/") shouldBe null
    }
}
