package it.rignanese.leo.slim.data

import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey

/**
 * Typed Preferences keys mirroring the legacy Flutter SharedPreferences names
 * verbatim (plan §0.5). Keeping the names identical lets [FlutterMigrator] copy
 * values from `FlutterSharedPreferences.xml` into DataStore without renaming.
 *
 * Three additional keys (`sentry_enabled`, `debug_mode`, `custom_js_acknowledged`)
 * are new in the Kotlin rewrite — they have no legacy equivalent.
 */
object SettingsKeys {
    val ENABLE_MESSENGER = booleanPreferencesKey("enable_messenger")
    val HIDE_ADS = booleanPreferencesKey("hide_ads")
    val RECENT_FIRST = booleanPreferencesKey("recent_first")
    val USE_MBASIC = booleanPreferencesKey("use_mbasic")
    val GPS_PERMISSION = booleanPreferencesKey("gps_permission")
    val CAMERA_PERMISSION = booleanPreferencesKey("camera_permission")
    val PHOTO_PERMISSION = booleanPreferencesKey("photo_permission")
    val PHOTOS_PERMISSION = booleanPreferencesKey("photos_permission")
    val DARK_THEME = booleanPreferencesKey("dark_theme")
    val FIXED_BAR = booleanPreferencesKey("fixed_bar")
    val HIDE_STORIES = booleanPreferencesKey("hide_stories")
    val CENTER_TEXT = booleanPreferencesKey("center_text")
    val ADD_SPACE = booleanPreferencesKey("add_space")
    val HIDE_MESSENGER_SIDEBAR = booleanPreferencesKey("hide_messenger_sidebar")
    val CUSTOM_USERAGENT_ENABLED = booleanPreferencesKey("custom_useragent_enabled")
    val CUSTOM_USERAGENT = stringPreferencesKey("custom_useragent")
    val CUSTOM_JS_ENABLED = booleanPreferencesKey("custom_js_enabled")
    val CUSTOM_JS = stringPreferencesKey("custom_js")
    val CUSTOM_CSS_ENABLED = booleanPreferencesKey("custom_css_enabled")
    val CUSTOM_CSS = stringPreferencesKey("custom_css")
    val CUSTOM_PROXY_ENABLED = booleanPreferencesKey("custom_proxy_enabled")
    val CUSTOM_PROXY_IP = stringPreferencesKey("custom_proxy_ip")
    val CUSTOM_PROXY_PORT = stringPreferencesKey("custom_proxy_port")

    // privacy / debug — new in Kotlin rewrite, no legacy equivalent
    val SENTRY_ENABLED = booleanPreferencesKey("sentry_enabled")
    val DEBUG_MODE = booleanPreferencesKey("debug_mode")
    val CUSTOM_JS_ACKNOWLEDGED = booleanPreferencesKey("custom_js_acknowledged")

    /**
     * The set of legacy key names (without `flutter.` prefix) recognised by the
     * Flutter migrator. Used for migration coverage reports.
     */
    val LEGACY_NAMES: Set<String> = setOf(
        ENABLE_MESSENGER.name,
        HIDE_ADS.name,
        RECENT_FIRST.name,
        USE_MBASIC.name,
        GPS_PERMISSION.name,
        CAMERA_PERMISSION.name,
        PHOTO_PERMISSION.name,
        PHOTOS_PERMISSION.name,
        DARK_THEME.name,
        FIXED_BAR.name,
        HIDE_STORIES.name,
        CENTER_TEXT.name,
        ADD_SPACE.name,
        HIDE_MESSENGER_SIDEBAR.name,
        CUSTOM_USERAGENT_ENABLED.name,
        CUSTOM_USERAGENT.name,
        CUSTOM_JS_ENABLED.name,
        CUSTOM_JS.name,
        CUSTOM_CSS_ENABLED.name,
        CUSTOM_CSS.name,
        CUSTOM_PROXY_ENABLED.name,
        CUSTOM_PROXY_IP.name,
        CUSTOM_PROXY_PORT.name,
    )
}
