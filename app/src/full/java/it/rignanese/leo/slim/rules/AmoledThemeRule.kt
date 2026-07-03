package it.rignanese.leo.slim.rules

import it.rignanese.leo.slim.domain.InjectionRule

/**
 * PRO theme: true-black AMOLED variant. Composes after the free
 * [DarkThemeRule] in [RuleRegistry] order, so on shared selectors the
 * later-injected `!important` declarations win the cascade and true black
 * replaces the free theme's translucent grays.
 */
class AmoledThemeRule : InjectionRule {
    override val id: String = ThemeIds.AMOLED

    override fun cssFor(url: String): String? {
        if (!RuleGates.isFbHost(url)) return null
        return CSS
    }

    private companion object {
        val CSS = """
/* SlimSocial PRO — AMOLED black */
* {
    border-color: #111111 !important;
    color: #e4e6eb !important;
    background-color: transparent !important;
}
html, body, body ._li, #root, #page, #viewport, #screen-root {
    background: #000000 !important;
    background-color: #000000 !important;
}
#header, #pagelet_bluebar, ._52z5, .stickyHeaderWrap, ._1kf5 {
    background-color: #000000 !important;
    border-bottom: 1px solid #111111 !important;
}
._4-u2, ._55wo, ._55wm, ._5rgr, .card, .fbNubFlyoutOuter, .uiMenuInner {
    background-color: #000000 !important;
    border-color: #111111 !important;
}
input, textarea, select, td .inputtext {
    background-color: #0a0a0a !important;
    color: #e4e6eb !important;
}
a {
    color: #8ab4f8 !important;
}
"""
    }
}
