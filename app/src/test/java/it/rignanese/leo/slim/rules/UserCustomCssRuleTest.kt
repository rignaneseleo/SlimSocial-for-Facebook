package it.rignanese.leo.slim.rules

import io.kotest.matchers.shouldBe
import it.rignanese.leo.slim.domain.CustomCode
import it.rignanese.leo.slim.domain.NamedSnippet
import org.junit.jupiter.api.Test

class UserCustomCssRuleTest {

    @Test
    fun `id is user_css`() {
        UserCustomCssRule(CustomCode()).id shouldBe "user_css"
    }

    @Test
    fun `returns null when no entries are active`() {
        val custom = CustomCode(
            cssEntries = listOf(
                NamedSnippet(id = "a", name = "A", code = ".a{}", updatedAt = 0L),
            ),
            activeCssIds = emptySet(),
        )
        UserCustomCssRule(custom).cssFor("https://m.facebook.com/") shouldBe null
    }

    @Test
    fun `joins active entries in order with newlines`() {
        val custom = CustomCode(
            cssEntries = listOf(
                NamedSnippet(id = "a", name = "A", code = ".a{}", updatedAt = 0L),
                NamedSnippet(id = "b", name = "B", code = ".b{}", updatedAt = 0L),
                NamedSnippet(id = "c", name = "C", code = ".c{}", updatedAt = 0L),
            ),
            activeCssIds = setOf("a", "c"),
        )
        UserCustomCssRule(custom).cssFor("https://example.com/") shouldBe ".a{}\n.c{}"
    }

    @Test
    fun `is host-agnostic`() {
        val custom = CustomCode(
            cssEntries = listOf(NamedSnippet("a", "A", ".x{}", 0L)),
            activeCssIds = setOf("a"),
        )
        val rule = UserCustomCssRule(custom)
        rule.cssFor("https://m.facebook.com/") shouldBe ".x{}"
        rule.cssFor("https://www.messenger.com/") shouldBe ".x{}"
        rule.cssFor("https://example.com/") shouldBe ".x{}"
    }
}
