package it.rignanese.leo.slim.rules

import it.rignanese.leo.slim.domain.InjectionRule

/**
 * Ports `hideStoriesCss` from Flutter `lib/utils/css.dart`. FB hosts.
 *
 * `#MStoriesTray` is the old touch/mbasic id and matches **0** elements on the
 * layout Facebook serves today (measured 2026-08-01 on a live session).
 *
 * On the mobile Bloks DOM that Facebook serves after the UA fix, the tray is a
 * horizontal scroller: `[data-is-h-scrollable="true"]`. Verified on-device
 * 2026-08-03 on an account with stories — computed `display` moved flex to
 * none and the tray disappeared from the feed.
 *
 * Three caveats:
 *  - The parent is collapsed via `:has()` as well, because hiding only the
 *    scroller left a tall blank gap in the feed — Bloks sets an explicit
 *    height on the container. The gap was observed on-device; **the `:has()`
 *    fix itself is not yet verified there** (the device became unavailable
 *    mid-test). Confirm before trusting it.
 *  - Horizontal scrollers are also used for Reels rows, so those go too. There
 *    is no attribute distinguishing a story tray from a reels tray.
 *  - `:has()` needs a modern engine. Fine on the WebView this targets
 *    (Chrome 150) but it will silently no-op on very old System WebViews.
 *
 * `[aria-label="Stories"]` remains for the desktop DOM and is still
 * unverified (no desktop session with stories was available); `#MStoriesTray`
 * remains for mbasic.
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
                "{ display: none !important; } " +
                // Collapse the parent too: Bloks gives it an explicit height,
                // so hiding only the scroller leaves a tall blank gap.
                "div[data-mcomponent=\"MContainer\"]:has(> [data-is-h-scrollable=\"true\"]) " +
                "{ display: none !important; } " +
                "[data-is-h-scrollable=\"true\"] { display: none !important; }"
    }
}
