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
import it.rignanese.leo.slim.rules.RuleRegistry
import it.rignanese.leo.slim.webview.CookieConfigurator
import it.rignanese.leo.slim.webview.CustomTabsUrlOpener
import it.rignanese.leo.slim.webview.DarkModeConfigurator
import it.rignanese.leo.slim.webview.ProxyConfigurator
import it.rignanese.leo.slim.webview.UrlOpener

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

    val settingsRepository: SettingsRepository = SettingsRepository(dataStore)
    val flutterMigrator: FlutterMigrator = FlutterMigrator(appContext, dataStore)
    val logBuffer: LogBuffer = LogBuffer()

    val urlRouter: UrlRouter = UrlRouter()
    val homeUrlBuilder: HomeUrlBuilder = HomeUrlBuilder()
    val userAgentResolver: UserAgentResolver = UserAgentResolver()
    val injectionComposer: InjectionComposer = InjectionComposer()
    val ruleRegistry: RuleRegistry = RuleRegistry()

    val cookieConfigurator: CookieConfigurator = CookieConfigurator()
    val proxyConfigurator: ProxyConfigurator = ProxyConfigurator()
    val darkModeConfigurator: DarkModeConfigurator = DarkModeConfigurator()
    val urlOpener: UrlOpener = CustomTabsUrlOpener()

    val askedPermissionFlag: AskedPermissionFlag = AskedPermissionFlag(appContext)
    val osPermissionReader: OsPermissionStateReader =
        OsPermissionStateReader(askedPermissionFlag::wasAsked)
}
