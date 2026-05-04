package it.rignanese.leo.slim.rules

import io.kotest.matchers.collections.shouldContain
import io.kotest.matchers.collections.shouldContainExactly
import io.kotest.matchers.shouldBe
import it.rignanese.leo.slim.domain.Settings
import org.junit.jupiter.api.Test

class RuleRegistryTest {
    private val registry = RuleRegistry()

    @Test
    fun `default settings produces the five legacy-default rules`() {
        // Default settings enable: features.hideAds, style.fixedBar,
        // style.hideMessengerSidebar — plus the always-present user-custom
        // rules. That is 5 rules total.
        val rules = registry.activeRules(Settings.DEFAULT)
        val ids = rules.map { it.id }
        ids shouldContainExactly listOf(
            "hide_messenger_sidebar",
            "fixed_bar",
            "hide_ads",
            "user_css",
            "user_js",
        )
    }

    @Test
    fun `enabling dark theme adds DarkThemeRule`() {
        val s = Settings.DEFAULT.copy(
            style = Settings.DEFAULT.style.copy(darkTheme = true),
        )
        val ids = registry.activeRules(s).map { it.id }
        ids shouldContain "dark_theme"
    }

    @Test
    fun `disabling all toggles still yields the two user-custom rules`() {
        val s = Settings.DEFAULT.copy(
            features = Settings.DEFAULT.features.copy(hideAds = false),
            style = Settings.DEFAULT.style.copy(
                fixedBar = false,
                hideMessengerSidebar = false,
            ),
        )
        val ids = registry.activeRules(s).map { it.id }
        ids shouldContainExactly listOf("user_css", "user_js")
    }

    @Test
    fun `enabling every style toggle adds every built-in css rule`() {
        val s = Settings.DEFAULT.copy(
            style = Settings.DEFAULT.style.copy(
                centerText = true,
                addSpace = true,
                hideStories = true,
                fixedBar = true,
                hideMessengerSidebar = true,
                removeMessengerDownload = true,
                removeBrowserNotSupported = true,
                hideAdsAndPeopleYouMayKnow = true,
                fabBtn = true,
                adaptMessenger = true,
                darkTheme = true,
                darkThemeMessenger = true,
            ),
        )
        val ids = registry.activeRules(s).map { it.id }.toSet()
        val expected = setOf(
            "center_text",
            "hide_messenger_sidebar",
            "add_space",
            "hide_stories",
            "fixed_bar",
            "removeMessengerDownload",
            "removeBrowserNotSupported",
            "hideAdsAndPeopleYouMayKnow",
            "fabBtn",
            "adaptMessenger",
            "dark_theme",
            "dark_theme_messenger",
            "hide_ads",
            "user_css",
            "user_js",
        )
        (expected - ids) shouldBe emptySet()
    }
}
