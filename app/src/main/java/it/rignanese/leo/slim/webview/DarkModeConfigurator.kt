package it.rignanese.leo.slim.webview

import android.webkit.WebSettings
import androidx.webkit.WebSettingsCompat
import androidx.webkit.WebViewFeature

/**
 * Algorithmic darkening — the modern replacement for legacy force-dark APIs.
 *
 * Gated on [WebViewFeature.ALGORITHMIC_DARKENING] — older WebView providers will
 * silently no-op rather than crash.
 */
class DarkModeConfigurator {
    fun apply(settings: WebSettings, allowed: Boolean) {
        if (WebViewFeature.isFeatureSupported(WebViewFeature.ALGORITHMIC_DARKENING)) {
            WebSettingsCompat.setAlgorithmicDarkeningAllowed(settings, allowed)
        }
    }
}
