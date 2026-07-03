package it.rignanese.leo.slim.rules

import io.kotest.matchers.shouldBe
import org.junit.jupiter.api.Test

/**
 * F-Droid ships no PRO themes: the provider returns the empty source, so the
 * picker has nothing to show and the registry can never resolve a theme rule.
 */
class FdroidThemeRuleSourceTest {

    @Test
    fun `provider returns the empty source`() {
        provideThemeRuleSource() shouldBe NoThemeRuleSource
    }

    @Test
    fun `no themes are available and no id resolves`() {
        val source = provideThemeRuleSource()
        source.availableThemes shouldBe emptyList<ThemeDescriptor>()
        source.ruleFor("theme_amoled") shouldBe null
    }
}
