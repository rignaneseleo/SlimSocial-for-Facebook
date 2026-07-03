package it.rignanese.leo.slim.rules

import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import org.junit.jupiter.api.Test

class CompactThemeRuleTest {
    private val rule = CompactThemeRule()

    @Test
    fun `id matches`() {
        rule.id shouldBe ThemeIds.COMPACT
    }

    @Test
    fun `css reduces font size and paddings`() {
        val css = rule.cssFor("https://m.facebook.com/")!!
        css shouldContain "font-size"
        css shouldContain "padding"
    }

    @Test
    fun `does not apply off facebook`() {
        rule.cssFor("https://example.com/") shouldBe null
    }
}
