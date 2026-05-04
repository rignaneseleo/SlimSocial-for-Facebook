package it.rignanese.leo.slim.rules

import it.rignanese.leo.slim.domain.InjectionRule

/**
 * Ports `fixedBarCss` from Flutter `lib/utils/css.dart`. The original used a
 * Dart raw string containing the literal `${'$'}spx` token; preserved verbatim.
 * FB hosts.
 */
class FixedBarRule : InjectionRule {
    override val id: String = "fixed_bar"

    override fun cssFor(url: String): String? {
        if (!RuleGates.isFbHost(url)) return null
        return CSS
    }

    private companion object {
        const val CSS =
            "#header { position: fixed; z-index: 6; top: 0px; } #root { padding-top: 84px; } .flyout { max-height: ${'$'}spx; overflow-y: scroll; } .item.more { position: fixed; bottom: 0px; text-align: center !important; }"
    }
}
