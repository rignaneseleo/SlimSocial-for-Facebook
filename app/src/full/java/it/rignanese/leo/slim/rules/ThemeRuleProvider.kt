package it.rignanese.leo.slim.rules

import it.rignanese.leo.slim.R
import it.rignanese.leo.slim.domain.InjectionRule

/**
 * Full (Play Store) flavor theme catalog. The same top-level function is
 * declared in the `fdroid` source set (returning [NoThemeRuleSource]);
 * Kotlin resolves the correct definition at flavor build time.
 */
fun provideThemeRuleSource(): ThemeRuleSource = FullThemeRuleSource

internal object FullThemeRuleSource : ThemeRuleSource {

    private val rules: Map<String, InjectionRule> = listOf(
        AmoledThemeRule(),
        AccentThemeRule(ThemeIds.ACCENT_GREEN, "#1b7f4d"),
        AccentThemeRule(ThemeIds.ACCENT_PURPLE, "#7b46b8"),
        AccentThemeRule(ThemeIds.ACCENT_ORANGE, "#d9662a"),
        CompactThemeRule(),
    ).associateBy { it.id }

    override val availableThemes: List<ThemeDescriptor> = listOf(
        ThemeDescriptor(ThemeIds.AMOLED, R.string.theme_amoled, 0xFF000000),
        ThemeDescriptor(ThemeIds.ACCENT_GREEN, R.string.theme_accent_green, 0xFF1B7F4D),
        ThemeDescriptor(ThemeIds.ACCENT_PURPLE, R.string.theme_accent_purple, 0xFF7B46B8),
        ThemeDescriptor(ThemeIds.ACCENT_ORANGE, R.string.theme_accent_orange, 0xFFD9662A),
        ThemeDescriptor(ThemeIds.COMPACT, R.string.theme_compact, 0xFF9AA0A6),
    )

    override fun ruleFor(themeId: String): InjectionRule? = rules[themeId]
}
