package it.rignanese.leo.slim.ui.settings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.AssistChip
import androidx.compose.material3.AssistChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import it.rignanese.leo.slim.R
import it.rignanese.leo.slim.permissions.OsPermissionStatus

/**
 * Three-state permission row implementing spec §6.4:
 *
 *  - **Off**: app-level toggle is disabled.
 *  - **On**: app toggle on AND OS grant present (or, for SAF-only perms,
 *    no OS grant required).
 *  - **On (denied by OS)**: app toggle on but OS grant is permanently denied;
 *    a warning chip surfaces a one-tap link to the system settings.
 *
 * The visual state is computed from the `(appEnabled, osStatus)` pair so the
 * caller doesn't have to pre-compute it — keeps the UI a pure function of the
 * underlying state.
 */
@Composable
fun PermissionRow(
    title: String,
    description: String,
    appEnabled: Boolean,
    osStatus: OsPermissionStatus,
    onToggle: (Boolean) -> Unit,
    onOpenSystemSettings: () -> Unit,
) {
    val permanentlyDenied = appEnabled && osStatus == OsPermissionStatus.PermanentlyDenied
    val statusLine = when {
        !appEnabled -> stringResource(R.string.permission_state_off)
        osStatus == OsPermissionStatus.Granted -> stringResource(R.string.permission_state_on)
        permanentlyDenied -> stringResource(R.string.permission_state_denied_by_os_tap_to_fix)
        else -> stringResource(R.string.permission_state_on)
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(modifier = Modifier.weight(1f)) {
                Text(text = title, style = MaterialTheme.typography.bodyLarge)
                Text(
                    text = description,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    text = statusLine,
                    style = MaterialTheme.typography.labelSmall,
                    color = if (permanentlyDenied) MaterialTheme.colorScheme.error
                    else MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Spacer(Modifier.width(8.dp))
            Switch(checked = appEnabled, onCheckedChange = onToggle)
        }
        if (permanentlyDenied) {
            AssistChip(
                onClick = onOpenSystemSettings,
                label = { Text(stringResource(R.string.open_system_settings)) },
                leadingIcon = {
                    Icon(
                        imageVector = Icons.Filled.Warning,
                        contentDescription = null,
                        modifier = Modifier.padding(end = 4.dp),
                    )
                },
                colors = AssistChipDefaults.assistChipColors(
                    leadingIconContentColor = MaterialTheme.colorScheme.error,
                ),
            )
        }
    }
}
