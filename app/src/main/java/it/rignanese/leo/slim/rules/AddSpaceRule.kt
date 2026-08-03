package it.rignanese.leo.slim.rules

import it.rignanese.leo.slim.domain.InjectionRule

/**
 * Ports `addSpaceBetweenPostsCss` from Flutter `lib/utils/css.dart`. FB hosts.
 *
 * The Flutter selector is the bare `article` tag. Measured against a live
 * logged-in session 2026-08-01: Facebook renders posts as
 * `div[role="article"]`, and `article` matches **0** elements — the toggle did
 * nothing. Adding the role selector moves computed `margin-top` from `0px` to
 * `50px` on every post (verified on 2 and on 10 posts).
 *
 * The tag selector stays for mbasic mode.
 *
 * Third selector added 2026-08-03 after the UA fix: Facebook now serves the
 * mobile Bloks/MComponent DOM, where a feed story is
 * `div[data-tracking-duration-id]` and `[role="article"]` matches 0. Verified
 * on-device — computed `margin-top` moved 0px to 50px across 9 posts.
 */
class AddSpaceRule : InjectionRule {
    override val id: String = "add_space"

    override fun cssFor(url: String): String? {
        if (!RuleGates.isFbHost(url)) return null
        return CSS
    }

    private companion object {
        const val CSS =
            "article, [role=\"article\"], div[data-tracking-duration-id] " +
                "{ margin-top: 50px !important; }"
    }
}
