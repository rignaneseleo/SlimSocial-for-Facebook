package it.rignanese.leo.slim.rules

import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import org.junit.jupiter.api.Test

class AddSpaceRuleTest {
    private val rule = AddSpaceRule()

    @Test
    fun `id matches`() {
        rule.id shouldBe "add_space"
    }

    @Test
    fun `applies on facebook`() {
        rule.cssFor("https://m.facebook.com/foo")!! shouldContain "margin-top: 50px"
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
