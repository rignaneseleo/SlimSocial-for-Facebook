package it.rignanese.leo.slim.domain

/**
 * A single CSS/JS injection rule. Implementations are pure functions of
 * URL and config — no Flow, no Android imports.
 */
interface InjectionRule {
    val id: String
    fun cssFor(url: String): String? = null
    fun jsFor(url: String): String? = null
}
