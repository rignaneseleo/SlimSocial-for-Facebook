package it.rignanese.leo.slim.rules

import it.rignanese.leo.slim.domain.CustomCode
import it.rignanese.leo.slim.domain.InjectionRule

/**
 * Concatenates the user's active custom CSS snippets. Order matches
 * `cssEntries`, filtered by `activeCssIds`. Returns null when nothing is
 * active so the composer can skip an empty block.
 */
class UserCustomCssRule(private val custom: CustomCode) : InjectionRule {
    override val id: String = "user_css"

    override fun cssFor(url: String): String? {
        val active = custom.cssEntries.filter { it.id in custom.activeCssIds }
        if (active.isEmpty()) return null
        return active.joinToString("\n") { it.code }
    }
}
