package it.rignanese.leo.slim.ui.settings

import androidx.compose.material3.Switch
import androidx.compose.runtime.Composable

/**
 * A [SettingsRow] with a Material 3 [Switch] as its trailing slot. Tapping
 * anywhere on the row inverts the toggle.
 */
@Composable
fun ToggleRow(
    title: String,
    subtitle: String? = null,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    SettingsRow(
        title = title,
        subtitle = subtitle,
        trailing = { Switch(checked = checked, onCheckedChange = onCheckedChange) },
        onClick = { onCheckedChange(!checked) },
    )
}
