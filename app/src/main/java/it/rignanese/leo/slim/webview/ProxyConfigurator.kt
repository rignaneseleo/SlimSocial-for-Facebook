package it.rignanese.leo.slim.webview

import androidx.webkit.ProxyConfig
import androidx.webkit.ProxyController
import androidx.webkit.WebViewFeature
import java.util.concurrent.Executor

/**
 * Wraps `androidx.webkit.ProxyController` for HTTP/HTTPS-only proxy override.
 *
 * Non-HTTP proxy schemes are intentionally NOT supported here — `ProxyController`
 * does not document them, and per the spec correction (plan §"Spec corrections")
 * they are deferred to a future VPNService implementation.
 *
 * The HTTP rule covers HTTPS too: HTTPS traffic reuses the HTTP CONNECT tunnel
 * so a single `http://host:port` rule entry routes both schemes correctly.
 */
class ProxyConfigurator {

    fun apply(host: String, port: String, onApplied: () -> Unit) {
        if (!WebViewFeature.isFeatureSupported(WebViewFeature.PROXY_OVERRIDE)) return
        if (host.isBlank() || port.isBlank()) return
        val portNum = port.toIntOrNull() ?: return
        val rule = "http://$host:$portNum"
        val config = ProxyConfig.Builder()
            .addProxyRule(rule)
            .removeImplicitRules()
            .build()
        ProxyController.getInstance().setProxyOverride(config, directExecutor(), Runnable { onApplied() })
    }

    fun clear(onCleared: () -> Unit) {
        if (!WebViewFeature.isFeatureSupported(WebViewFeature.PROXY_OVERRIDE)) return
        ProxyController.getInstance().clearProxyOverride(directExecutor(), Runnable { onCleared() })
    }

    private fun directExecutor(): Executor = Executor { it.run() }
}
