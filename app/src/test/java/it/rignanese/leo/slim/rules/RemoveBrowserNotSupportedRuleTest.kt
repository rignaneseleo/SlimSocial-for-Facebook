package it.rignanese.leo.slim.rules

import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import org.junit.jupiter.api.Test

class RemoveBrowserNotSupportedRuleTest {
    private val rule = RemoveBrowserNotSupportedRule()

    @Test
    fun `id matches`() {
        rule.id shouldBe "removeBrowserNotSupported"
    }

    @Test
    fun `applies on facebook hosts`() {
        rule.cssFor("https://m.facebook.com/foo")!! shouldContain "#header-notices"
    }

    @Test
    fun `applies on messenger hosts`() {
        rule.cssFor("https://www.messenger.com/inbox")!! shouldContain "#header-notices"
    }

    @Test
    fun `does not apply on unknown hosts`() {
        rule.cssFor("https://example.com/") shouldBe null
    }
}
