package it.rignanese.leo.slim.app

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.preferencesDataStore
import it.rignanese.leo.slim.data.FlutterMigrator
import it.rignanese.leo.slim.data.LogBuffer
import it.rignanese.leo.slim.data.SettingsRepository
import it.rignanese.leo.slim.domain.HomeUrlBuilder
import it.rignanese.leo.slim.domain.InjectionComposer
import it.rignanese.leo.slim.domain.UrlRouter
import it.rignanese.leo.slim.domain.UserAgentResolver
import it.rignanese.leo.slim.permissions.OsPermissionStateReader
import it.rignanese.leo.slim.platform.Platform
import it.rignanese.leo.slim.platform.providePlatform
import it.rignanese.leo.slim.rules.RuleRegistry
import it.rignanese.leo.slim.rules.ThemeRuleSource
import it.rignanese.leo.slim.rules.provideThemeRuleSource
import it.rignanese.leo.slim.webview.CookieConfigurator
import it.rignanese.leo.slim.webview.CustomTabsUrlOpener
import it.rignanese.leo.slim.webview.DarkModeConfigurator
import it.rignanese.leo.slim.webview.LiveWebViewHost
import it.rignanese.leo.slim.webview.ProxyConfigurator
import it.rignanese.leo.slim.webview.UrlOpener
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "settings")

/**
 * Manual dependency-injection container for application-scoped singletons.
 *
 * Constructed once in [SlimApplication.onCreate]; lifetime equals the process.
 * Consumers (Activities, ViewModels, Compose roots) reach the container via
 * `(application as SlimApplication).container`.
 */
class AppContainer(appContext: Context) {

    val dataStore: DataStore<Preferences> = appContext.dataStore

    /**
     * Application-lifetime scope for platform background work (entitlement
     * cache seeding + billing re-verification). Never cancelled — it dies
     * with the process, like every other AppContainer singleton.
     */
    val appScope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    val settingsRepository: SettingsRepository = SettingsRepository(dataStore)
    val flutterMigrator: FlutterMigrator = FlutterMigrator(appContext, dataStore)
    val logBuffer: LogBuffer = LogBuffer()

    val urlRouter: UrlRouter = UrlRouter()
    val homeUrlBuilder: HomeUrlBuilder = HomeUrlBuilder()
    val userAgentResolver: UserAgentResolver = UserAgentResolver()
    val injectionComposer: InjectionComposer = InjectionComposer()

    /** Flavor-resolved PRO theme catalog (full: real themes; fdroid: empty). */
    val themeRuleSource: ThemeRuleSource = provideThemeRuleSource()
    val ruleRegistry: RuleRegistry = RuleRegistry(themeRuleSource)

    val cookieConfigurator: CookieConfigurator = CookieConfigurator()
    val proxyConfigurator: ProxyConfigurator = ProxyConfigurator()
    val darkModeConfigurator: DarkModeConfigurator = DarkModeConfigurator()
    val urlOpener: UrlOpener = CustomTabsUrlOpener()

    /**
     * Flavor-provided platform services (crash reporting, donations, reviews).
     * Resolved at compile time via the `providePlatform(Context)` function
     * defined in `src/full/.../platform/PlatformProvider.kt` or
     * `src/fdroid/.../platform/PlatformProvider.kt`.
     */
    val platform: Platform = providePlatform(appContext, dataStore, appScope)

    val askedPermissionFlag: AskedPermissionFlag = AskedPermissionFlag(appContext)
    val osPermissionReader: OsPermissionStateReader =
        OsPermissionStateReader(askedPermissionFlag::wasAsked)

    /**
     * Mutable holder for the currently-mounted [it.rignanese.leo.slim.webview.WebViewHost].
     * Set by [it.rignanese.leo.slim.ui.BrowserScreen] when the WebView factory runs;
     * read by the editor's "Test" button so it can route a one-off injection through
     * the live WebView. Cleared on disposal to avoid retaining a destroyed view.
     */
    val liveWebViewHost: LiveWebViewHost = LiveWebViewHost()
}
