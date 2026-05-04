package it.rignanese.leo.slim.ui.settings.advanced

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import it.rignanese.leo.slim.R
import it.rignanese.leo.slim.ui.settings.SettingsViewModel
import it.rignanese.leo.slim.webview.ProxyConfigurator

/**
 * Editor for the (per-process) HTTP proxy override. The settings are persisted
 * via [SettingsViewModel.update] AND the proxy override is applied to the live
 * WebView process immediately on Save — proxy is global per-process so any
 * existing WebView picks up the change without recreation.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProxySettingsScreen(
    vm: SettingsViewModel,
    proxyConfigurator: ProxyConfigurator,
    onBack: () -> Unit,
) {
    val settings by vm.settings.collectAsStateWithLifecycle()

    var enabled by remember { mutableStateOf(settings.webView.customProxyEnabled) }
    var host by remember { mutableStateOf(settings.webView.customProxyHost) }
    var port by remember { mutableStateOf(settings.webView.customProxyPort) }

    // Re-sync local fields if persisted state changes from elsewhere.
    LaunchedEffect(settings.webView) {
        enabled = settings.webView.customProxyEnabled
        host = settings.webView.customProxyHost
        port = settings.webView.customProxyPort
    }

    val portInt = port.toIntOrNull()
    val portValid = port.isBlank() || (portInt != null && portInt in 1..65_535)
    val canApply = !enabled || (host.isNotBlank() && portInt != null && portInt in 1..65_535)

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.custom_proxy)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = stringResource(R.string.back),
                        )
                    }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = stringResource(R.string.proxy_enable),
                    modifier = Modifier.weight(1f),
                    style = MaterialTheme.typography.bodyLarge,
                )
                Switch(checked = enabled, onCheckedChange = { enabled = it })
            }
            OutlinedTextField(
                value = host,
                onValueChange = { host = it },
                label = { Text(stringResource(R.string.proxy_host_label)) },
                singleLine = true,
                enabled = enabled,
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = port,
                onValueChange = { input -> port = input.filter { it.isDigit() } },
                label = { Text(stringResource(R.string.proxy_port_label)) },
                singleLine = true,
                enabled = enabled,
                isError = !portValid,
                supportingText = {
                    if (!portValid) Text(stringResource(R.string.proxy_port_invalid))
                },
                keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(
                    keyboardType = KeyboardType.Number,
                ),
                modifier = Modifier.fillMaxWidth(),
            )
            Button(
                onClick = {
                    vm.update {
                        it.copy(
                            webView = it.webView.copy(
                                customProxyEnabled = enabled,
                                customProxyHost = host,
                                customProxyPort = port,
                            ),
                        )
                    }
                    if (enabled) {
                        proxyConfigurator.apply(host = host, port = port, onApplied = {})
                    } else {
                        proxyConfigurator.clear(onCleared = {})
                    }
                },
                enabled = canApply,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(stringResource(R.string.editor_apply_button))
            }
        }
    }
}
