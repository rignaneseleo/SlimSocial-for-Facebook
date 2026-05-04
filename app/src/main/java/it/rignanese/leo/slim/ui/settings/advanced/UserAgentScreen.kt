package it.rignanese.leo.slim.ui.settings.advanced

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
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
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import it.rignanese.leo.slim.R
import it.rignanese.leo.slim.ui.settings.SettingsViewModel

/**
 * Editor for the custom WebView user agent. Empty input clears the override
 * (UA falls back to the resolver default in [it.rignanese.leo.slim.domain.UserAgentResolver]).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun UserAgentScreen(
    vm: SettingsViewModel,
    onBack: () -> Unit,
) {
    val settings by vm.settings.collectAsStateWithLifecycle()
    var input by remember { mutableStateOf(settings.webView.customUserAgent.orEmpty()) }
    LaunchedEffect(settings.webView.customUserAgent) {
        input = settings.webView.customUserAgent.orEmpty()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.user_agent_title)) },
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
            Text(
                stringResource(R.string.user_agent_hint),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            OutlinedTextField(
                value = input,
                onValueChange = { input = it },
                label = { Text(stringResource(R.string.user_agent_label)) },
                singleLine = false,
                modifier = Modifier.fillMaxWidth(),
            )
            Button(
                onClick = {
                    val sanitized = input.trim().ifBlank { null }
                    vm.update {
                        it.copy(webView = it.webView.copy(customUserAgent = sanitized))
                    }
                },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(stringResource(R.string.save))
            }
        }
    }
}
