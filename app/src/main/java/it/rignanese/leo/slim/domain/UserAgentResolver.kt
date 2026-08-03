package it.rignanese.leo.slim.domain

/**
 * Reproduces `PrefController.getUserAgent()` from
 * `SlimSocial_for_Facebook/lib/controllers/fb_controller.dart:19-32`.
 *
 * Precedence:
 * 1. User-supplied custom UA (when enabled and non-blank)
 * 2. Opera Mini UA when `useMbasic` is true
 * 3. The device's own WebView UA with the `wv` token removed
 */
class UserAgentResolver(
    /**
     * The platform WebView's default UA (`WebSettings.getDefaultUserAgent`).
     * Defaults to [UA_FIREFOX] so pure-JVM callers and tests need no Android.
     */
    private val deviceUserAgent: String = UA_FIREFOX,
) {
    fun resolve(customEnabled: Boolean, customUa: String?, useMbasic: Boolean): String {
        return when {
            customEnabled && !customUa.isNullOrBlank() -> customUa
            useMbasic -> UA_OPERA_MINI
            else -> stripWebViewToken(deviceUserAgent)
        }
    }

    companion object {
        /**
         * Removes the `; wv` marker Android inserts into every WebView UA.
         *
         * This one token is the whole ballgame. Measured on a Pixel 10 Pro
         * (Android 17, WebView 150) against the live site on 2026-08-03, by
         * driving the app's own WebView over its DevTools socket and opening
         * the notifications panel under four user agents:
         *
         * | UA                          | `; wv)` | notifications panel      |
         * |-----------------------------|---------|--------------------------|
         * | WebView default             | yes     | collapses to height 0    |
         * | Firefox 124 desktop         | no      | collapses to height 0    |
         * | Chrome OS desktop           | no      | collapses to height 0    |
         * | Chrome Android (no `wv`)    | no      | **works**                |
         *
         * With `wv` present Facebook serves a bundle whose popover never lays
         * out: the panel exists with 330 children of real text, is positioned
         * correctly (`max-height: 568px`), and computes to `height: 0px`. The
         * desktop UAs dodge the WebView sniff but land on the desktop popover,
         * which collapses the same way. A plain Chrome-for-Android UA gets the
         * mobile bundle, where notifications are a route (`/notifications/`)
         * rather than a popover — and that renders.
         *
         * Deriving from the device UA instead of hardcoding a fake phone keeps
         * the Android version, model and Chrome version truthful; only the
         * WebView marker is dropped.
         *
         * Historical note: the KDoc here used to claim any mobile UA yields a
         * blank height-0 "Bloks" page. Re-measured on-device 2026-08-03 —
         * mobile UA renders a full feed (`body` height 4917px). That claim was
         * true in July and is not true now; do not restore a desktop UA on the
         * strength of it without re-measuring.
         */
        fun stripWebViewToken(ua: String): String =
            ua.replace("; wv)", ")").replace(" wv)", ")")

        /**
         * Fallback when no device UA is available (unit tests, JVM callers).
         * Desktop Firefox, byte-identical to the Flutter app's `kFirefoxUserAgent`.
         */
        const val UA_FIREFOX =
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:124.0) " +
                "Gecko/20100101 Firefox/124.0"

        // Verbatim from SlimSocial_for_Facebook/lib/consts.dart:26-27
        const val UA_OPERA_MINI =
            "Opera/9.80 (Android; Opera Mini/69.0.2254/191.303; U; en) Presto/2.12.423 Version/12.16"
    }
}
