package it.rignanese.leo.slim.ui.settings

import androidx.compose.runtime.Composable
import it.rignanese.leo.slim.platform.ProEntitlement

/**
 * F-Droid flavor: PRO UI is compiled out — no themes entry, no paywall
 * (spec §3.1). Empty body keeps the shared SettingsScreen flavor-agnostic.
 */
@Suppress("UNUSED_PARAMETER")
@Composable
fun ProSettingsSection(
    proEntitlement: ProEntitlement,
    onNavigate: (route: String) -> Unit,
) {
}
