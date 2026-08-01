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
