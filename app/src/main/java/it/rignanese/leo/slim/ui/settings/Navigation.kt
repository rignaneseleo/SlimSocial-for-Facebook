package it.rignanese.leo.slim.ui.settings

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.navArgument
import it.rignanese.leo.slim.app.AppContainer
import it.rignanese.leo.slim.ui.editor.SnippetEditorScreen
import it.rignanese.leo.slim.ui.editor.SnippetListScreen
import it.rignanese.leo.slim.ui.editor.SnippetType
import it.rignanese.leo.slim.ui.log.LogViewerScreen
import it.rignanese.leo.slim.ui.settings.advanced.ProxySettingsScreen
import it.rignanese.leo.slim.ui.settings.advanced.UserAgentScreen

/**
 * Navigation graph for the Settings tree. Hosted as a sub-graph from
 * [it.rignanese.leo.slim.ui.AppRoot] — the root nav graph drives "home"
 * vs "settings/root" while this composable owns transitions between settings
 * screens.
 *
 * Phase 9 fills in real Compose screens for editor/css, editor/js, and debug.
 *
 * @param currentUrl the URL the production WebView is currently displaying;
 *   surfaced in the log viewer's state-snapshot card.
 * @param userAgent the resolved user agent — same source as the WebView's UA.
 */
@Composable
fun SettingsNavGraph(
    navController: NavHostController,
    container: AppContainer,
    currentUrl: String,
    userAgent: String,
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
        composable("editor/css") {
            SnippetListScreen(
                type = SnippetType.CSS,
                repo = container.settingsRepository,
                onEditSnippet = { id -> navController.navigate("editor/css/$id") },
                onBack = { navController.popBackStack() },
            )
        }
        composable("editor/js") {
            SnippetListScreen(
                type = SnippetType.JS,
                repo = container.settingsRepository,
                onEditSnippet = { id -> navController.navigate("editor/js/$id") },
                onBack = { navController.popBackStack() },
            )
        }
        composable(
            route = "editor/css/{id}",
            arguments = listOf(navArgument("id") { type = NavType.StringType }),
        ) { entry ->
            val id = entry.arguments?.getString("id") ?: "new"
            SnippetEditorScreen(
                type = SnippetType.CSS,
                snippetId = id,
                repo = container.settingsRepository,
                onTest = { code -> container.liveWebViewHost.current?.injectCss(code) },
                onBack = { navController.popBackStack() },
            )
        }
        composable(
            route = "editor/js/{id}",
            arguments = listOf(navArgument("id") { type = NavType.StringType }),
        ) { entry ->
            val id = entry.arguments?.getString("id") ?: "new"
            SnippetEditorScreen(
                type = SnippetType.JS,
                snippetId = id,
                repo = container.settingsRepository,
                onTest = { code -> container.liveWebViewHost.current?.injectJs(code) },
                onBack = { navController.popBackStack() },
            )
        }
        composable("debug") {
            val settings by vm.settings.collectAsStateWithLifecycle()
            val activeRuleIds = remember(settings) {
                container.ruleRegistry.activeRules(settings).map { it.id }
            }
            LogViewerScreen(
                logBuffer = container.logBuffer,
                repo = container.settingsRepository,
                settings = settings,
                currentUrl = currentUrl,
                userAgent = userAgent,
                activeRuleIds = activeRuleIds,
                onBack = { navController.popBackStack() },
            )
        }
        composable("donate") {
            DonateScreen(
                donationLauncher = container.platform.donationLauncher,
                onBack = { navController.popBackStack() },
            )
        }
    }
}
