package it.rignanese.leo.slim.ui

import androidx.activity.ComponentActivity
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import it.rignanese.leo.slim.MainViewModel
import it.rignanese.leo.slim.app.SlimApplication
import it.rignanese.leo.slim.permissions.RealPermissionGate
import it.rignanese.leo.slim.webview.WebViewHost

/**
 * Top-level Compose root. Owns the cross-cutting state for the WebView host
 * surface: render-gone overlay flag and the [WebViewHost] reference used to
 * deliver deeplinks and reload after a renderer crash.
 *
 * Phase 7 renders only the browser surface; Phase 8 will introduce navigation
 * to settings/editor/log screens.
 */
@Composable
fun AppRoot(vm: MainViewModel) {
    val homeUrl by vm.homeUrl.collectAsStateWithLifecycle()
    val userAgent by vm.userAgent.collectAsStateWithLifecycle()

    val context = LocalContext.current
    val activity = context as? ComponentActivity
        ?: error("AppRoot must be hosted inside a ComponentActivity")
    val container = (activity.application as SlimApplication).container

    val gate = remember(vm) {
        RealPermissionGate(
            context = activity.applicationContext,
            grantsProvider = vm.grantsProvider(),
            osReader = container.osPermissionReader,
        )
    }

    var showRenderGone by remember { mutableStateOf(false) }
    var hostRef by remember { mutableStateOf<WebViewHost?>(null) }

    LaunchedEffect(vm) {
        vm.renderGone.collect { showRenderGone = true }
    }

    LaunchedEffect(vm) {
        vm.deeplinkUrl.collect { url -> hostRef?.load(url) }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        BrowserScreen(
            homeUrl = homeUrl,
            userAgent = userAgent,
            container = container,
            gate = gate,
            onPageReady = { url, host ->
                val payload = vm.composeInjection(url)
                if (payload.css.isNotEmpty()) host.injectCss(payload.css)
                if (payload.js.isNotEmpty()) host.injectJs(payload.js)
            },
            onRenderGone = { didCrash -> vm.onRenderGone(didCrash) },
            onHostReady = { hostRef = it },
        )

        if (showRenderGone) {
            RenderGoneOverlay(
                onReload = {
                    showRenderGone = false
                    hostRef?.reload()
                },
            )
        }
    }
}
