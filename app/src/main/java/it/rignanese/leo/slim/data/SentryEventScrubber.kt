package it.rignanese.leo.slim.data

/**
 * Subset of fields scrubbed before they reach the Sentry SDK in the `full`
 * flavor. The SDK itself is NOT imported here so this file is safe to compile
 * and unit-test in the F-Droid flavor too — the flavor shim that constructs a
 * `SentryEvent` will adapt these fields back to Sentry's types.
 */
data class ScrubInput(
    val cookies: String? = null,
    val queryString: String? = null,
    val headers: Map<String, String> = emptyMap(),
    val extras: Map<String, String> = emptyMap(),
    val tags: Map<String, String> = emptyMap(),
)

/**
 * Pure scrubbing logic that strips Facebook session cookies and any
 * key whose name suggests a credential (token / password / secret / auth /
 * cookie). Called from the Sentry `BeforeSendCallback` in the full flavor.
 */
object SentryEventScrubber {

    private val SENSITIVE_KEY = Regex("(?i)(token|password|secret|auth|cookie)")
    private val FB_SESSION_COOKIE_NAMES = setOf("c_user", "xs", "fr", "presence", "wd", "dpr", "sb", "datr")
    private val FB_VALUE_PATTERN = Regex(
        "(?:" + FB_SESSION_COOKIE_NAMES.joinToString("|") + ")=[^;\\s]*"
    )

    fun scrub(input: ScrubInput): ScrubInput = ScrubInput(
        cookies = null,
        queryString = null,
        headers = scrubMap(input.headers),
        extras = scrubMap(input.extras),
        tags = scrubMap(input.tags),
    )

    private fun scrubMap(m: Map<String, String>): Map<String, String> =
        m.filterKeys { !SENSITIVE_KEY.containsMatchIn(it) }
            .mapValues { (_, v) -> stripFbSession(v) }

    private fun stripFbSession(s: String): String = FB_VALUE_PATTERN.replace(s, "<redacted>")
}
