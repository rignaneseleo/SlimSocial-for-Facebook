package it.rignanese.leo.slim.rules

import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import org.junit.jupiter.api.Test

class AccentThemeRuleTest {
    private val rule = AccentThemeRule(ThemeIds.ACCENT_GREEN, "#1b7f4d")

    @Test
    fun `id matches the constructor argument`() {
        rule.id shouldBe ThemeIds.ACCENT_GREEN
    }

    @Test
    fun `css re-tints the chrome with the accent color`() {
        rule.cssFor("https://m.facebook.com/")!! shouldContain "#1b7f4d"
    }

    @Test
    fun `header content stays readable on the accent background`() {
        // The accent is applied to #header's background AND to link text; a
        // higher-specificity override must keep header links white.
        rule.cssFor("https://m.facebook.com/")!! shouldContain "#header a"
    }

    @Test
    fun `does not apply off facebook`() {
        rule.cssFor("https://example.com/") shouldBe null
        rule.cssFor("https://www.messenger.com/") shouldBe null
    }

    @Test
    fun `each accent variant carries its own color`() {
        AccentThemeRule(ThemeIds.ACCENT_PURPLE, "#7b46b8")
            .cssFor("https://m.facebook.com/")!! shouldContain "#7b46b8"
        AccentThemeRule(ThemeIds.ACCENT_ORANGE, "#d9662a")
            .cssFor("https://m.facebook.com/")!! shouldContain "#d9662a"
    }
}
