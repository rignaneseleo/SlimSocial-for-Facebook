package it.rignanese.leo.slim.ui.settings

import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import it.rignanese.leo.slim.app.AppContainer

/** F-Droid flavor: no PRO destinations — the picker is compiled out (spec §3.1). */
@Suppress("UNUSED_PARAMETER")
fun NavGraphBuilder.proDestinations(
    container: AppContainer,
    navController: NavHostController,
    vm: SettingsViewModel,
) {
}
