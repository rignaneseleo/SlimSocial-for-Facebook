package it.rignanese.leo.slim.domain

/**
 * Facebook URL/suffix constants. The original native SlimSocial used
 * `touch.facebook.com/home.php` with a Chrome OS UA and it worked for years.
 *
 * `touch.facebook.com` 301-redirects to `www.facebook.com/home.php`; under a
 * *mobile* UA that lands on a bare "Not Found"/blank page, which is why the
 * Flutter-era rewrite switched to `m.facebook.com`. But `m.facebook.com` under
 * a WebView serves a height-0 "Bloks" page (blank white). With the desktop-class
 * Chrome OS UA (see [UserAgentResolver]) the touch→www redirect resolves to a
 * proper, rendering login/feed — so we restore the proven native host.
 */
object FbConstants {
    const val URL_TOUCH = "https://touch.facebook.com/home.php"
    const val URL_MBASIC = "https://mbasic.facebook.com/home.php"
    const val SUFFIX_RECENT = "?sk=h_chr"
    const val SUFFIX_DEFAULT = "?sk=h_nor"
}

/**
 * Builds the initial Facebook home URL based on the user's `useMbasic` and
 * `recentFirst` toggles, replicating
 * `SlimSocial_for_Facebook/lib/controllers/fb_controller.dart:7-17`.
 */
class HomeUrlBuilder {
    fun build(useMbasic: Boolean, recentFirst: Boolean): String {
        val base = if (useMbasic) FbConstants.URL_MBASIC else FbConstants.URL_TOUCH
        val suffix = if (recentFirst) FbConstants.SUFFIX_RECENT else FbConstants.SUFFIX_DEFAULT
        return base + suffix
    }
}
