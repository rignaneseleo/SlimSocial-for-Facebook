package it.rignanese.leo.slim.webview

import android.webkit.WebStorage
import android.webkit.WebView

/**
 * Owns and exposes high-level operations on a single [WebView].
 *
 * All `evaluateJavascript` calls in the project route through this class
 * (via [injectCss] / [injectJs]) so callers don't pull in raw WebView APIs.
 */
class WebViewHost(
    val view: WebView,
    private val cookies: CookieConfigurator,
    private val proxy: ProxyConfigurator,
    private val darkMode: DarkModeConfigurator,
) {
    fun load(url: String) = view.loadUrl(url)

    fun reload() = view.reload()

    fun back(): Boolean = if (view.canGoBack()) {
        view.goBack(); true
    } else false

    fun setUserAgent(ua: String) {
        view.settings.userAgentString = ua
    }

    /**
     * Inject CSS by appending a `<style>` element. The CSS string is escaped for
     * embedding into a single-quoted JS literal: backslash, single-quote, and
     * newline are the only meta-characters we need to handle for CSS payloads.
     */
    fun injectCss(css: String) {
        val safe = css
            .replace("\\", "\\\\")
            .replace("'", "\\'")
            .replace("\n", "\\n")
        view.evaluateJavascript(
            "javascript:(function(){ var s=document.createElement('style'); s.textContent='$safe'; document.head.appendChild(s); })()",
            null,
        )
    }

    fun injectJs(js: String) {
        view.evaluateJavascript(js, null)
    }

    fun applyDarkMode(allowed: Boolean) = darkMode.apply(view.settings, allowed)

    fun applyProxy(host: String, port: String, onApplied: () -> Unit = {}) =
        proxy.apply(host, port, onApplied)

    fun clearProxy(onCleared: () -> Unit = {}) = proxy.clear(onCleared)

    fun flushCookies() = cookies.flush()

    fun clearAll() {
        view.clearCache(true)
        view.clearHistory()
        view.clearFormData()
        WebStorage.getInstance().deleteAllData()
    }
}
