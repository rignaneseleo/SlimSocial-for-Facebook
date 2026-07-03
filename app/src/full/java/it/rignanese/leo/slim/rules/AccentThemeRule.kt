package it.rignanese.leo.slim.rules

import it.rignanese.leo.slim.domain.InjectionRule

/**
 * PRO theme: re-tints the Facebook chrome (top bar, links, action buttons,
 * badges) with a single accent color. One class, one instance per shipped
 * variant — see the catalog in `ThemeRuleProvider.kt`.
 */
class AccentThemeRule(
    override val id: String,
    private val accentHex: String,
) : InjectionRule {

    override fun cssFor(url: String): String? {
        if (!RuleGates.isFbHost(url)) return null
        return """
/* SlimSocial PRO — accent theme ($accentHex) */
#header, #pagelet_bluebar, ._52z5, ._1kf5, .stickyHeaderWrap {
    background-color: $accentHex !important;
}
a, ._5fpq, ._52jh, ._4g34 {
    color: $accentHex !important;
}
span._59tg, .jewelItemNew, ._1b1b {
    background-color: $accentHex !important;
}
button[type=submit], ._4jy1, input[type=submit], ._54k8._56bs {
    background-color: $accentHex !important;
    border-color: $accentHex !important;
}
/* Keep header content readable on the accent background. */
#header a, #header ._52jh, #header span {
    color: #ffffff !important;
}
"""
    }
}
