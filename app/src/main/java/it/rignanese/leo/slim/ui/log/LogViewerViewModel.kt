package it.rignanese.leo.slim.ui.log

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import it.rignanese.leo.slim.data.LogBuffer
import it.rignanese.leo.slim.data.LogEvent
import it.rignanese.leo.slim.data.SettingsRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Polls the [LogBuffer] every [pollIntervalMs] and exposes a snapshot stream
 * for the Log Viewer screen. Polling beats subscribing to LogBuffer because the
 * buffer is a thread-safe in-memory ring with no native flow API; a lightweight
 * 500 ms tick is plenty for human-readable scroll-back.
 *
 * `pollIntervalMs` is injectable so unit tests can cut the polling delay.
 */
class LogViewerViewModel(
    private val logBuffer: LogBuffer,
    private val repo: SettingsRepository,
    private val pollIntervalMs: Long = DEFAULT_POLL_MS,
) : ViewModel() {

    private val _paused = MutableStateFlow(false)
    val paused: StateFlow<Boolean> = _paused

    val events: StateFlow<List<LogEvent>> = flow {
        while (true) {
            if (!_paused.value) emit(logBuffer.snapshot())
            delay(pollIntervalMs)
        }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(STOP_TIMEOUT_MS), emptyList())

    val debugMode: StateFlow<Boolean> = repo.settings
        .map { it.privacy.debugMode }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(STOP_TIMEOUT_MS), false)

    fun togglePause() {
        _paused.value = !_paused.value
    }

    fun clear() {
        logBuffer.clear()
    }

    fun exportRedacted(): String = logBuffer.exportRedacted()

    fun setDebugMode(enabled: Boolean) {
        viewModelScope.launch {
            repo.update { it.copy(privacy = it.privacy.copy(debugMode = enabled)) }
        }
    }

    private companion object {
        const val DEFAULT_POLL_MS = 500L
        const val STOP_TIMEOUT_MS = 5_000L
    }
}

class LogViewerViewModelFactory(
    private val logBuffer: LogBuffer,
    private val repo: SettingsRepository,
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        require(modelClass.isAssignableFrom(LogViewerViewModel::class.java)) {
            "Unknown ViewModel class: ${modelClass.name}"
        }
        return LogViewerViewModel(logBuffer, repo) as T
    }
}
