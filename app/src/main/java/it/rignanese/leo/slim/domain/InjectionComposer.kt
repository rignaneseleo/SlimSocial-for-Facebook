package it.rignanese.leo.slim.domain

/**
 * Combines a list of [InjectionRule]s into one CSS block and one JS block
 * for a given URL. Order of rules is preserved.
 */
class InjectionComposer {
    fun compose(rules: List<InjectionRule>, url: String): InjectionPayload {
        val css = rules.mapNotNull { it.cssFor(url) }.joinToString("\n")
        val js = rules.mapNotNull { it.jsFor(url) }.joinToString(";\n")
        return InjectionPayload(css, js)
    }
}

data class InjectionPayload(val css: String, val js: String)
