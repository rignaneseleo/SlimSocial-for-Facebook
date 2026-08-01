package it.rignanese.leo.slim.rules

import it.rignanese.leo.slim.domain.InjectionRule

/**
 * Ports `hideAdsAndPeopleYouMayKnowCss` from Flutter `lib/utils/css.dart`.
 *
 * The Flutter source was malformed — `##[data-pagelet=RightRail]` (double `#`)
 * and an unclosed `:has(>div>div>div>div>div>`. Verified 2026-08-01 by parsing
 * the payload in Chromium: the engine drops **both** blocks, so the toggle was
 * a no-op in the Flutter app — the unterminated `:has(` swallows the rest of
 * the sheet, taking the unrelated `.ego` rule down with it. Fixed here rather
 * than ported verbatim: a rule that parses to nothing cannot be "parity".
 *
 * Caveat: the RightRail selector is only known to be *valid* CSS now; whether
 * it still matches Facebook's live DOM is unverified (needs a logged-in
 * session). `.ego` is the load-bearing half and now applies.
 *
 * FB hosts.
 */
class HideAdsAndPYMKRule : InjectionRule {
    override val id: String = "hideAdsAndPeopleYouMayKnow"

    override fun cssFor(url: String): String? {
        if (!RuleGates.isFbHost(url)) return null
        return CSS
    }

    private companion object {
        const val CSS =
            "[data-pagelet=\"RightRail\"] > div > div:has(> div > div > div > div > div) " +
                "{ display: none !important; } .ego { display: none !important; }"
    }
}
