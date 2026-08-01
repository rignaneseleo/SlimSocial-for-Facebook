package it.rignanese.leo.slim.rules

import it.rignanese.leo.slim.domain.InjectionRule

/**
 * Ports `hideStoriesCss` from Flutter `lib/utils/css.dart`. FB hosts.
 *
 * `#MStoriesTray` is the old touch/mbasic id and matches **0** elements on the
 * layout Facebook serves today (measured 2026-08-01 on a live session).
 *
 * ⚠️ Unlike the other re-targeted rules, the replacement selectors here are
 * **unverified**: the test account has no friends, so no story tray ever
 * rendered and there was nothing to measure against. `[aria-label="Stories"]`
 * (and the Italian `Storie`) is the documented ARIA labelling Facebook uses
 * for the tray, but treat it as a best guess until someone confirms it on an
 * account with stories. The legacy id is kept for mbasic.
 */
class HideStoriesRule : InjectionRule {
    override val id: String = "hide_stories"

    override fun cssFor(url: String): String? {
        if (!RuleGates.isFbHost(url)) return null
        return CSS
    }

    private companion object {
        const val CSS =
            "#MStoriesTray, [aria-label=\"Stories\"], [aria-label=\"Storie\"] " +
                "{ display: none !important; }"
    }
}
