package it.rignanese.leo.slim.data

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.MutablePreferences
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.w3c.dom.Element
import org.w3c.dom.Node

/**
 * Outcome of a single [FlutterMigrator.migrateOnce] call.
 *
 * - [keysFound]    legacy keys read from XML.
 * - [keysMissing]  legacy keys defined in [SettingsKeys.LEGACY_NAMES] that
 *                  were not present in the XML (informational).
 * - [error]        non-null when parsing or writing failed; the source file is
 *                  left untouched so a future run can retry.
 */
data class MigrationReport(
    val keysFound: Int,
    val keysMissing: List<String>,
    val error: Throwable?,
)

/**
 * Reads `<baseDir>/shared_prefs/FlutterSharedPreferences.xml` (the on-disk
 * format `package:shared_preferences` writes from Flutter) and copies recognised
 * keys into a Preferences DataStore.
 *
 * Idempotent: after a successful run the source file is renamed with a
 * `.migrated` suffix and subsequent calls become no-ops.
 *
 * Tests construct the migrator with [forBaseDir] so they don't need a Context.
 * Production code uses [forContext] or the public constructor.
 */
class FlutterMigrator internal constructor(
    private val baseDir: File,
    private val ds: DataStore<Preferences>,
) {
    constructor(context: Context, ds: DataStore<Preferences>) : this(
        baseDir = context.filesDir.parentFile ?: context.filesDir,
        ds = ds,
    )

    suspend fun migrateOnce(): MigrationReport {
        val source = File(baseDir, "shared_prefs/FlutterSharedPreferences.xml")
        val migrated = File(source.parentFile, source.name + ".migrated")
        if (!source.exists() || migrated.exists()) {
            return MigrationReport(keysFound = 0, keysMissing = emptyList(), error = null)
        }
        return runCatching {
            val parsed = parseFlutterPrefs(source)
            ds.edit { prefs -> writeParsedToPrefs(parsed, prefs) }
            // Rename only after the edit committed. If rename fails we still
            // succeeded but the next run will re-apply the same values
            // (idempotent in practice — values are deterministic).
            source.renameTo(migrated)
            MigrationReport(
                keysFound = parsed.size,
                keysMissing = (SettingsKeys.LEGACY_NAMES - parsed.keys).toList().sorted(),
                error = null,
            )
        }.getOrElse { MigrationReport(0, emptyList(), it) }
    }

    companion object {
        fun forBaseDir(baseDir: File, ds: DataStore<Preferences>): FlutterMigrator =
            FlutterMigrator(baseDir, ds)

        fun forContext(context: Context, ds: DataStore<Preferences>): FlutterMigrator =
            FlutterMigrator(context, ds)
    }
}

/**
 * Result of parsing the Flutter shared-prefs XML — either a Boolean or a String.
 * Keys are returned with the `flutter.` prefix already stripped.
 */
internal sealed class FlutterValue {
    data class Bool(val value: Boolean) : FlutterValue()
    data class Str(val value: String) : FlutterValue()
}

private const val FLUTTER_PREFIX = "flutter."

internal fun parseFlutterPrefs(file: File): Map<String, FlutterValue> {
    val out = mutableMapOf<String, FlutterValue>()
    // Using javax.xml DocumentBuilder rather than XmlPullParser because
    // XmlPullParserFactory is part of the Android stubs jar (returns null in
    // pure-JVM unit tests). DocumentBuilder is in the JDK and works in both.
    val factory = DocumentBuilderFactory.newInstance().apply {
        isNamespaceAware = false
        // Defensive: disable potentially-unsafe features that aren't needed.
        try { setFeature("http://apache.org/xml/features/disallow-doctype-decl", true) } catch (_: Throwable) {}
    }
    val doc = file.inputStream().use { input -> factory.newDocumentBuilder().parse(input) }
    val nodes = doc.documentElement?.childNodes ?: return out
    for (i in 0 until nodes.length) {
        val node = nodes.item(i)
        if (node.nodeType != Node.ELEMENT_NODE) continue
        val el = node as Element
        val rawName = el.getAttribute("name")
        if (!rawName.startsWith(FLUTTER_PREFIX)) continue
        val key = rawName.removePrefix(FLUTTER_PREFIX)
        when (el.tagName) {
            "boolean" -> {
                val v = el.getAttribute("value")
                if (v.isNotEmpty()) out[key] = FlutterValue.Bool(v == "true")
            }
            "string" -> {
                out[key] = FlutterValue.Str(el.textContent ?: "")
            }
            // int / long / float / set: not used by SlimSocial settings
            else -> Unit
        }
    }
    return out
}

internal fun writeParsedToPrefs(
    parsed: Map<String, FlutterValue>,
    prefs: MutablePreferences,
) {
    for ((name, value) in parsed) {
        if (name !in SettingsKeys.LEGACY_NAMES) continue
        when (value) {
            is FlutterValue.Bool -> prefs[booleanPreferencesKey(name)] = value.value
            is FlutterValue.Str -> prefs[stringPreferencesKey(name)] = value.value
        }
    }
}
