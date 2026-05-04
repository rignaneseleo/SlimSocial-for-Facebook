package it.rignanese.leo.slim.rules

import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import org.junit.jupiter.api.Test

class RemoveMessengerDownloadRuleTest {
    private val rule = RemoveMessengerDownloadRule()

    @Test
    fun `id matches`() {
        rule.id shouldBe "removeMessengerDownload"
    }

    @Test
    fun `applies on messenger`() {
        rule.cssFor("https://www.messenger.com/inbox")!! shouldContain "._s15"
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
