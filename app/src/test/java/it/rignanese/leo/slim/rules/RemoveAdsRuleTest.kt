package it.rignanese.leo.slim.rules

import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import org.junit.jupiter.api.Test

class RemoveAdsRuleTest {
    private val rule = RemoveAdsRule()

    private val keywords = listOf(
        "Sponsorisé",
        "Sponsored",
        "Patrocinado",
        "Publicidad",
        "Gesponsert",
        "Sponsorizzato",
        "Sponsrad",
        "Được tài trợ",
        "贊助內容",
        "赞助内容",
        "スポンサーされた投稿",
        "Sponsorowane",
        "Реклама",
        "Sponzorirano",
        "प्रायोजित",
        "স্পনসরড",
        "பராமரிக்கப்பட்ட",
        "ప్రచారం చేసిన",
        "ಪ್ರಾಯೋಜಿತ",
        "സ്പോൺസർ ചെയ്യപ്പെട്ട",
        "ਸਰਪ੍ਰਸਤ",
        "प्रायोजित",
        "સ્પોન્સર્ડ",
        "سپانسرڈ",
        "โพสต์ที่ได้รับการสนับสนุน",
    )

    @Test
    fun `id matches`() {
        rule.id shouldBe "hide_ads"
    }

    @Test
    fun `applies on facebook`() {
        val js = rule.jsFor("https://m.facebook.com/foo")!!
        js shouldContain "removeAds"
    }

    @Test
    fun `does not apply on messenger`() {
        rule.jsFor("https://www.messenger.com/inbox") shouldBe null
    }

    @Test
    fun `does not apply on unknown hosts`() {
        rule.jsFor("https://example.com/") shouldBe null
    }

    @Test
    fun `contains all sponsor keywords across 23 languages`() {
        val js = rule.jsFor("https://m.facebook.com/foo")!!
        // Note: the spec lists 25 entries; two languages (Spanish and Chinese)
        // contribute two keywords each, so the language count is 23 with 25
        // distinct keyword strings.
        keywords.forEach { kw -> js shouldContain kw }
    }

    @Test
    fun `contains the MutationObserver block`() {
        val js = rule.jsFor("https://m.facebook.com/foo")!!
        js shouldContain "MutationObserver"
        js shouldContain "newPostsObserver"
    }

    @Test
    fun `css is not produced`() {
        rule.cssFor("https://m.facebook.com/foo") shouldBe null
    }
}
