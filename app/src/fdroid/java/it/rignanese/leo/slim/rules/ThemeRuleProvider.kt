package it.rignanese.leo.slim.rules

/**
 * F-Droid flavor: no PRO themes — the real catalog lives only in `src/full`
 * so no theme code (or dead paywall) ships on F-Droid. Same flavor-split
 * pattern as `providePlatform`.
 */
fun provideThemeRuleSource(): ThemeRuleSource = NoThemeRuleSource
