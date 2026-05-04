package it.rignanese.leo.slim.rules

import it.rignanese.leo.slim.domain.InjectionRule

/**
 * Ports `removeMessengerDownloadCss` from Flutter `lib/utils/css.dart`.
 * Messenger hosts.
 */
class RemoveMessengerDownloadRule : InjectionRule {
    override val id: String = "removeMessengerDownload"

    override fun cssFor(url: String): String? {
        if (!RuleGates.isMessengerHost(url)) return null
        return CSS
    }

    private companion object {
        const val CSS =
            "._s15 { display: none; } input { -webkit-user-select: text; } [data-sigil*=m-promo-jewel-header] { display: none; }"
    }
}
