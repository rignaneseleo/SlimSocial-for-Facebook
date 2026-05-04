package it.rignanese.leo.slim.rules

import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import org.junit.jupiter.api.Test

class HideAdsAndPYMKRuleTest {
    private val rule = HideAdsAndPYMKRule()

    @Test
    fun `id matches`() {
        rule.id shouldBe "hideAdsAndPeopleYouMayKnow"
    }

    @Test
    fun `applies on facebook`() {
        val css = rule.cssFor("https://m.facebook.com/foo")!!
        css shouldContain ".ego"
        // Flutter source had a malformed selector with `##` and an unclosed
        // `:has(>div>div>div>div>div>` — preserved verbatim per spec.
        css shouldContain "##[data-pagelet=RightRail]"
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
