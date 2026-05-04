package it.rignanese.leo.slim.rules

import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import org.junit.jupiter.api.Test

class DarkThemeMessengerRuleTest {
    private val rule = DarkThemeMessengerRule()

    @Test
    fun `id matches`() {
        rule.id shouldBe "dark_theme_messenger"
    }

    @Test
    fun `applies on messenger`() {
        val css = rule.cssFor("https://www.messenger.com/inbox")!!
        css shouldContain "--surface-background"
        css shouldContain "::-webkit-scrollbar"
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
