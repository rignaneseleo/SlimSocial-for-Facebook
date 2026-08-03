package it.rignanese.leo.slim.debug

import it.rignanese.leo.slim.data.LogBuffer
import kotlinx.coroutines.CoroutineScope

/**
 * Release build: diagnostics streaming does not exist. No network call, no
 * collector endpoint compiled in.
 */
@Suppress("UNUSED_PARAMETER")
fun startDebugDiagnostics(logBuffer: LogBuffer, scope: CoroutineScope) = Unit
