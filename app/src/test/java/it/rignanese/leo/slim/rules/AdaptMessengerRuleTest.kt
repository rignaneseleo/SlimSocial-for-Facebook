package it.rignanese.leo.slim.rules

import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import org.junit.jupiter.api.Test

class AdaptMessengerRuleTest {
    private val rule = AdaptMessengerRule()

    @Test
    fun `id matches`() {
        rule.id shouldBe "adaptMessenger"
    }

    @Test
    fun `applies on messenger`() {
        val css = rule.cssFor("https://www.messenger.com/inbox")!!
        css shouldContain "TOP BAR"
        css shouldContain "CHAT BAR"
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
