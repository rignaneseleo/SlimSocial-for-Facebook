package it.rignanese.leo.slim.rules

import it.rignanese.leo.slim.domain.InjectionRule

/**
 * Ports `hideAdsAndPeopleYouMayKnowCss` from Flutter `lib/utils/css.dart`.
 * Note: the source CSS contains a malformed `:has(...)` selector with an
 * unclosed paren and a leading `##`; preserved verbatim. FB hosts.
 */
class HideAdsAndPYMKRule : InjectionRule {
    override val id: String = "hideAdsAndPeopleYouMayKnow"

    override fun cssFor(url: String): String? {
        if (!RuleGates.isFbHost(url)) return null
        return CSS
    }

    private companion object {
        const val CSS =
            "##[data-pagelet=RightRail]>div>div:has(>div>div>div>div>div> { display: none !important; } .ego { display: none !important; }"
    }
}
