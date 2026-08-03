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
            // Honor Facebook's <meta viewport> so the modern responsive
            // m.facebook.com lays out against the device viewport. Without these
            // the WebView uses a legacy layout viewport and pages built on
            // 100vh / flex collapse to html/body height 0 → a blank white screen
            // (the plain-HTML consent/mbasic pages are unaffected, which is why
            // the bug only showed post-consent).
            useWideViewPort = true
            loadWithOverviewMode = true
            cacheMode = WebSettings.LOAD_DEFAULT
            allowFileAccess = false
            allowContentAccess = false
            mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
            builtInZoomControls = true
            displayZoomControls = false
            // Facebook opens some flows (login re-auth, share sheets) through
            // window.open. Without these the call is silently dropped and the
            // UI looks dead.
            javaScriptCanOpenWindowsAutomatically = true
            setSupportMultipleWindows(true)
        }
        // Focusable in touch mode so text fields and the page behave normally.
        //
        // Deliberately NO setOnTouchListener that calls requestFocus(): that
        // was tried while chasing the notifications panel and it swallowed the
        // first gestures after load. Measured on a Pixel 10 Pro 2026-08-03 with
        // 14 scripted swipes — swipes 1 and 2 moved scrollY by 0 while the
        // remaining 12 moved it ~860px each. Requesting focus mid-gesture
        // cancels that gesture. The panel bug was the WebView `wv` UA token
        // (see UserAgentResolver), not focus.
        webView.isFocusable = true
        webView.isFocusableInTouchMode = true
        return webView
    }
}
