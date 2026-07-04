package it.rignanese.leo.slim.rules

import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import io.kotest.matchers.string.shouldNotContain
import org.junit.jupiter.api.Test

class FixedBarRuleTest {
    private val rule = FixedBarRule()

    @Test
    fun `id matches`() {
        rule.id shouldBe "fixed_bar"
    }

    @Test
    fun `pins the bar with sticky positioning on facebook`() {
        val css = rule.cssFor("https://m.facebook.com/foo")!!
        // Modern fix: sticky keeps the bar pinned without a #root padding hack.
        css shouldContain "position: sticky"
        css shouldContain "top: 0"
    }

    @Test
    fun `targets both the mbasic header and the modern banner`() {
        val css = rule.cssFor("https://m.facebook.com/foo")!!
        css shouldContain "#header"
        css shouldContain "[role=\"banner\"]"
    }

    @Test
    fun `does not pad the react root or ship the broken interpolation token`() {
        val css = rule.cssFor("https://m.facebook.com/foo")!!
        // The old rule padded #root unconditionally (broke pre-login pages) and
        // shipped an unsubstituted `${'$'}spx` token (invalid CSS). Both are gone.
        css shouldNotContain "#root"
        css shouldNotContain "position: fixed"
        css shouldNotContain "${'$'}spx"
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
