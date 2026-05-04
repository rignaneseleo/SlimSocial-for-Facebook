package it.rignanese.leo.slim.ui

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import it.rignanese.leo.slim.app.AppContainer
import it.rignanese.leo.slim.data.LogCategory
import it.rignanese.leo.slim.webview.AppWebChromeClient
import it.rignanese.leo.slim.webview.AppWebViewClient
import it.rignanese.leo.slim.webview.PermissionGate
import it.rignanese.leo.slim.webview.WebViewFactory
import it.rignanese.leo.slim.webview.WebViewHost

/**
 * Hosts the production WebView via Compose [AndroidView]. The WebView and its
 * [WebViewHost] wrapper are constructed once inside `factory` and never
 * recreated by recomposition — `update` only mutates settings on the live view.
 *
 * @param onHostReady invoked exactly once with the [WebViewHost] so the parent
 *   composable can drive load/reload from outside (e.g. for deeplink delivery).
 */
@Composable
fun BrowserScreen(
    homeUrl: String,
    userAgent: String,
    container: AppContainer,
    gate: PermissionGate,
    onPageReady: (url: String, host: WebViewHost) -> Unit,
    onRenderGone: (didCrash: Boolean) -> Unit,
    onHostReady: (WebViewHost) -> Unit,
) {
    AndroidView(
        modifier = Modifier.fillMaxSize(),
        factory = { ctx ->
            val webView = WebViewFactory.create(ctx)
            container.cookieConfigurator.configure(webView)
            val host = WebViewHost(
                view = webView,
                cookies = container.cookieConfigurator,
                proxy = container.proxyConfigurator,
                darkMode = container.darkModeConfigurator,
            )
            webView.webViewClient = AppWebViewClient(
                urlRouter = container.urlRouter,
                urlOpener = container.urlOpener,
                onPageReady = { url -> onPageReady(url, host) },
                onRenderGone = onRenderGone,
                logBuffer = container.logBuffer,
            )
            webView.webChromeClient = AppWebChromeClient(
                gate = gate,
                onConsoleMessage = { msg ->
                    container.logBuffer.record(LogCategory.CONSOLE, msg.message())
                },
                // Phase 8 wires SAF; for now decline the chooser cleanly so JS
                // sees an empty selection rather than a hung callback.
                onShowFileChooser = { cb, _ ->
                    cb.onReceiveValue(emptyArray())
                    true
                },
                onShowCustomView = { _, _ -> },
                onHideCustomView = { },
            )
            host.setUserAgent(userAgent)
            host.load(homeUrl)
            // Publish the live host into the process-scoped holder so the editor's
            // "Test" button can inject through it without threading callbacks
            // through the navigation graph.
            container.liveWebViewHost.current = host
            onHostReady(host)
            webView
        },
        update = { webView ->
            // Reactively follow Settings: only the UA mutates here. The home URL
            // change does NOT auto-navigate — that would yank the user out of
            // wherever they are. Initial URL is set once in `factory`.
            webView.settings.userAgentString = userAgent
        },
    )
}
