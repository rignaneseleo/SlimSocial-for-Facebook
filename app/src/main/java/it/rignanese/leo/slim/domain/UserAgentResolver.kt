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
        // A Chrome OS (Chromebook) UA — the exact approach the original native
        // SlimSocial (pre-Flutter) shipped, which worked for years.
        //
        // Why not a mobile UA: Facebook fingerprints the Android WebView (mobile
        // UA string + `Sec-CH-UA: "Android WebView"` client hint, which the UA
        // string can't hide) and serves a "Bloks" mobile page that collapses to
        // html/body height 0 in a plain WebView — a blank white screen. Verified
        // on-device: every mobile UA => body height 0; a desktop-class UA =>
        // renders. Chrome OS is a touch-capable desktop, so Facebook serves a
        // responsive layout that scales to fit a phone (with wide-viewport +
        // overview mode + zoom, mirroring the old app's `setDesktopMode(true)`).
        // Name retained for backwards compatibility.
        const val UA_FIREFOX =
            "Mozilla/5.0 (X11; CrOS x86_64 14541.0.0) AppleWebKit/537.36 " +
                "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

        // Verbatim from SlimSocial_for_Facebook/lib/consts.dart:26-27
        const val UA_OPERA_MINI =
            "Opera/9.80 (Android; Opera Mini/69.0.2254/191.303; U; en) Presto/2.12.423 Version/12.16"
    }
}
