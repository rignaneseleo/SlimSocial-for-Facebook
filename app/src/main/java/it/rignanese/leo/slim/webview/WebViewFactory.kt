package it.rignanese.leo.slim.webview

import android.annotation.SuppressLint
import android.content.Context
import android.webkit.WebSettings
import android.webkit.WebView

/**
 * Central place where a [WebView] is constructed and configured.
 *
 * Settings are restricted to the allow-list in plan §0.1. The deprecated
 * Honeycomb-era WebSettings APIs are explicitly NOT called.
 */
object WebViewFactory {

    @SuppressLint("SetJavaScriptEnabled")
    fun create(context: Context): WebView {
        val webView = WebView(context)
        with(webView.settings) {
            javaScriptEnabled = true
            domStorageEnabled = true
            cacheMode = WebSettings.LOAD_DEFAULT
            allowFileAccess = false
            allowContentAccess = false
            mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
            builtInZoomControls = true
            displayZoomControls = false
        }
        return webView
    }
}
