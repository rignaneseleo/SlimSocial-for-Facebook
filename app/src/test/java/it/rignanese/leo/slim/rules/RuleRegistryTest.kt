package it.rignanese.leo.slim.rules

import io.kotest.matchers.collections.shouldContain
import io.kotest.matchers.collections.shouldContainExactly
import io.kotest.matchers.shouldBe
import it.rignanese.leo.slim.domain.InjectionRule
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

    // ------------------------------------------------------------------
    // PRO theme gating
    // ------------------------------------------------------------------

    private val themedRegistry = RuleRegistry(FakeThemeRuleSource)

    private fun themedSettings(theme: String? = "test_theme") = Settings.DEFAULT.copy(
        style = Settings.DEFAULT.style.copy(darkTheme = true, selectedTheme = theme),
    )

    @Test
    fun `pro user with a selected theme gets the theme rule`() {
        val ids = themedRegistry.activeRules(themedSettings(), isPro = true).map { it.id }
        ids shouldContain "test_theme"
    }

    @Test
    fun `theme rule composes after dark theme and before user custom rules`() {
        val ids = themedRegistry.activeRules(themedSettings(), isPro = true).map { it.id }
        // Later CSS wins on equal-specificity !important conflicts, so the
        // theme must come after the free dark rule; user snippets stay last.
        (ids.indexOf("test_theme") > ids.indexOf("dark_theme")) shouldBe true
        (ids.indexOf("test_theme") < ids.indexOf("user_css")) shouldBe true
    }

    @Test
    fun `non-pro user never gets the theme rule even with a stored selection`() {
        val ids = themedRegistry.activeRules(themedSettings(), isPro = false).map { it.id }
        (ids.contains("test_theme")) shouldBe false
    }

    @Test
    fun `pro user with no selected theme gets no theme rule`() {
        val ids = themedRegistry.activeRules(themedSettings(theme = null), isPro = true).map { it.id }
        (ids.contains("test_theme")) shouldBe false
    }

    @Test
    fun `unknown theme id resolves to no rule`() {
        val ids = themedRegistry.activeRules(themedSettings(theme = "gone"), isPro = true).map { it.id }
        (ids.contains("gone")) shouldBe false
    }

    @Test
    fun `default registry has no theme source and stays theme-free`() {
        val ids = registry.activeRules(themedSettings(), isPro = true).map { it.id }
        (ids.contains("test_theme")) shouldBe false
    }
}

private object FakeThemeRuleSource : ThemeRuleSource {
    override val availableThemes = listOf(ThemeDescriptor("test_theme", 0, 0xFF000000))
    override fun ruleFor(themeId: String): InjectionRule? =
        if (themeId == "test_theme") {
            object : InjectionRule {
                override val id = "test_theme"
                override fun cssFor(url: String) = "/* test theme css */"
            }
        } else {
            null
        }
}
