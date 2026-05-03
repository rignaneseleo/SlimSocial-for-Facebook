package it.rignanese.leo.slim.domain

import java.net.URI
import java.net.URISyntaxException

sealed class Route {
    data class InApp(val url: String) : Route()
    data class Messenger(val url: String) : Route()
    data class External(val url: String) : Route()
}

/**
 * Decides whether a navigation should stay in-app, hop to the Messenger surface,
 * or be punted to an external browser. Hostnames default to the legacy Flutter
 * lists from `lib/consts.dart`.
 */
class UrlRouter(
    private val fbHosts: Set<String> = setOf("facebook.com", "fb.com", "fb.me"),
    private val messengerHosts: Set<String> = setOf("messenger.com", "m.me"),
) {
    fun route(url: String): Route {
        val host = parseHost(url) ?: return Route.External(url)
        return when {
            matches(host, fbHosts) -> Route.InApp(url)
            matches(host, messengerHosts) -> Route.Messenger(url)
            else -> Route.External(url)
        }
    }

    private fun parseHost(url: String): String? {
        if (url.isBlank()) return null
        return try {
            val uri = URI(url)
            uri.host?.lowercase()?.takeIf { it.isNotBlank() }
        } catch (_: URISyntaxException) {
            null
        } catch (_: IllegalArgumentException) {
            null
        }
    }

    /**
     * True if [host] equals one of [allowed], or is a proper sub-domain of one
     * (i.e. ends with `.<allowed>`). Prevents `notfacebook.com` from matching.
     */
    private fun matches(host: String, allowed: Set<String>): Boolean {
        return allowed.any { allowedHost ->
            host == allowedHost || host.endsWith(".$allowedHost")
        }
    }
}
