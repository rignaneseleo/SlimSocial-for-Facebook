package it.rignanese.leo.slim.debug

import it.rignanese.leo.slim.data.LogBuffer
import kotlinx.coroutines.CoroutineScope

/**
 * Debug build: stream diagnostics to the remote collector.
 *
 * Same flavor-split top-level function pattern as `providePlatform` — the
 * `release` source set declares a no-op with the identical signature, so the
 * shipper cannot end up in a shipped build.
 */
fun startDebugDiagnostics(logBuffer: LogBuffer, scope: CoroutineScope) {
    DebugLogShipper(logBuffer).start(scope)
}
