package it.rignanese.leo.slim.ui.editor

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import it.rignanese.leo.slim.R
import it.rignanese.leo.slim.data.SettingsRepository
import it.rignanese.leo.slim.domain.NamedSnippet
import java.util.UUID

/**
 * Editor for a single snippet (CSS or JS). Receives a [snippetId] of `"new"` to
 * start blank, otherwise loads the existing entry by id.
 *
 * For JavaScript a persistent yellow header strip warns the user about the
 * security boundary; this is in addition to the [JsWarningDialog] flow on the
 * list screen.
 *
 * The "Test" button routes the current draft through [onTest], which the
 * caller (typically [it.rignanese.leo.slim.ui.settings.SettingsNavGraph]) wires
 * to the live WebView via `AppContainer.liveWebViewHost`.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SnippetEditorScreen(
    type: SnippetType,
    snippetId: String,
    repo: SettingsRepository,
    onTest: (code: String) -> Unit,
    onBack: () -> Unit,
) {
    val vm: EditorViewModel = viewModel(
        key = "EditorViewModel-${type.name}",
        factory = remember(repo, type) { EditorViewModelFactory(repo, type) },
    )
    SnippetEditorScreenContent(
        type = type,
        snippetId = snippetId,
        vm = vm,
        onTest = onTest,
        onBack = onBack,
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun SnippetEditorScreenContent(
    type: SnippetType,
    snippetId: String,
    vm: EditorViewModel,
    onTest: (code: String) -> Unit,
    onBack: () -> Unit,
) {
    val snippets by vm.snippets.collectAsStateWithLifecycle()

    val isNew = snippetId == "new"
    val existing = remember(snippets, snippetId) {
        if (isNew) null else snippets.firstOrNull { it.id == snippetId }
    }

    var name by remember(existing?.id) { mutableStateOf(existing?.name.orEmpty()) }
    var code by remember(existing?.id) { mutableStateOf(existing?.code.orEmpty()) }

    val titleRes = when {
        isNew && type == SnippetType.CSS -> R.string.editor_title_new_css
        isNew -> R.string.editor_title_new_js
        type == SnippetType.CSS -> R.string.editor_title_edit_css
        else -> R.string.editor_title_edit_js
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(titleRes)) },
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
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            if (type == SnippetType.JS) {
                JsHeaderStrip()
            }
            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                label = { Text(stringResource(R.string.editor_name_label)) },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            // Monospace code editor; min height 200.dp so it's visibly tall on
            // first paint, but scrolls outward via the parent verticalScroll.
            BasicTextField(
                value = code,
                onValueChange = { code = it },
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 200.dp)
                    .background(MaterialTheme.colorScheme.surfaceVariant)
                    .padding(8.dp),
                textStyle = TextStyle(
                    fontFamily = FontFamily.Monospace,
                    color = MaterialTheme.colorScheme.onSurface,
                ),
                cursorBrush = SolidColor(MaterialTheme.colorScheme.primary),
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                OutlinedButton(
                    onClick = { onTest(code) },
                    modifier = Modifier.weight(1f),
                ) {
                    Text(stringResource(R.string.editor_test_button))
                }
                val untitled = stringResource(R.string.editor_untitled)
                Button(
                    onClick = {
                        val nowId = if (isNew) UUID.randomUUID().toString() else snippetId
                        val saved = NamedSnippet(
                            id = nowId,
                            name = name.trim().ifBlank { untitled },
                            code = code,
                            updatedAt = System.currentTimeMillis(),
                        )
                        vm.saveSnippet(saved)
                        onBack()
                    },
                    modifier = Modifier.weight(1f),
                ) {
                    Text(stringResource(R.string.editor_save_button))
                }
            }
        }
    }
}

@Composable
private fun JsHeaderStrip() {
    // Material 3 doesn't ship a "warning" colour token; use a hand-picked yellow
    // that reads on both light and dark surfaces.
    val bg = Color(0xFFFFF59D)
    val fg = Color(0xFF212121)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(bg)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(
            imageVector = Icons.Filled.Warning,
            contentDescription = null,
            tint = fg,
        )
        Text(
            text = stringResource(R.string.js_warning_strip),
            style = MaterialTheme.typography.bodySmall,
            color = fg,
        )
    }
}
