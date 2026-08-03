package it.rignanese.leo.slim.rules

import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import org.junit.jupiter.api.Test

class ViewportFitRuleTest {
    private val rule = ViewportFitRule()

    @Test
    fun `id matches`() {
        rule.id shouldBe "viewport_fit"
    }

    @Test
    fun `injects no css at all`() {
        // Regression guard: an earlier revision clipped the document with
        // `overflow-x: hidden`, which killed feed scrolling and swallowed
        // Facebook's flyout menus on-device. This rule is JS-only by design.
        rule.cssFor("https://www.facebook.com/home.php") shouldBe null
    }

    @Test
    fun `js installs a device-width viewport meta`() {
        val js = rule.jsFor("https://touch.facebook.com/")!!
        js shouldContain "meta[name=viewport]"
        js shouldContain "width=device-width"
    }

    @Test
    fun `does not apply on messenger or unknown hosts`() {
        rule.jsFor("https://www.messenger.com/inbox") shouldBe null
        rule.jsFor("https://example.com/") shouldBe null
    }
}
