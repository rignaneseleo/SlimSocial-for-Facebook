package it.rignanese.leo.slim.ui.settings

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import it.rignanese.leo.slim.app.AppContainer
import it.rignanese.leo.slim.ui.settings.advanced.ProxySettingsScreen
import it.rignanese.leo.slim.ui.settings.advanced.UserAgentScreen

/**
 * Navigation graph for the Settings tree. Hosted as a sub-graph from
 * [it.rignanese.leo.slim.ui.AppRoot] — the root nav graph drives "home"
 * vs "settings/root" while this composable owns transitions between settings
 * screens.
 *
 * Editor and debug routes resolve to placeholders for Phase 8; Phase 9 will
 * fill them in with real Compose screens.
 */
@Composable
fun SettingsNavGraph(
    navController: NavHostController,
    container: AppContainer,
    onExitSettings: () -> Unit,
) {
    val vm: SettingsViewModel = viewModel(
        factory = remember(container) { SettingsViewModelFactory(container.settingsRepository) },
    )

    NavHost(navController = navController, startDestination = "settings/root") {
        composable("settings/root") {
            SettingsScreen(
                vm = vm,
                onNavigate = { route -> navController.navigate(route) },
                onBack = onExitSettings,
                osReader = container.osPermissionReader,
            )
        }
        composable("settings/proxy") {
            ProxySettingsScreen(
                vm = vm,
                proxyConfigurator = container.proxyConfigurator,
                onBack = { navController.popBackStack() },
            )
        }
        composable("settings/useragent") {
            UserAgentScreen(
                vm = vm,
                onBack = { navController.popBackStack() },
            )
        }
        composable("about") {
            AboutScreen(
                onBack = { navController.popBackStack() },
                urlOpener = container.urlOpener,
                onNavigate = { route -> navController.navigate(route) },
            )
        }
        composable("editor/css") { PlaceholderScreen("Custom CSS Editor — Phase 9") }
        composable("editor/js") { PlaceholderScreen("Custom JS Editor — Phase 9") }
        composable("debug") { PlaceholderScreen("Debug / Log Viewer — Phase 9") }
        composable("donate") { PlaceholderScreen("Donate — Phase 10") }
    }
}

@Composable
private fun PlaceholderScreen(label: String) {
    Box(modifier = Modifier.fillMaxSize().padding(24.dp)) {
        Text(label, style = MaterialTheme.typography.bodyLarge)
    }
}
