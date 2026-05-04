package it.rignanese.leo.slim.ui.log

import android.content.Intent
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.webkit.WebViewCompat
import it.rignanese.leo.slim.BuildConfig
import it.rignanese.leo.slim.data.LogBuffer
import it.rignanese.leo.slim.data.LogCategory
import it.rignanese.leo.slim.data.LogEvent
import it.rignanese.leo.slim.data.SettingsRepository
import it.rignanese.leo.slim.domain.Settings

/**
 * Top-level "debug" route. Tails the in-memory [LogBuffer] (auto-scrolling to
 * the newest entry like a console), filters by [LogCategory], and exposes
 * Pause / Clear / Export / Send-to-dev affordances. The card at the top
 * binds the persistent "Reproduce mode" flag.
 *
 * The state-snapshot card surfaces values that are useful in bug reports:
 * WebView Chrome version, current UA, current URL, active rule IDs, proxy
 * state, permission grants.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LogViewerScreen(
    logBuffer: LogBuffer,
    repo: SettingsRepository,
    settings: Settings,
    currentUrl: String,
    userAgent: String,
    activeRuleIds: List<String>,
    onBack: () -> Unit,
) {
    val vm: LogViewerViewModel = viewModel(
        factory = remember(logBuffer, repo) { LogViewerViewModelFactory(logBuffer, repo) },
    )
    LogViewerScreenContent(
        vm = vm,
        settings = settings,
        currentUrl = currentUrl,
        userAgent = userAgent,
        activeRuleIds = activeRuleIds,
        onBack = onBack,
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun LogViewerScreenContent(
    vm: LogViewerViewModel,
    settings: Settings,
    currentUrl: String,
    userAgent: String,
    activeRuleIds: List<String>,
    onBack: () -> Unit,
) {
    val events by vm.events.collectAsStateWithLifecycle()
    val paused by vm.paused.collectAsStateWithLifecycle()
    val debugMode by vm.debugMode.collectAsStateWithLifecycle()

    var selectedCategories by remember { mutableStateOf(LogCategory.values().toSet()) }
    val visibleEvents = remember(events, selectedCategories) {
        events.filter { it.category in selectedCategories }
    }

    val context = LocalContext.current
    val listState = rememberLazyListState()

    // Auto-scroll to the bottom whenever the visible list grows, mimicking a
    // streaming console.
    LaunchedEffect(visibleEvents.size, paused) {
        if (!paused && visibleEvents.isNotEmpty()) {
            listState.scrollToItem(visibleEvents.lastIndex)
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Log viewer") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            // ---------------- Reproduce mode card ----------------
            ReproduceModeCard(
                debugMode = debugMode,
                onChange = { vm.setDebugMode(it) },
            )

            // ---------------- State snapshot ----------------
            StateSnapshotCard(
                settings = settings,
                currentUrl = currentUrl,
                userAgent = userAgent,
                activeRuleIds = activeRuleIds,
            )

            HorizontalDivider()

            // ---------------- Filter chips ----------------
            FilterChipRow(
                selected = selectedCategories,
                onChange = { selectedCategories = it },
            )

            HorizontalDivider()

            // ---------------- Action buttons ----------------
            ActionButtonsRow(
                paused = paused,
                onPauseToggle = { vm.togglePause() },
                onClear = { vm.clear() },
                onExport = {
                    val intent = Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_TEXT, vm.exportRedacted())
                    }
                    runCatching {
                        context.startActivity(Intent.createChooser(intent, "Export log"))
                    }
                },
                onSendToDev = {
                    val intent = Intent(Intent.ACTION_SEND).apply {
                        setType("message/rfc822")
                        putExtra(Intent.EXTRA_EMAIL, arrayOf("rignanese.leo@gmail.com"))
                        putExtra(
                            Intent.EXTRA_SUBJECT,
                            "SlimSocial debug log v${BuildConfig.VERSION_NAME}",
                        )
                        putExtra(Intent.EXTRA_TEXT, vm.exportRedacted())
                    }
                    runCatching { context.startActivity(intent) }
                },
            )

            HorizontalDivider()

            // ---------------- Log tail ----------------
            LogList(
                events = visibleEvents,
                listState = listState,
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 8.dp),
            )
        }
    }
}

@Composable
private fun ReproduceModeCard(debugMode: Boolean, onChange: (Boolean) -> Unit) {
    Card(modifier = Modifier.fillMaxWidth().padding(8.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text("Reproduce mode", style = MaterialTheme.typography.titleSmall)
                Text(
                    "Records extra detail to help reproduce bugs.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Switch(checked = debugMode, onCheckedChange = onChange)
        }
    }
}

@Composable
private fun StateSnapshotCard(
    settings: Settings,
    currentUrl: String,
    userAgent: String,
    activeRuleIds: List<String>,
) {
    val context = LocalContext.current
    val webViewVersion = remember(context) {
        WebViewCompat.getCurrentWebViewPackage(context)?.versionName ?: "unknown"
    }
    val proxyState = if (settings.webView.customProxyEnabled) {
        "${settings.webView.customProxyHost}:${settings.webView.customProxyPort}"
    } else {
        "off"
    }
    val grants = settings.permissions
    val permissionsLabel = listOfNotNull(
        if (grants.gps) "gps" else null,
        if (grants.camera) "camera" else null,
        if (grants.photo) "photo" else null,
        if (grants.photos) "photos" else null,
        if (grants.mic) "mic" else null,
        if (grants.notifications) "notifications" else null,
    ).joinToString(", ").ifBlank { "none" }
    val activeRulesLabel = activeRuleIds.joinToString(", ").ifBlank { "none" }
    val activeCss = settings.customization.activeCssIds.joinToString(", ").ifBlank { "none" }
    val activeJs = settings.customization.activeJsIds.joinToString(", ").ifBlank { "none" }

    Card(modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 4.dp)) {
        Column(
            modifier = Modifier.padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            Text("State snapshot", style = MaterialTheme.typography.titleSmall)
            SnapshotLine(label = "WebView", value = webViewVersion)
            SnapshotLine(label = "URL", value = currentUrl.ifBlank { "(none)" })
            SnapshotLine(label = "UA", value = userAgent)
            SnapshotLine(label = "Active rules", value = activeRulesLabel)
            SnapshotLine(label = "Active CSS", value = activeCss)
            SnapshotLine(label = "Active JS", value = activeJs)
            SnapshotLine(label = "Proxy", value = proxyState)
            SnapshotLine(label = "Permissions", value = permissionsLabel)
        }
    }
}

@Composable
private fun SnapshotLine(label: String, value: String) {
    Row(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = "$label: ",
            style = MaterialTheme.typography.bodySmall,
            fontFamily = FontFamily.Monospace,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodySmall,
            fontFamily = FontFamily.Monospace,
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FilterChipRow(
    selected: Set<LogCategory>,
    onChange: (Set<LogCategory>) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = 8.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        LogCategory.values().forEach { category ->
            val isSelected = category in selected
            FilterChip(
                selected = isSelected,
                onClick = {
                    onChange(
                        if (isSelected) selected - category else selected + category,
                    )
                },
                label = { Text(category.name) },
            )
        }
    }
}

@Composable
private fun ActionButtonsRow(
    paused: Boolean,
    onPauseToggle: () -> Unit,
    onClear: () -> Unit,
    onExport: () -> Unit,
    onSendToDev: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = 8.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        OutlinedButton(onClick = onPauseToggle) {
            Text(if (paused) "Resume" else "Pause")
        }
        OutlinedButton(onClick = onClear) { Text("Clear") }
        OutlinedButton(onClick = onExport) { Text("Export") }
        OutlinedButton(onClick = onSendToDev) { Text("Send to dev") }
    }
}

@Composable
private fun LogList(
    events: List<LogEvent>,
    listState: androidx.compose.foundation.lazy.LazyListState,
    modifier: Modifier = Modifier,
) {
    if (events.isEmpty()) {
        Column(
            modifier = modifier,
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = "No log events match the current filter.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
        }
        return
    }
    LazyColumn(
        state = listState,
        modifier = modifier,
        contentPadding = PaddingValues(vertical = 4.dp),
    ) {
        items(items = events, key = { it.timestampMs.toString() + it.message.hashCode() }) { event ->
            LogRow(event)
        }
    }
}

@Composable
private fun LogRow(event: LogEvent) {
    Text(
        text = "[${event.timestampMs}] ${event.category.name}: ${event.message}",
        style = MaterialTheme.typography.bodySmall,
        fontFamily = FontFamily.Monospace,
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 1.dp),
    )
}
