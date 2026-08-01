package it.rignanese.leo.slim.rules

import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import io.kotest.matchers.string.shouldNotContain
import org.junit.jupiter.api.Test

class HideAdsAndPYMKRuleTest {
    private val rule = HideAdsAndPYMKRule()

    @Test
    fun `id matches`() {
        rule.id shouldBe "hideAdsAndPeopleYouMayKnow"
    }

    @Test
    fun `applies on facebook`() {
        val css = rule.cssFor("https://m.facebook.com/foo")!!
        css shouldContain ".ego"
        css shouldContain "[data-pagelet=\"RightRail\"]"
    }

    @Test
    fun `css is parseable - no double hash and balanced parens`() {
        // Regression guard for the ported Flutter bug: `##[data-pagelet=...]`
        // plus an unclosed `:has(` made Chromium drop every block in this
        // payload, including the unrelated `.ego` rule.
        val css = rule.cssFor("https://m.facebook.com/")!!
        css shouldNotContain "##"
        css.count { it == '(' } shouldBe css.count { it == ')' }
        css.count { it == '{' } shouldBe css.count { it == '}' }
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
