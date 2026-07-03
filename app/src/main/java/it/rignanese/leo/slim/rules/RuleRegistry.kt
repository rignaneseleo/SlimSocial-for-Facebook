package it.rignanese.leo.slim.rules

import it.rignanese.leo.slim.domain.InjectionRule
import it.rignanese.leo.slim.domain.Settings

/**
 * Resolves the active set of [InjectionRule]s for the given [Settings].
 * Pure function — no Android imports, no I/O — so it can be unit tested
 * directly on the JVM.
 *
 * PRO page themes come from the flavor-split [themeRuleSource] and apply
 * only when [activeRules] is called with `isPro = true`. The theme rule is
 * appended after the free dark rules — later CSS wins equal-specificity
 * `!important` conflicts, so the theme overrides the free dark mode — and
 * before the user-custom rules, so user snippets keep the last word.
 */
class RuleRegistry(
    private val themeRuleSource: ThemeRuleSource = NoThemeRuleSource,
) {
    fun activeRules(s: Settings, isPro: Boolean = false): List<InjectionRule> = buildList {
        if (s.style.centerText) add(CenterTextRule())
        if (s.style.hideMessengerSidebar) add(HideMessengerSidebarRule())
        if (s.style.addSpace) add(AddSpaceRule())
        if (s.style.hideStories) add(HideStoriesRule())
        if (s.style.fixedBar) add(FixedBarRule())
        if (s.style.removeMessengerDownload) add(RemoveMessengerDownloadRule())
        if (s.style.removeBrowserNotSupported) add(RemoveBrowserNotSupportedRule())
        if (s.style.hideAdsAndPeopleYouMayKnow) add(HideAdsAndPYMKRule())
        if (s.style.fabBtn) add(FabButtonRule())
        if (s.style.adaptMessenger) add(AdaptMessengerRule())
        if (s.style.darkTheme) add(DarkThemeRule())
        if (s.style.darkThemeMessenger) add(DarkThemeMessengerRule())
        if (isPro) {
            s.style.selectedTheme
                ?.let { themeRuleSource.ruleFor(it) }
                ?.let { add(it) }
        }
        if (s.features.hideAds) add(RemoveAdsRule())
        add(UserCustomCssRule(s.customization))
        add(UserCustomJsRule(s.customization))
    }
}
