package it.rignanese.leo.slim.rules

import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import org.junit.jupiter.api.Test

class HideStoriesRuleTest {
    private val rule = HideStoriesRule()

    @Test
    fun `id matches`() {
        rule.id shouldBe "hide_stories"
    }

    @Test
    fun `applies on facebook`() {
        val css = rule.cssFor("https://m.facebook.com/foo")!!
        css shouldContain "#MStoriesTray"
        // Best-effort modern hook — unverified, see the rule's KDoc.
        css shouldContain "[aria-label=\"Stories\"]"
        // Mobile Bloks DOM: the tray is a horizontal scroller, and its parent
        // carries an explicit height that has to be collapsed with it.
        css shouldContain "[data-is-h-scrollable=\"true\"]"
        css shouldContain ":has(> [data-is-h-scrollable=\"true\"])"
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
