package it.rignanese.leo.slim.webview

import android.webkit.CookieManager
import android.webkit.WebView

/**
 * Cookie setup + flush helpers.
 *
 * Per plan §0.1, third-party cookies are enabled globally (not per-origin) since
 * `setAcceptThirdPartyCookies` does not support an allowlist. The WebView only
 * ever loads Facebook surfaces, so this is acceptable.
 */
open class CookieConfigurator {
    open fun configure(webView: WebView) {
        val mgr = CookieManager.getInstance()
        mgr.setAcceptCookie(true)
        mgr.setAcceptThirdPartyCookies(webView, true)
    }

    /** Force-write the in-memory cookie store to disk. Call from `onPause`. */
    open fun flush() {
        CookieManager.getInstance().flush()
    }
}
