package it.rignanese.leo.slim.ui.editor

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import it.rignanese.leo.slim.R
import it.rignanese.leo.slim.data.SettingsRepository
import it.rignanese.leo.slim.domain.NamedSnippet

/**
 * List of named CSS or JS snippets. Each row has a switch (toggle membership in
 * the active set), an edit button (navigates to the editor), and a delete
 * button with a confirmation dialog.
 *
 * If the list is for [SnippetType.JS] and the user has not yet acknowledged the
 * JS-runs-in-your-session warning, toggling a snippet ON intercepts the action
 * and shows [JsWarningDialog]. Acceptance both records the acknowledgement and
 * completes the toggle; cancel leaves the row off.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SnippetListScreen(
    type: SnippetType,
    repo: SettingsRepository,
    onEditSnippet: (id: String) -> Unit,
    onBack: () -> Unit,
) {
    val vm: EditorViewModel = viewModel(
        // Per-type key so navigating between editor/css and editor/js gives us
        // distinct VMs rather than reusing the previous list.
        key = "EditorViewModel-${type.name}",
        factory = remember(repo, type) { EditorViewModelFactory(repo, type) },
    )
    SnippetListScreenContent(
        type = type,
        vm = vm,
        onEditSnippet = onEditSnippet,
        onBack = onBack,
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun SnippetListScreenContent(
    type: SnippetType,
    vm: EditorViewModel,
    onEditSnippet: (id: String) -> Unit,
    onBack: () -> Unit,
) {
    val snippets by vm.snippets.collectAsStateWithLifecycle()
    val activeIds by vm.activeIds.collectAsStateWithLifecycle()
    val acknowledged by vm.customJsAcknowledged.collectAsStateWithLifecycle()

    var pendingDelete by remember { mutableStateOf<NamedSnippet?>(null) }
    var pendingJsEnable by remember { mutableStateOf<String?>(null) }

    val title = stringResource(
        if (type == SnippetType.CSS) R.string.editor_title_custom_css
        else R.string.editor_title_custom_js,
    )

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(title) },
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
        floatingActionButton = {
            FloatingActionButton(onClick = { onEditSnippet("new") }) {
                Icon(
                    Icons.Filled.Add,
                    contentDescription = stringResource(R.string.editor_new_snippet),
                )
            }
        },
    ) { padding ->
        if (snippets.isEmpty()) {
            EmptyState(padding = padding, type = type)
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
            ) {
                items(items = snippets, key = { it.id }) { snippet ->
                    SnippetRow(
                        snippet = snippet,
                        enabled = activeIds.contains(snippet.id),
                        onToggle = { newEnabled ->
                            if (newEnabled && type == SnippetType.JS && !acknowledged) {
                                // Defer the toggle until acknowledgement; the dialog
                                // handler completes (or cancels) the work.
                                pendingJsEnable = snippet.id
                            } else {
                                vm.toggle(snippet.id, newEnabled)
                            }
                        },
                        onEdit = { onEditSnippet(snippet.id) },
                        onDelete = { pendingDelete = snippet },
                    )
                }
            }
        }
    }

    pendingDelete?.let { target ->
        AlertDialog(
            onDismissRequest = { pendingDelete = null },
            title = { Text(stringResource(R.string.editor_delete_snippet_title)) },
            text = {
                Text(
                    stringResource(R.string.editor_delete_snippet_message, target.name),
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    vm.deleteSnippet(target.id)
                    pendingDelete = null
                }) { Text(stringResource(R.string.delete)) }
            },
            dismissButton = {
                TextButton(onClick = { pendingDelete = null }) {
                    Text(stringResource(R.string.cancel))
                }
            },
        )
    }

    if (pendingJsEnable != null) {
        JsWarningDialog(
            onAccept = {
                val id = pendingJsEnable
                pendingJsEnable = null
                if (id != null) {
                    vm.acknowledgeJsWarning()
                    vm.toggle(id, enabled = true)
                }
            },
            onDismiss = { pendingJsEnable = null },
        )
    }
}

@Composable
private fun SnippetRow(
    snippet: NamedSnippet,
    enabled: Boolean,
    onToggle: (Boolean) -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        val unnamed = stringResource(R.string.editor_unnamed)
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = snippet.name.ifBlank { unnamed },
                style = MaterialTheme.typography.bodyLarge,
            )
        }
        Switch(checked = enabled, onCheckedChange = onToggle)
        IconButton(onClick = onEdit) {
            Icon(
                Icons.Filled.Edit,
                contentDescription = stringResource(R.string.editor_edit),
            )
        }
        IconButton(onClick = onDelete) {
            Icon(
                Icons.Filled.Delete,
                contentDescription = stringResource(R.string.delete),
            )
        }
    }
}

@Composable
private fun EmptyState(padding: PaddingValues, type: SnippetType) {
    val noun = stringResource(
        if (type == SnippetType.CSS) R.string.editor_noun_css
        else R.string.editor_noun_js,
    )
    Box(
        modifier = Modifier
            .fillMaxSize()
            .padding(padding)
            .padding(24.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = stringResource(R.string.editor_no_snippets_yet, noun),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}
