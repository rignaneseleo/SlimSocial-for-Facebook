package it.rignanese.leo.slim.rules

import it.rignanese.leo.slim.domain.InjectionRule

/**
 * Pins Facebook's top navigation bar so it stays visible while scrolling.
 *
 * History: the original Flutter `fixedBarCss` used `#header { position: fixed }`
 * plus `#root { padding-top: 84px }` to offset the now-fixed header, and carried
 * a broken `.flyout { max-height: ${'$'}spx }` — a Dart string-interpolation token
 * (`${'$'}{size}px`) that never got substituted, so it shipped invalid CSS. Worse,
 * the unconditional `#root { padding-top: 84px }` fired on **every** FB page,
 * including the pre-login cookie-consent and login interstitials (which have no
 * `#header` to compensate for): it shoved their content down and, on the consent
 * page, collapsed the layout entirely behind Facebook's gray scrim.
 *
 * Modern fix: use `position: sticky` on the bar itself. Sticky keeps the bar
 * pinned during scroll while leaving it in normal flow, so no `#root` padding
 * hack is needed — and when the bar is absent (every pre-login page), the
 * selectors simply match nothing and the page is untouched. Covers both the
 * mbasic `#header` and the modern touch site's `[role="banner"]`.
 *
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
            "#header, [role=\"banner\"] { position: sticky !important; top: 0 !important; z-index: 6 !important; }"
    }
}
