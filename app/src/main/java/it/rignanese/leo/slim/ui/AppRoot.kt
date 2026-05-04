package it.rignanese.leo.slim.ui

import androidx.activity.ComponentActivity
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import it.rignanese.leo.slim.MainViewModel
import it.rignanese.leo.slim.app.SlimApplication
import it.rignanese.leo.slim.permissions.RealPermissionGate
import it.rignanese.leo.slim.ui.settings.SettingsNavGraph
import it.rignanese.leo.slim.webview.WebViewHost

/**
 * Top-level Compose root. Owns the cross-cutting state for the WebView host
 * surface plus the top-level navigation graph that switches between the
 * browser surface ("home") and the Settings tree ("settings").
 *
 * Phase 8 adds:
 *  - A top-level `NavHost` with two destinations.
 *  - An overlay icon button on the browser surface that pushes "settings".
 *  - Delegation to [SettingsNavGraph] for nested settings navigation.
 */
@Composable
fun AppRoot(vm: MainViewModel) {
    val rootNav: NavHostController = rememberNavController()
    // Tracks the most recently observed URL from the WebView for use by the
    // Settings sub-graph (specifically the Log Viewer's state-snapshot card).
    var currentUrl by remember { mutableStateOf("") }

    NavHost(navController = rootNav, startDestination = "home") {
        composable("home") {
            HomeScreen(
                vm = vm,
                onOpenSettings = { rootNav.navigate("settings") },
                onUrlChange = { currentUrl = it },
            )
        }
        composable("settings") {
            val container = (LocalContext.current.applicationContext as SlimApplication).container
            val settingsNav = rememberNavController()
            val userAgent by vm.userAgent.collectAsStateWithLifecycle()
            SettingsNavGraph(
                navController = settingsNav,
                container = container,
                currentUrl = currentUrl,
                userAgent = userAgent,
                onExitSettings = { rootNav.popBackStack() },
            )
        }
    }
}

@Composable
private fun HomeScreen(
    vm: MainViewModel,
    onOpenSettings: () -> Unit,
    onUrlChange: (String) -> Unit = {},
) {
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
                onUrlChange(url)
                val payload = vm.composeInjection(url)
                if (payload.css.isNotEmpty()) host.injectCss(payload.css)
                if (payload.js.isNotEmpty()) host.injectJs(payload.js)
            },
            onRenderGone = { didCrash -> vm.onRenderGone(didCrash) },
            onHostReady = { hostRef = it },
        )

        // Top-right overlay shortcut into the Settings tree. The Flutter app
        // showed an AppBar with a gear icon — we emulate it with a single
        // floating button so the WebView keeps the full viewport.
        FilledTonalIconButton(
            onClick = onOpenSettings,
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(top = 16.dp, end = 8.dp)
                .size(40.dp),
        ) {
            Icon(
                imageVector = Icons.Filled.Settings,
                contentDescription = "Settings",
            )
        }

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
