package it.rignanese.leo.slim.data

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.MutablePreferences
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import it.rignanese.leo.slim.domain.CustomCode
import it.rignanese.leo.slim.domain.FeatureToggles
import it.rignanese.leo.slim.domain.NamedSnippet
import it.rignanese.leo.slim.domain.PermissionGrants
import it.rignanese.leo.slim.domain.PrivacySettings
import it.rignanese.leo.slim.domain.Settings
import it.rignanese.leo.slim.domain.StyleToggles
import it.rignanese.leo.slim.domain.WebViewSettings
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

/**
 * Reads and writes [Settings] backed by a Preferences DataStore.
 *
 * The mapping uses the legacy Flutter key names verbatim (see [SettingsKeys])
 * so [FlutterMigrator] can hand off values without renaming.
 */
class SettingsRepository(private val ds: DataStore<Preferences>) {

    val settings: Flow<Settings> = ds.data.map { prefs -> prefs.toSettings() }

    suspend fun update(transform: (Settings) -> Settings) {
        ds.edit { prefs ->
            val newSettings = transform(prefs.toSettings())
            newSettings.writeInto(prefs)
        }
    }
}

internal const val LEGACY_SNIPPET_ID = "legacy"
internal const val LEGACY_SNIPPET_NAME = "Imported"

internal fun Preferences.toSettings(): Settings = Settings(
    webView = WebViewSettings(
        customUserAgent = if (this[SettingsKeys.CUSTOM_USERAGENT_ENABLED] == true) {
            this[SettingsKeys.CUSTOM_USERAGENT]
        } else {
            null
        },
        customProxyEnabled = this[SettingsKeys.CUSTOM_PROXY_ENABLED] ?: false,
        customProxyHost = this[SettingsKeys.CUSTOM_PROXY_IP] ?: "",
        customProxyPort = this[SettingsKeys.CUSTOM_PROXY_PORT] ?: "",
    ),
    features = FeatureToggles(
        enableMessenger = this[SettingsKeys.ENABLE_MESSENGER] ?: true,
        hideAds = this[SettingsKeys.HIDE_ADS] ?: true,
        recentFirst = this[SettingsKeys.RECENT_FIRST] ?: false,
        useMbasic = this[SettingsKeys.USE_MBASIC] ?: false,
    ),
    style = StyleToggles(
        darkTheme = this[SettingsKeys.DARK_THEME] ?: false,
        fixedBar = this[SettingsKeys.FIXED_BAR] ?: true,
        hideStories = this[SettingsKeys.HIDE_STORIES] ?: false,
        centerText = this[SettingsKeys.CENTER_TEXT] ?: false,
        addSpace = this[SettingsKeys.ADD_SPACE] ?: false,
        hideMessengerSidebar = this[SettingsKeys.HIDE_MESSENGER_SIDEBAR] ?: true,
        // Remaining StyleToggles fields not represented in legacy XML — keep their data-class defaults.
    ),
    permissions = PermissionGrants(
        gps = this[SettingsKeys.GPS_PERMISSION] ?: false,
        camera = this[SettingsKeys.CAMERA_PERMISSION] ?: false,
        photo = this[SettingsKeys.PHOTO_PERMISSION] ?: false,
        photos = this[SettingsKeys.PHOTOS_PERMISSION] ?: false,
    ),
    customization = CustomCode(
        cssEntries = legacyCustomCss(this),
        jsEntries = legacyCustomJs(this),
        activeCssIds = legacyCustomCssActive(this),
        activeJsIds = legacyCustomJsActive(this),
    ),
    privacy = PrivacySettings(
        sentryEnabled = this[SettingsKeys.SENTRY_ENABLED] ?: true,
        debugMode = this[SettingsKeys.DEBUG_MODE] ?: false,
        customJsAcknowledged = this[SettingsKeys.CUSTOM_JS_ACKNOWLEDGED] ?: false,
    ),
)

internal fun legacyCustomCss(prefs: Preferences): List<NamedSnippet> {
    val code = prefs[SettingsKeys.CUSTOM_CSS].orEmpty()
    return if (code.isNotEmpty()) {
        listOf(NamedSnippet(id = LEGACY_SNIPPET_ID, name = LEGACY_SNIPPET_NAME, code = code, updatedAt = 0L))
    } else {
        emptyList()
    }
}

internal fun legacyCustomJs(prefs: Preferences): List<NamedSnippet> {
    val code = prefs[SettingsKeys.CUSTOM_JS].orEmpty()
    return if (code.isNotEmpty()) {
        listOf(NamedSnippet(id = LEGACY_SNIPPET_ID, name = LEGACY_SNIPPET_NAME, code = code, updatedAt = 0L))
    } else {
        emptyList()
    }
}

internal fun legacyCustomCssActive(prefs: Preferences): Set<String> {
    val enabled = prefs[SettingsKeys.CUSTOM_CSS_ENABLED] == true
    val code = prefs[SettingsKeys.CUSTOM_CSS].orEmpty()
    return if (enabled && code.isNotEmpty()) setOf(LEGACY_SNIPPET_ID) else emptySet()
}

internal fun legacyCustomJsActive(prefs: Preferences): Set<String> {
    val enabled = prefs[SettingsKeys.CUSTOM_JS_ENABLED] == true
    val code = prefs[SettingsKeys.CUSTOM_JS].orEmpty()
    return if (enabled && code.isNotEmpty()) setOf(LEGACY_SNIPPET_ID) else emptySet()
}

internal fun Settings.writeInto(prefs: MutablePreferences) {
    // WebView
    prefs[SettingsKeys.CUSTOM_USERAGENT_ENABLED] = webView.customUserAgent != null
    if (webView.customUserAgent != null) {
        prefs[SettingsKeys.CUSTOM_USERAGENT] = webView.customUserAgent!!
    } else {
        prefs.remove(SettingsKeys.CUSTOM_USERAGENT)
    }
    prefs[SettingsKeys.CUSTOM_PROXY_ENABLED] = webView.customProxyEnabled
    prefs[SettingsKeys.CUSTOM_PROXY_IP] = webView.customProxyHost
    prefs[SettingsKeys.CUSTOM_PROXY_PORT] = webView.customProxyPort

    // Features
    prefs[SettingsKeys.ENABLE_MESSENGER] = features.enableMessenger
    prefs[SettingsKeys.HIDE_ADS] = features.hideAds
    prefs[SettingsKeys.RECENT_FIRST] = features.recentFirst
    prefs[SettingsKeys.USE_MBASIC] = features.useMbasic

    // Style
    prefs[SettingsKeys.DARK_THEME] = style.darkTheme
    prefs[SettingsKeys.FIXED_BAR] = style.fixedBar
    prefs[SettingsKeys.HIDE_STORIES] = style.hideStories
    prefs[SettingsKeys.CENTER_TEXT] = style.centerText
    prefs[SettingsKeys.ADD_SPACE] = style.addSpace
    prefs[SettingsKeys.HIDE_MESSENGER_SIDEBAR] = style.hideMessengerSidebar

    // Permissions
    prefs[SettingsKeys.GPS_PERMISSION] = permissions.gps
    prefs[SettingsKeys.CAMERA_PERMISSION] = permissions.camera
    prefs[SettingsKeys.PHOTO_PERMISSION] = permissions.photo
    prefs[SettingsKeys.PHOTOS_PERMISSION] = permissions.photos

    // Customization — flatten the legacy single-snippet model back to the legacy XML keys.
    val legacyCss = customization.cssEntries.firstOrNull { it.id == LEGACY_SNIPPET_ID }
        ?: customization.cssEntries.firstOrNull()
    val legacyJs = customization.jsEntries.firstOrNull { it.id == LEGACY_SNIPPET_ID }
        ?: customization.jsEntries.firstOrNull()
    if (legacyCss != null) {
        prefs[SettingsKeys.CUSTOM_CSS] = legacyCss.code
    } else {
        prefs.remove(SettingsKeys.CUSTOM_CSS)
    }
    prefs[SettingsKeys.CUSTOM_CSS_ENABLED] =
        legacyCss != null && customization.activeCssIds.contains(legacyCss.id)
    if (legacyJs != null) {
        prefs[SettingsKeys.CUSTOM_JS] = legacyJs.code
    } else {
        prefs.remove(SettingsKeys.CUSTOM_JS)
    }
    prefs[SettingsKeys.CUSTOM_JS_ENABLED] =
        legacyJs != null && customization.activeJsIds.contains(legacyJs.id)

    // Privacy
    prefs[SettingsKeys.SENTRY_ENABLED] = privacy.sentryEnabled
    prefs[SettingsKeys.DEBUG_MODE] = privacy.debugMode
    prefs[SettingsKeys.CUSTOM_JS_ACKNOWLEDGED] = privacy.customJsAcknowledged
}
