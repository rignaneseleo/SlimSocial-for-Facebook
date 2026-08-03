package it.rignanese.leo.slim.debug

import it.rignanese.leo.slim.data.LogBuffer
import it.rignanese.leo.slim.data.LogEvent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

/**
 * Debug-only: streams [LogBuffer] events off-device so a remote developer can
 * watch what the WebView is doing without the tester copying anything.
 *
 * Why this exists: the WebChromeClient already funnels every JS `console.*`
 * message and page error into [LogBuffer], but reading it means opening the Log
 * viewer and screenshotting it by hand. Shipping the same events to a
 * collector closes the loop — the tester just uses the app.
 *
 * Why the app and not injected JS: Facebook's Content-Security-Policy blocks
 * off-origin `fetch`/`img` from page context, so a beacon from an injected
 * script cannot leave the page. Native HTTP is not subject to page CSP.
 *
 * This class lives in `src/debug` and therefore **cannot be compiled into a
 * release build**. Events are already redacted by [LogBuffer] (cookies and URL
 * query strings are stripped) before they get here.
 *
 * The endpoint is tailnet-only over HTTPS; if it is unreachable the shipper
 * fails silently and keeps running.
 */
class DebugLogShipper(
    private val logBuffer: LogBuffer,
    private val endpoint: String = DEFAULT_ENDPOINT,
    private val intervalMs: Long = 3_000,
) {
    private var lastSeen: Long = 0

    fun start(scope: CoroutineScope) {
        scope.launch(Dispatchers.IO) {
            while (isActive) {
                runCatching { flush() }
                delay(intervalMs)
            }
        }
    }

    private fun flush() {
        val fresh = logBuffer.snapshot().filter { it.timestampMs > lastSeen }
        if (fresh.isEmpty()) return
        lastSeen = fresh.maxOf { it.timestampMs }
        post(fresh.joinToString("\n") { format(it) })
    }

    private fun format(e: LogEvent) = "[${e.timestampMs}] ${e.category}: ${e.message}"

    private fun post(body: String) {
        val conn = URL(endpoint).openConnection() as HttpURLConnection
        conn.requestMethod = "POST"
        conn.connectTimeout = 5_000
        conn.readTimeout = 5_000
        conn.doOutput = true
        conn.setRequestProperty("Content-Type", "text/plain; charset=utf-8")
        try {
            OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { it.write(body) }
            conn.responseCode // triggers the request
        } finally {
            conn.disconnect()
        }
    }

    companion object {
        const val DEFAULT_ENDPOINT = "https://vps-claude-new.taildf8ada.ts.net/apks/log"
    }
}
