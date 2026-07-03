package it.rignanese.leo.slim.rules

import it.rignanese.leo.slim.domain.InjectionRule

/**
 * Descriptor of a PRO page theme, consumed by the full-flavor theme picker.
 *
 * @param id stable theme id stored in `Settings.style.selectedTheme`
 * @param nameRes display-name string resource (lives in the flavor's res)
 * @param previewArgb ARGB swatch color shown in the picker preview
 */
data class ThemeDescriptor(
    val id: String,
    val nameRes: Int,
    val previewArgb: Long,
)

/**
 * Flavor-split source of PRO theme rules. The `full` flavor provides the
 * real catalog; `fdroid` returns [NoThemeRuleSource] so no PRO theme code
 * ships on F-Droid. Resolved via the top-level `provideThemeRuleSource()`
 * function declared in each flavor source set — the same pattern as
 * `providePlatform` (see `platform/PlatformProvider.kt` in both flavors).
 */
interface ThemeRuleSource {
    val availableThemes: List<ThemeDescriptor>

    /** The [InjectionRule] for [themeId], or null when the id is unknown. */
    fun ruleFor(themeId: String): InjectionRule?
}

/** Empty source: no themes. Used by `fdroid` and as the [RuleRegistry] default. */
object NoThemeRuleSource : ThemeRuleSource {
    override val availableThemes: List<ThemeDescriptor> = emptyList()
    override fun ruleFor(themeId: String): InjectionRule? = null
}
