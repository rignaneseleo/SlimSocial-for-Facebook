package it.rignanese.leo.slim.domain

/**
 * Reproduces `PrefController.getUserAgent()` from
 * `SlimSocial_for_Facebook/lib/controllers/fb_controller.dart:19-32`.
 *
 * Precedence:
 * 1. User-supplied custom UA (when enabled and non-blank)
 * 2. Opera Mini UA when `useMbasic` is true
 * 3. Firefox UA otherwise
 */
class UserAgentResolver {
    fun resolve(customEnabled: Boolean, customUa: String?, useMbasic: Boolean): String {
        return when {
            customEnabled && !customUa.isNullOrBlank() -> customUa
            useMbasic -> UA_OPERA_MINI
            else -> UA_FIREFOX
        }
    }

    companion object {
        // The legacy Flutter app shipped a desktop Firefox 124 UA. Meta now
        // 301-redirects that combo from m./touch. to www.facebook.com/home.php,
        // which returns "Not Found" for unauthenticated users. A current mobile
        // Chrome UA keeps the request on the mobile surface and serves the
        // proper login/feed flow. Name retained for backwards compatibility.
        const val UA_FIREFOX =
            "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 " +
                "(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36"

        // Verbatim from SlimSocial_for_Facebook/lib/consts.dart:26-27
        const val UA_OPERA_MINI =
            "Opera/9.80 (Android; Opera Mini/69.0.2254/191.303; U; en) Presto/2.12.423 Version/12.16"
    }
}
