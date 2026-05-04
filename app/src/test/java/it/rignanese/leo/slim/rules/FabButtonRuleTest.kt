package it.rignanese.leo.slim.rules

import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import org.junit.jupiter.api.Test

class FabButtonRuleTest {
    private val rule = FabButtonRule()

    @Test
    fun `id matches`() {
        rule.id shouldBe "fabBtn"
    }

    @Test
    fun `css applies on facebook`() {
        rule.cssFor("https://m.facebook.com/foo")!! shouldContain ".my_fab_btn"
    }

    @Test
    fun `js applies on facebook`() {
        val js = rule.jsFor("https://m.facebook.com/foo")!!
        js shouldContain "createFab"
        js shouldContain "my_fab_btn"
    }

    @Test
    fun `does not apply on messenger`() {
        rule.cssFor("https://www.messenger.com/inbox") shouldBe null
        rule.jsFor("https://www.messenger.com/inbox") shouldBe null
    }

    @Test
    fun `does not apply on unknown hosts`() {
        rule.cssFor("https://example.com/") shouldBe null
        rule.jsFor("https://example.com/") shouldBe null
    }
}
