package it.rignanese.leo.slim.rules

import it.rignanese.leo.slim.domain.InjectionRule

/**
 * Ports `hideMessengerSidebar` from Flutter `lib/utils/css.dart`. Messenger
 * hosts only.
 */
class HideMessengerSidebarRule : InjectionRule {
    override val id: String = "hide_messenger_sidebar"

    override fun cssFor(url: String): String? {
        if (!RuleGates.isMessengerHost(url)) return null
        return CSS
    }

    private companion object {
        const val CSS =
            ".x9f619.x1n2onr6.x1ja2u2z.x78zum5.xdt5ytf.xu1343h.x26u7qi.xy80clv.x1yu6fn4.xs83m0k.x1dt7z5j.x2ixbly {display: none;}"
    }
}
