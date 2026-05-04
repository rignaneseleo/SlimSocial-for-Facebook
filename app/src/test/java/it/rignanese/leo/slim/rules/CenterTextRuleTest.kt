package it.rignanese.leo.slim.rules

import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import org.junit.jupiter.api.Test

class CenterTextRuleTest {
    private val rule = CenterTextRule()

    @Test
    fun `id matches legacy SharedPreferences key`() {
        rule.id shouldBe "center_text"
    }

    @Test
    fun `applies on facebook hosts`() {
        val css = rule.cssFor("https://m.facebook.com/foo")
        css!! shouldContain "._5rgt._5msi"
    }

    @Test
    fun `does not apply on messenger hosts`() {
        rule.cssFor("https://www.messenger.com/inbox") shouldBe null
    }

    @Test
    fun `does not apply on unknown hosts`() {
        rule.cssFor("https://example.com/") shouldBe null
    }

    @Test
    fun `js is null`() {
        rule.jsFor("https://m.facebook.com/foo") shouldBe null
    }
}
