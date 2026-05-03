package it.rignanese.leo.slim.domain

/**
 * Facebook URL/suffix constants ported verbatim from
 * `SlimSocial_for_Facebook/lib/consts.dart` (lines 1-3, 17-19).
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
