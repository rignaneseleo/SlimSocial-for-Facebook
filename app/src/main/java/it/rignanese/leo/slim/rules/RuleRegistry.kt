package it.rignanese.leo.slim.rules

import it.rignanese.leo.slim.domain.InjectionRule
import it.rignanese.leo.slim.domain.Settings

/**
 * Resolves the active set of [InjectionRule]s for the given [Settings].
 * Pure function — no Android imports, no I/O — so it can be unit tested
 * directly on the JVM.
 */
class RuleRegistry {
    fun activeRules(s: Settings): List<InjectionRule> = buildList {
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
        if (s.features.hideAds) add(RemoveAdsRule())
        add(UserCustomCssRule(s.customization))
        add(UserCustomJsRule(s.customization))
    }
}
