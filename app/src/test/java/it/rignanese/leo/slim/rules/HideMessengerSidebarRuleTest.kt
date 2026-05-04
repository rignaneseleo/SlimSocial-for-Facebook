package it.rignanese.leo.slim.rules

import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import org.junit.jupiter.api.Test

class HideMessengerSidebarRuleTest {
    private val rule = HideMessengerSidebarRule()

    @Test
    fun `id matches`() {
        rule.id shouldBe "hide_messenger_sidebar"
    }

    @Test
    fun `applies on messenger`() {
        val css = rule.cssFor("https://www.messenger.com/inbox")
        css!! shouldContain "display: none"
    }

    @Test
    fun `does not apply on facebook`() {
        rule.cssFor("https://m.facebook.com/foo") shouldBe null
    }

    @Test
    fun `does not apply on unknown hosts`() {
        rule.cssFor("https://example.com/") shouldBe null
    }
}
