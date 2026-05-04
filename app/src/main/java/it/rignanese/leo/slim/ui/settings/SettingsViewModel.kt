package it.rignanese.leo.slim.ui.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import it.rignanese.leo.slim.data.SettingsRepository
import it.rignanese.leo.slim.domain.Settings
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

/**
 * Reactive view-model for the Settings UI tree. Exposes the live [Settings]
 * snapshot from the [SettingsRepository] and provides an [update] action that
 * applies a transform on top of the latest value.
 *
 * Uses `WhileSubscribed(5_000)` so the upstream collection survives short
 * configuration changes (e.g. screen rotation) without restarting.
 */
class SettingsViewModel(private val repo: SettingsRepository) : ViewModel() {

    val settings: StateFlow<Settings> = repo.settings
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(STOP_TIMEOUT_MS), Settings.DEFAULT)

    fun update(transform: (Settings) -> Settings) {
        viewModelScope.launch { repo.update(transform) }
    }

    private companion object {
        const val STOP_TIMEOUT_MS = 5_000L
    }
}

class SettingsViewModelFactory(private val repo: SettingsRepository) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        require(modelClass.isAssignableFrom(SettingsViewModel::class.java)) {
            "Unknown ViewModel class: ${modelClass.name}"
        }
        return SettingsViewModel(repo) as T
    }
}
