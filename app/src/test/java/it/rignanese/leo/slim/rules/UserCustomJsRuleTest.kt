package it.rignanese.leo.slim.rules

import io.kotest.matchers.shouldBe
import it.rignanese.leo.slim.domain.CustomCode
import it.rignanese.leo.slim.domain.NamedSnippet
import org.junit.jupiter.api.Test

class UserCustomJsRuleTest {

    @Test
    fun `id is user_js`() {
        UserCustomJsRule(CustomCode()).id shouldBe "user_js"
    }

    @Test
    fun `returns null when no entries are active`() {
        val custom = CustomCode(
            jsEntries = listOf(NamedSnippet("a", "A", "alert(1)", 0L)),
            activeJsIds = emptySet(),
        )
        UserCustomJsRule(custom).jsFor("https://m.facebook.com/") shouldBe null
    }

    @Test
    fun `joins active entries in order with newlines`() {
        val custom = CustomCode(
            jsEntries = listOf(
                NamedSnippet("a", "A", "alert(1)", 0L),
                NamedSnippet("b", "B", "alert(2)", 0L),
            ),
            activeJsIds = setOf("a", "b"),
        )
        UserCustomJsRule(custom).jsFor("https://m.facebook.com/") shouldBe "alert(1)\nalert(2)"
    }
}
