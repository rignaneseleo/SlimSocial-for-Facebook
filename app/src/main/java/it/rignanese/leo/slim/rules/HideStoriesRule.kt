package it.rignanese.leo.slim.rules

import it.rignanese.leo.slim.domain.InjectionRule

/**
 * Ports `hideStoriesCss` from Flutter `lib/utils/css.dart`. FB hosts.
 */
class HideStoriesRule : InjectionRule {
    override val id: String = "hide_stories"

    override fun cssFor(url: String): String? {
        if (!RuleGates.isFbHost(url)) return null
        return CSS
    }

    private companion object {
        const val CSS = "#MStoriesTray { display: none !important; }"
    }
}
