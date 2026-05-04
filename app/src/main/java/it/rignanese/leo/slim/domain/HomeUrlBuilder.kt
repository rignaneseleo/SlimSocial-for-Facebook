package it.rignanese.leo.slim.domain

/**
 * Facebook URL/suffix constants. Originally ported from the Flutter app's
 * `lib/consts.dart`, which used `touch.facebook.com`. Meta now 301-redirects
 * that host to `www.facebook.com/home.php`, which serves a bare "Not Found"
 * page when unauthenticated — so we point the default at `m.facebook.com`,
 * the live mobile surface that still serves a proper login flow.
 */
object FbConstants {
    const val URL_TOUCH = "https://m.facebook.com/home.php"
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
