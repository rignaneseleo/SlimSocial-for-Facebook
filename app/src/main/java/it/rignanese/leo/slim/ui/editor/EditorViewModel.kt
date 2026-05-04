package it.rignanese.leo.slim.ui.editor

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import it.rignanese.leo.slim.data.SettingsRepository
import it.rignanese.leo.slim.domain.CustomCode
import it.rignanese.leo.slim.domain.NamedSnippet
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

/** Which snippet collection an Editor screen operates on. */
enum class SnippetType { CSS, JS }

/**
 * View-model backing the Snippet List + Snippet Editor screens.
 *
 * One instance per [SnippetType] — the [type] determines which sub-list of
 * [CustomCode] is exposed and mutated. The VM is intentionally tiny and free
 * of UI logic: the JS warning dialog flow lives in the screen, which calls
 * [acknowledgeJsWarning] when the user accepts.
 */
class EditorViewModel(
    private val repo: SettingsRepository,
    private val type: SnippetType,
) : ViewModel() {

    val snippets: StateFlow<List<NamedSnippet>> = repo.settings
        .map { settings ->
            if (type == SnippetType.CSS) settings.customization.cssEntries
            else settings.customization.jsEntries
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(STOP_TIMEOUT_MS), emptyList())

    val activeIds: StateFlow<Set<String>> = repo.settings
        .map { settings ->
            if (type == SnippetType.CSS) settings.customization.activeCssIds
            else settings.customization.activeJsIds
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(STOP_TIMEOUT_MS), emptySet())

    val customJsAcknowledged: StateFlow<Boolean> = repo.settings
        .map { it.privacy.customJsAcknowledged }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(STOP_TIMEOUT_MS), false)

    /** Toggle membership of [id] in the active set for [type]. */
    fun toggle(id: String, enabled: Boolean) {
        viewModelScope.launch {
            repo.update { settings ->
                val customization = settings.customization
                val updated = if (type == SnippetType.CSS) {
                    val ids = if (enabled) customization.activeCssIds + id
                    else customization.activeCssIds - id
                    customization.copy(activeCssIds = ids)
                } else {
                    val ids = if (enabled) customization.activeJsIds + id
                    else customization.activeJsIds - id
                    customization.copy(activeJsIds = ids)
                }
                settings.copy(customization = updated)
            }
        }
    }

    /**
     * Upsert by id — replaces the matching entry in place (preserving order)
     * if the id already exists, otherwise appends.
     */
    fun saveSnippet(snippet: NamedSnippet) {
        viewModelScope.launch {
            repo.update { settings ->
                val customization = settings.customization
                val list = if (type == SnippetType.CSS) customization.cssEntries
                else customization.jsEntries
                val replaced = list.indexOfFirst { it.id == snippet.id }
                val newList = if (replaced >= 0) {
                    list.toMutableList().also { it[replaced] = snippet }
                } else {
                    list + snippet
                }
                val updated = if (type == SnippetType.CSS) {
                    customization.copy(cssEntries = newList)
                } else {
                    customization.copy(jsEntries = newList)
                }
                settings.copy(customization = updated)
            }
        }
    }

    /** Remove by id and drop from the active set. */
    fun deleteSnippet(id: String) {
        viewModelScope.launch {
            repo.update { settings ->
                val customization = settings.customization
                val updated = if (type == SnippetType.CSS) {
                    customization.copy(
                        cssEntries = customization.cssEntries.filterNot { it.id == id },
                        activeCssIds = customization.activeCssIds - id,
                    )
                } else {
                    customization.copy(
                        jsEntries = customization.jsEntries.filterNot { it.id == id },
                        activeJsIds = customization.activeJsIds - id,
                    )
                }
                settings.copy(customization = updated)
            }
        }
    }

    fun acknowledgeJsWarning() {
        viewModelScope.launch {
            repo.update { it.copy(privacy = it.privacy.copy(customJsAcknowledged = true)) }
        }
    }

    private companion object {
        const val STOP_TIMEOUT_MS = 5_000L
    }
}

class EditorViewModelFactory(
    private val repo: SettingsRepository,
    private val type: SnippetType,
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        require(modelClass.isAssignableFrom(EditorViewModel::class.java)) {
            "Unknown ViewModel class: ${modelClass.name}"
        }
        return EditorViewModel(repo, type) as T
    }
}
