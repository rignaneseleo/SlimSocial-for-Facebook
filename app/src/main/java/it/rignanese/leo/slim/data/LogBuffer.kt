package it.rignanese.leo.slim.data

/**
 * Categories of events captured by [LogBuffer].
 */
enum class LogCategory {
    LIFECYCLE,
    NAV,
    INJECT,
    CONSOLE,
    PERMISSION,
    RENDER_GONE,
    SENTRY,
    OTHER,
}

data class LogEvent(
    val timestampMs: Long,
    val category: LogCategory,
    val message: String,
)

/**
 * Bounded ring buffer for in-memory diagnostic events.
 *
 * On record(), messages are redacted before storage so a later export cannot
 * leak Facebook session cookies or URL query strings even if developers paste
 * the snapshot into a bug report.
 *
 * Thread-safe via a coarse intrinsic lock — write/read traffic is low (UI events,
 * navigation, console logs) so contention is not a concern.
 */
class LogBuffer(private val capacity: Int = 500) {

    init {
        require(capacity > 0) { "capacity must be > 0" }
    }

    private val buf = ArrayDeque<LogEvent>(capacity)
    private val lock = Any()

    fun record(category: LogCategory, message: String, now: Long = System.currentTimeMillis()) {
        synchronized(lock) {
            buf.addLast(LogEvent(now, category, redact(message)))
            while (buf.size > capacity) {
                buf.removeFirst()
            }
        }
    }

    fun snapshot(): List<LogEvent> = synchronized(lock) { buf.toList() }

    fun clear() = synchronized(lock) { buf.clear() }

    fun exportRedacted(): String =
        snapshot().joinToString("\n") { "[${it.timestampMs}] ${it.category}: ${it.message}" }

    private fun redact(input: String): String {
        // 1. Strip URL query strings entirely (URL itself is preserved up to the '?').
        var s = URL_QUERY_RE.replace(input) { match -> match.groupValues[1] }
        // 2. Redact Facebook session cookie pairs (e.g. c_user=12345 → c_user=<redacted>).
        s = COOKIE_PAIR_RE.replace(s) { match -> "${match.groupValues[1]}=<redacted>" }
        return s
    }

    companion object {
        /** Facebook session-related cookie names that must never leak. */
        private val FB_SESSION_NAMES = setOf("c_user", "xs", "fr", "presence", "wd", "dpr", "sb", "datr")
        private val COOKIE_PAIR_RE = Regex("(${FB_SESSION_NAMES.joinToString("|")})=([^;\\s]+)")
        private val URL_QUERY_RE = Regex("(https?://[^?\\s]+)\\?[^\\s]*")
    }
}
