package it.rignanese.leo.slim.rules

import it.rignanese.leo.slim.domain.CustomCode
import it.rignanese.leo.slim.domain.InjectionRule

/**
 * Concatenates the user's active custom JS snippets. Order matches
 * `jsEntries`, filtered by `activeJsIds`. Returns null when nothing is active.
 */
class UserCustomJsRule(private val custom: CustomCode) : InjectionRule {
    override val id: String = "user_js"

    override fun jsFor(url: String): String? {
        val active = custom.jsEntries.filter { it.id in custom.activeJsIds }
        if (active.isEmpty()) return null
        return active.joinToString("\n") { it.code }
    }
}
