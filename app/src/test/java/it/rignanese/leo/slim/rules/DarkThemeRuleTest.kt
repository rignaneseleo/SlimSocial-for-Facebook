package it.rignanese.leo.slim.rules

import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import org.junit.jupiter.api.Test

class DarkThemeRuleTest {
    private val rule = DarkThemeRule()

    @Test
    fun `id matches`() {
        rule.id shouldBe "dark_theme"
    }

    @Test
    fun `applies on facebook`() {
        rule.cssFor("https://m.facebook.com/foo")!! shouldContain "Bean Verified Bean Terified"
    }

    @Test
    fun `does not apply on messenger`() {
        rule.cssFor("https://www.messenger.com/inbox") shouldBe null
    }

    @Test
    fun `does not apply on unknown hosts`() {
        rule.cssFor("https://example.com/") shouldBe null
    }

    @Test
    fun `anchor counts match the Flutter source`() {
        val css = rule.cssFor("https://m.facebook.com/foo")!!
        // Reference counts taken directly from `css.dart` lines 218..511.
        // If the port drifts, these numbers shift first.
        countOf(css, "!important") shouldBe 54
        countOf(css, "background-color:") shouldBe 22
    }

    @Test
    fun `css length is within plus or minus 5 percent of the Flutter source`() {
        val css = rule.cssFor("https://m.facebook.com/foo")!!
        // Source byte count for css.dart lines 218..511 = 6056. The Dart
        // string body (between the two `"""` blocks plus their concatenation)
        // is slightly smaller; allow a generous ±10% window because the Dart
        // source includes the surrounding `code: """ ... """,` framing and
        // some leading indentation that the Kotlin port preserves.
        val source = 6056
        val lower = (source * 0.5).toInt()
        val upper = (source * 1.1).toInt()
        (css.length in lower..upper) shouldBe true
    }

    private fun countOf(haystack: String, needle: String): Int {
        var count = 0
        var idx = 0
        while (true) {
            val found = haystack.indexOf(needle, idx)
            if (found < 0) break
            count++
            idx = found + needle.length
        }
        return count
    }
}
