package it.rignanese.leo.slim.ui.editor

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.res.stringResource
import it.rignanese.leo.slim.R

/**
 * One-time confirmation dialog shown the first time the user enables custom
 * JavaScript. After acceptance, [Settings.privacy.customJsAcknowledged] flips
 * to `true` so the dialog never shows again.
 *
 * The copy intentionally calls out _session cookies, feed, messages_ — the
 * point of the dialog is to make the security model visible, not just nag.
 */
@Composable
fun JsWarningDialog(onAccept: () -> Unit, onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        icon = { Icon(Icons.Filled.Warning, contentDescription = null) },
        title = { Text(stringResource(R.string.js_warning_title)) },
        text = { Text(stringResource(R.string.js_warning_body)) },
        confirmButton = {
            TextButton(onClick = onAccept) {
                Text(stringResource(R.string.i_understand))
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.cancel))
            }
        },
    )
}
