package it.rignanese.leo.slim.domain

/**
 * Aggregate of all user-configurable settings, mirroring the legacy Flutter
 * SharedPreferences schema described in plan §0.5.
 */
data class Settings(
    val webView: WebViewSettings,
    val features: FeatureToggles,
    val style: StyleToggles,
    val permissions: PermissionGrants,
    val customization: CustomCode,
    val privacy: PrivacySettings,
) {
    companion object {
        /**
         * Defaults that exactly match the legacy Flutter behavior (plan §0.5).
         * The four "TRUE" defaults — `enableMessenger`, `hideAds`, `fixedBar`,
         * `hideMessengerSidebar` — are required for behavioral parity on first run.
         * `sentryEnabled` is `true` because Sentry was opt-out in the legacy app
         * (full flavor only honors it).
         */
        val DEFAULT: Settings = Settings(
            webView = WebViewSettings(),
            features = FeatureToggles(),
            style = StyleToggles(),
            permissions = PermissionGrants(),
            customization = CustomCode(),
            privacy = PrivacySettings(),
        )
    }
}

data class FeatureToggles(
    val enableMessenger: Boolean = true,   // legacy default TRUE
    val hideAds: Boolean = true,           // legacy default TRUE
    val recentFirst: Boolean = false,
    val useMbasic: Boolean = false,
)

data class StyleToggles(
    val darkTheme: Boolean = false,
    val fixedBar: Boolean = true,                  // legacy TRUE
    val hideStories: Boolean = false,
    val centerText: Boolean = false,
    val addSpace: Boolean = false,
    val hideMessengerSidebar: Boolean = true,      // legacy TRUE
    val darkThemeMessenger: Boolean = false,
    val removeMessengerDownload: Boolean = false,
    val removeBrowserNotSupported: Boolean = false,
    val hideAdsAndPeopleYouMayKnow: Boolean = false,
    val fabBtn: Boolean = false,
    val adaptMessenger: Boolean = false,
    /** PRO page theme id (see ThemeRuleSource), or null for no theme. New in WS1, no legacy key. */
    val selectedTheme: String? = null,
)

data class PermissionGrants(
    val gps: Boolean = false,
    val camera: Boolean = false,
    val photo: Boolean = false,
    val photos: Boolean = false,
    val mic: Boolean = false,
    val notifications: Boolean = false,
)

data class CustomCode(
    val cssEntries: List<NamedSnippet> = emptyList(),
    val jsEntries: List<NamedSnippet> = emptyList(),
    val activeCssIds: Set<String> = emptySet(),
    val activeJsIds: Set<String> = emptySet(),
)

data class NamedSnippet(
    val id: String,
    val name: String,
    val code: String,
    val updatedAt: Long,
)

data class WebViewSettings(
    val customUserAgent: String? = null,
    val customProxyEnabled: Boolean = false,
    val customProxyHost: String = "",
    val customProxyPort: String = "",
)

data class PrivacySettings(
    val sentryEnabled: Boolean = true,
    val debugMode: Boolean = false,
    val customJsAcknowledged: Boolean = false,
)
