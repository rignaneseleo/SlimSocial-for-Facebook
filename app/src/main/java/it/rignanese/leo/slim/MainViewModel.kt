package it.rignanese.leo.slim

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import it.rignanese.leo.slim.app.AppContainer
import it.rignanese.leo.slim.data.SettingsRepository
import it.rignanese.leo.slim.domain.HomeUrlBuilder
import it.rignanese.leo.slim.domain.InjectionComposer
import it.rignanese.leo.slim.domain.InjectionPayload
import it.rignanese.leo.slim.domain.PermissionGrants
import it.rignanese.leo.slim.domain.Settings
import it.rignanese.leo.slim.domain.UserAgentResolver
import it.rignanese.leo.slim.platform.ProEntitlement
import it.rignanese.leo.slim.rules.RuleRegistry
import it.rignanese.leo.slim.webview.CookieConfigurator
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

/**
 * ViewModel that wires reactive [Settings] to URL/UA derivations, drives
 * per-page injection, and brokers render-process-gone + deeplink events.
 *
 * Construction is split:
 *  - The internal primary constructor takes individual collaborators so unit
 *    tests can pass test doubles without standing up a full [AppContainer].
 *  - The convenience secondary constructor accepts an [AppContainer] for
 *    production wiring from [MainActivity].
 */
class MainViewModel internal constructor(
    private val settingsRepository: SettingsRepository,
    private val homeUrlBuilder: HomeUrlBuilder,
    private val userAgentResolver: UserAgentResolver,
    private val injectionComposer: InjectionComposer,
    private val ruleRegistry: RuleRegistry,
    private val cookieConfigurator: CookieConfigurator,
    private val proEntitlement: ProEntitlement,
) : ViewModel() {

    constructor(container: AppContainer) : this(
        settingsRepository = container.settingsRepository,
        homeUrlBuilder = container.homeUrlBuilder,
        userAgentResolver = container.userAgentResolver,
        injectionComposer = container.injectionComposer,
        ruleRegistry = container.ruleRegistry,
        cookieConfigurator = container.cookieConfigurator,
        proEntitlement = container.platform.proEntitlement,
    )

    val settings: StateFlow<Settings> = settingsRepository.settings
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(STOP_TIMEOUT_MS), Settings.DEFAULT)

    val homeUrl: StateFlow<String> = settings
        .map { homeUrlBuilder.build(it.features.useMbasic, it.features.recentFirst) }
        .stateIn(
            viewModelScope,
            SharingStarted.WhileSubscribed(STOP_TIMEOUT_MS),
            homeUrlBuilder.build(useMbasic = false, recentFirst = false),
        )

    val userAgent: StateFlow<String> = settings
        .map {
            userAgentResolver.resolve(
                customEnabled = it.webView.customUserAgent != null,
                customUa = it.webView.customUserAgent,
                useMbasic = it.features.useMbasic,
            )
        }
        .stateIn(
            viewModelScope,
            SharingStarted.WhileSubscribed(STOP_TIMEOUT_MS),
            UserAgentResolver.UA_FIREFOX,
        )

    private val _renderGone = MutableSharedFlow<Boolean>(extraBufferCapacity = 1)
    val renderGone: SharedFlow<Boolean> = _renderGone

    private val _deeplinkUrl = MutableSharedFlow<String>(extraBufferCapacity = 1)
    val deeplinkUrl: SharedFlow<String> = _deeplinkUrl

    /**
     * Compose the active CSS+JS payload for [currentUrl] from the latest settings
     * snapshot. Called on every page-ready event from the WebView client.
     */
    fun composeInjection(currentUrl: String): InjectionPayload {
        val rules = ruleRegistry.activeRules(settings.value, isPro = proEntitlement.isPro.value)
        return injectionComposer.compose(rules, currentUrl)
    }

    fun onRenderGone(didCrash: Boolean) {
        viewModelScope.launch { _renderGone.emit(didCrash) }
    }

    fun handleDeeplink(url: String) {
        viewModelScope.launch { _deeplinkUrl.emit(url) }
    }

    fun flushCookies() = cookieConfigurator.flush()

    fun grantsProvider(): () -> PermissionGrants = { settings.value.permissions }

    private companion object {
        const val STOP_TIMEOUT_MS = 5_000L
    }
}

/**
 * `ViewModelProvider.Factory` that constructs [MainViewModel] from a live
 * [AppContainer]. The activity reference is captured but not required by the
 * VM itself in Phase 7 — Phase 8 will use it for runtime permission requests.
 */
class MainViewModelFactory(
    private val container: AppContainer,
) : ViewModelProvider.Factory {

    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        require(modelClass.isAssignableFrom(MainViewModel::class.java)) {
            "Unknown ViewModel class: ${modelClass.name}"
        }
        return MainViewModel(container) as T
    }
}
