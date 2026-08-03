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
 * All three ship: the legacy one still applies in mbasic mode, the
 * `data-ad-*` pair to the desktop DOM, and the third to the mobile
 * Bloks/MComponent DOM Facebook serves after the UA fix, where post copy is a
 * `.native-text` div inside a `[data-mcomponent="TextArea"]`. Verified
 * on-device 2026-08-03 — computed `text-align` moved start to center.
 *
 * Known imprecision on mobile: a post's author line and timestamp are also
 * TextAreas, so they can centre too. Bloks exposes no attribute that marks the
 * message specifically; distinguishing it would need JS to tag the longest
 * block, which is not worth the machinery for a cosmetic toggle.
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
                "{ text-align: center !important; } " +
                "div[data-tracking-duration-id] [data-mcomponent=\"TextArea\"] .native-text " +
                "{ text-align: center !important; }"
    }
}
