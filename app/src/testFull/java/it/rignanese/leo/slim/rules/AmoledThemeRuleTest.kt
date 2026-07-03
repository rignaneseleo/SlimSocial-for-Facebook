package it.rignanese.leo.slim.rules

import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import org.junit.jupiter.api.Test

class AmoledThemeRuleTest {
    private val rule = AmoledThemeRule()

    @Test
    fun `id matches`() {
        rule.id shouldBe ThemeIds.AMOLED
    }

    @Test
    fun `applies on facebook hosts`() {
        rule.cssFor("https://m.facebook.com/home.php")!! shouldContain "#000000"
    }

    @Test
    fun `does not apply on messenger`() {
        rule.cssFor("https://www.messenger.com/inbox") shouldBe null
    }

    @Test
    fun `does not apply on unknown hosts`() {
        rule.cssFor("https://example.com/") shouldBe null
    }

    @Test
    fun `has no JS payload`() {
        rule.jsFor("https://m.facebook.com/") shouldBe null
    }

    @Test
    fun `every declaration is important so the theme wins over the free dark css`() {
        val css = rule.cssFor("https://m.facebook.com/")!!
        val declarations = css.lines().count { it.trim().endsWith(";") }
        val importants = css.lines().count { it.contains("!important") }
        (importants >= declarations) shouldBe true
    }
}
