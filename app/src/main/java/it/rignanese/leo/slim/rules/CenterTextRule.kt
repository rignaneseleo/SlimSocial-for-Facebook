package it.rignanese.leo.slim.rules

import it.rignanese.leo.slim.domain.InjectionRule

/**
 * Ports `centerTextPostsCss` from Flutter `lib/utils/css.dart`. FB hosts only
 * (excluding messenger).
 *
 * The Flutter selector `._5rgt._5msi` targets the old touch/mbasic DOM.
 * Measured against a live logged-in session 2026-08-01: it matches **0**
 * elements on the layout Facebook serves today. The post body is now marked up
 * with Facebook's own semantic hooks, `data-ad-preview="message"` /
 * `data-ad-rendering-role="story_message"` — verified to flip computed
 * `text-align` from `start` to `center` on 4-14 posts.
 *
 * Both selectors ship: the legacy one still applies in mbasic mode, which the
 * app can still be switched to.
 */
class CenterTextRule : InjectionRule {
    override val id: String = "center_text"

    override fun cssFor(url: String): String? {
        if (!RuleGates.isFbHost(url) || RuleGates.isMessengerHost(url)) return null
        return CSS
    }

    private companion object {
        const val CSS =
            "._5rgt._5msi { text-align: center; } " +
                "[data-ad-preview=\"message\"], [data-ad-rendering-role=\"story_message\"] " +
                "{ text-align: center !important; }"
    }
}
