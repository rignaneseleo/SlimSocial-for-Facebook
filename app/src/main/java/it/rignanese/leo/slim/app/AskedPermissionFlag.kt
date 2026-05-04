package it.rignanese.leo.slim.app

import android.content.Context

/**
 * SharedPreferences-backed boolean flag tracking whether the host activity has
 * ever issued a runtime permission request for a given Android permission name.
 *
 * Used by [it.rignanese.leo.slim.permissions.OsPermissionStateReader] to
 * disambiguate "first ask" from "permanently denied" when
 * `shouldShowRequestPermissionRationale` returns false.
 *
 * SharedPreferences (rather than DataStore) is intentional: a single boolean
 * per Android permission, fully synchronous reads acceptable on the main thread,
 * and the WebView callback that consults this flag is itself synchronous.
 */
class AskedPermissionFlag(context: Context) {

    private val prefs = context.getSharedPreferences(NAME, Context.MODE_PRIVATE)

    fun wasAsked(androidPerm: String): Boolean = prefs.getBoolean(androidPerm, false)

    fun mark(androidPerm: String) {
        prefs.edit().putBoolean(androidPerm, true).apply()
    }

    private companion object {
        const val NAME = "asked_permissions"
    }
}
