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
        // Verbatim from SlimSocial_for_Facebook/lib/consts.dart:22-23
        const val UA_FIREFOX =
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:124.0) Gecko/20100101 Firefox/124.0"

        // Verbatim from SlimSocial_for_Facebook/lib/consts.dart:26-27
        const val UA_OPERA_MINI =
            "Opera/9.80 (Android; Opera Mini/69.0.2254/191.303; U; en) Presto/2.12.423 Version/12.16"
    }
}
