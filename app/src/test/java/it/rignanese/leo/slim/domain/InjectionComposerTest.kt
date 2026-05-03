package it.rignanese.leo.slim.domain

import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import org.junit.jupiter.api.Test

class InjectionComposerTest {

    private val composer = InjectionComposer()

    private fun rule(
        id: String,
        css: ((String) -> String?)? = null,
        js: ((String) -> String?)? = null,
    ): InjectionRule = object : InjectionRule {
        override val id: String = id
        override fun cssFor(url: String): String? = css?.invoke(url)
        override fun jsFor(url: String): String? = js?.invoke(url)
    }

    @Test
    fun `empty rule list yields empty payload`() {
        val payload = composer.compose(emptyList(), "https://facebook.com/")
        payload shouldBe InjectionPayload("", "")
    }

    @Test
    fun `css-only rule populates css and leaves js empty`() {
        val r = rule("a", css = { "body { color: red; }" })
        val payload = composer.compose(listOf(r), "https://facebook.com/")
        payload.css shouldBe "body { color: red; }"
        payload.js shouldBe ""
    }

    @Test
    fun `js-only rule populates js and leaves css empty`() {
        val r = rule("a", js = { "console.log('hi')" })
        val payload = composer.compose(listOf(r), "https://facebook.com/")
        payload.css shouldBe ""
        payload.js shouldBe "console.log('hi')"
    }

    @Test
    fun `multiple rules combine with newline for css and semicolon-newline for js`() {
        val r1 = rule("a", css = { "a{}" }, js = { "a()" })
        val r2 = rule("b", css = { "b{}" }, js = { "b()" })
        val payload = composer.compose(listOf(r1, r2), "https://facebook.com/")
        payload.css shouldBe "a{}\nb{}"
        payload.js shouldBe "a();\nb()"
    }

    @Test
    fun `null returns from a rule are filtered out`() {
        val matching = rule("on", css = { url -> if (url.contains("messenger")) "m{}" else null })
        val always = rule("on", css = { "x{}" })
        val payload = composer.compose(listOf(matching, always), "https://facebook.com/")
        payload.css shouldBe "x{}"
        payload.css.contains("m{}") shouldBe false
    }

    @Test
    fun `rule order is preserved in output`() {
        val r1 = rule("a", css = { "/* first */" })
        val r2 = rule("b", css = { "/* second */" })
        val r3 = rule("c", css = { "/* third */" })
        val payload = composer.compose(listOf(r1, r2, r3), "https://facebook.com/")
        payload.css shouldBe "/* first */\n/* second */\n/* third */"
    }

    @Test
    fun `js rules separator is exactly semicolon-newline`() {
        val r1 = rule("a", js = { "alert(1)" })
        val r2 = rule("b", js = { "alert(2)" })
        val payload = composer.compose(listOf(r1, r2), "https://facebook.com/")
        payload.js shouldContain ";\n"
        payload.js shouldBe "alert(1);\nalert(2)"
    }
}
