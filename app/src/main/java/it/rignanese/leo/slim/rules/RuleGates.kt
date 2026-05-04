package it.rignanese.leo.slim.rules

/**
 * URL-host gating helpers shared by all built-in injection rules.
 * Pure functions — no Android imports.
 */
internal object RuleGates {
    fun isFbHost(url: String): Boolean {
        val host = runCatching { java.net.URI(url).host }.getOrNull() ?: return false
        return host.endsWith("facebook.com") || host.endsWith("fb.com") || host.endsWith("fb.me")
    }

    fun isMessengerHost(url: String): Boolean {
        val host = runCatching { java.net.URI(url).host }.getOrNull() ?: return false
        return host.endsWith("messenger.com") || host.endsWith("m.me")
    }
}
