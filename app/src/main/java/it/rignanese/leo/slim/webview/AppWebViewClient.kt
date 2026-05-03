package it.rignanese.leo.slim.webview

import android.webkit.RenderProcessGoneDetail
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.annotation.RequiresApi
import it.rignanese.leo.slim.data.LogBuffer
import it.rignanese.leo.slim.data.LogCategory
import it.rignanese.leo.slim.domain.Route
import it.rignanese.leo.slim.domain.UrlRouter

/**
 * WebViewClient handling navigation routing, page-ready signals, and renderer
 * crash recovery.
 *
 * Phase 4 routes Messenger URLs in-app (returns false). Phase 7 may split
 * Messenger into its own host WebView; for now both share one renderer.
 */
class AppWebViewClient(
    private val urlRouter: UrlRouter,
    private val urlOpener: UrlOpener,
    private val onPageReady: (url: String) -> Unit,
    private val onRenderGone: (didCrash: Boolean) -> Unit,
    private val logBuffer: LogBuffer,
) : WebViewClient() {

    override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
        val url = request.url.toString()
        return when (urlRouter.route(url)) {
            is Route.InApp -> false
            is Route.Messenger -> false  // Phase 7 may route to a separate WebView.
            is Route.External -> {
                urlOpener.open(view.context, url)
                true
            }
        }
    }

    override fun onPageCommitVisible(view: WebView, url: String) {
        onPageReady(url)
    }

    override fun onPageFinished(view: WebView, url: String) {
        onPageReady(url)
    }

    @RequiresApi(26)
    override fun onRenderProcessGone(view: WebView, detail: RenderProcessGoneDetail): Boolean {
        logBuffer.record(LogCategory.RENDER_GONE, "didCrash=${detail.didCrash()}")
        onRenderGone(detail.didCrash())
        return true
    }
}
