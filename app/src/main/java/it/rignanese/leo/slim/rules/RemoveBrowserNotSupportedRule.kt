package it.rignanese.leo.slim.rules

import it.rignanese.leo.slim.domain.InjectionRule

/**
 * Ports `removeBrowserNotSupportedCss` from Flutter `lib/utils/css.dart`.
 * Applies to any FB or messenger host.
 */
class RemoveBrowserNotSupportedRule : InjectionRule {
    override val id: String = "removeBrowserNotSupported"

    override fun cssFor(url: String): String? {
        if (!RuleGates.isFbHost(url) && !RuleGates.isMessengerHost(url)) return null
        return CSS
    }

    private companion object {
        const val CSS = "#header-notices { display: none; }"
    }
}
