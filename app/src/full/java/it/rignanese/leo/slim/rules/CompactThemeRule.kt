package it.rignanese.leo.slim.rules

import it.rignanese.leo.slim.domain.InjectionRule

/**
 * PRO theme: compact mode — smaller base font, tighter paddings and story
 * spacing for information density on small screens.
 */
class CompactThemeRule : InjectionRule {
    override val id: String = ThemeIds.COMPACT

    override fun cssFor(url: String): String? {
        if (!RuleGates.isFbHost(url)) return null
        return CSS
    }

    private companion object {
        val CSS = """
/* SlimSocial PRO — compact mode */
body {
    font-size: 13px !important;
    line-height: 1.25 !important;
}
._55wo, ._55wm, ._4-u2, ._5rgr, .story_body_container {
    padding: 4px 6px !important;
    margin: 0 0 4px 0 !important;
}
._2vxa, ._5rgt, ._5msi {
    font-size: 13px !important;
}
#header, ._52z5 {
    min-height: 36px !important;
}
._4-u8, .item {
    margin-bottom: 4px !important;
}
"""
    }
}
