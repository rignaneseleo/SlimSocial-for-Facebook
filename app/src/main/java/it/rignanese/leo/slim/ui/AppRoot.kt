package it.rignanese.leo.slim.ui

import androidx.activity.ComponentActivity
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import it.rignanese.leo.slim.R
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

@OptIn(ExperimentalMaterial3Api::class)
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

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.app_name)) },
                actions = {
                    OverflowMenu(
                        onSettings = onOpenSettings,
                        onReload = { hostRef?.reload() },
                        onHome = { hostRef?.load(homeUrl) },
                    )
                },
            )
        },
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
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
}

/**
 * The app bar's 3-dot overflow menu. Replaces the old floating gear button:
 * a stable top-bar affordance that never overlaps web content and groups the
 * navigation actions (Home, Reload, Settings) in one place.
 */
@Composable
private fun OverflowMenu(
    onSettings: () -> Unit,
    onReload: () -> Unit,
    onHome: () -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    IconButton(onClick = { expanded = true }) {
        Icon(
            imageVector = Icons.Filled.MoreVert,
            contentDescription = stringResource(R.string.settings),
        )
    }
    DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
        DropdownMenuItem(
            text = { Text(stringResource(R.string.home)) },
            leadingIcon = { Icon(Icons.Filled.Home, contentDescription = null) },
            onClick = {
                expanded = false
                onHome()
            },
        )
        DropdownMenuItem(
            text = { Text(stringResource(R.string.reload)) },
            leadingIcon = { Icon(Icons.Filled.Refresh, contentDescription = null) },
            onClick = {
                expanded = false
                onReload()
            },
        )
        DropdownMenuItem(
            text = { Text(stringResource(R.string.settings)) },
            leadingIcon = { Icon(Icons.Filled.Settings, contentDescription = null) },
            onClick = {
                expanded = false
                onSettings()
            },
        )
    }
}
