package it.rignanese.leo.slim.rules

import it.rignanese.leo.slim.domain.InjectionRule

/**
 * Ports `addSpaceBetweenPostsCss` from Flutter `lib/utils/css.dart`. FB hosts.
 */
class AddSpaceRule : InjectionRule {
    override val id: String = "add_space"

    override fun cssFor(url: String): String? {
        if (!RuleGates.isFbHost(url)) return null
        return CSS
    }

    private companion object {
        const val CSS = "article { margin-top: 50px !important; }"
    }
}
