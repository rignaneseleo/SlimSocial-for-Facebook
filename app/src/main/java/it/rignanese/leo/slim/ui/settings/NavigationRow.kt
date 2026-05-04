package it.rignanese.leo.slim.ui.settings

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable

/**
 * A [SettingsRow] with a chevron trailing icon — used to push another route.
 */
@Composable
fun NavigationRow(
    title: String,
    subtitle: String? = null,
    onClick: () -> Unit,
) {
    SettingsRow(
        title = title,
        subtitle = subtitle,
        trailing = {
            Icon(
                imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
            )
        },
        onClick = onClick,
    )
}
