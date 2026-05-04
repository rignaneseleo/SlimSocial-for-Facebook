package it.rignanese.leo.slim.ui.editor

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable

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
        title = { Text("JavaScript runs in your Facebook session") },
        text = {
            Text(
                "Custom JavaScript runs with full access to your Facebook session — " +
                    "including your feed, messages, and session cookies. " +
                    "Only paste code from sources you trust.",
            )
        },
        confirmButton = { TextButton(onClick = onAccept) { Text("I understand") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
    )
}
