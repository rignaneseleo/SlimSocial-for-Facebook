package it.rignanese.leo.slim.ui.settings

import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.compose.composable
import it.rignanese.leo.slim.app.AppContainer

/**
 * Full-flavor PRO destinations for the Settings nav graph. The `fdroid`
 * source set declares the same function with an empty body, so the shared
 * [SettingsNavGraph] never references PRO screens directly.
 */
fun NavGraphBuilder.proDestinations(
    container: AppContainer,
    navController: NavHostController,
    vm: SettingsViewModel,
) {
    composable("themes") {
        ThemePickerScreen(
            vm = vm,
            proEntitlement = container.platform.proEntitlement,
            themeRuleSource = container.themeRuleSource,
            onGetPro = { navController.navigate("donate") },
            onBack = { navController.popBackStack() },
        )
    }
}
