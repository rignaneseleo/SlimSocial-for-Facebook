package it.rignanese.leo.slim.rules

import it.rignanese.leo.slim.domain.InjectionRule

/**
 * Ports `centerTextPostsCss` from Flutter `lib/utils/css.dart`. FB hosts only
 * (excluding messenger).
 */
class CenterTextRule : InjectionRule {
    override val id: String = "center_text"

    override fun cssFor(url: String): String? {
        if (!RuleGates.isFbHost(url) || RuleGates.isMessengerHost(url)) return null
        return CSS
    }

    private companion object {
        const val CSS = "._5rgt._5msi { text-align: center;}"
    }
}
