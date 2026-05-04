package it.rignanese.leo.slim

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.core.Preferences
import app.cash.turbine.test
import kotlin.time.Duration.Companion.seconds
import io.kotest.matchers.shouldBe
import it.rignanese.leo.slim.data.SettingsRepository
import it.rignanese.leo.slim.domain.FbConstants
import it.rignanese.leo.slim.domain.HomeUrlBuilder
import it.rignanese.leo.slim.domain.InjectionComposer
import it.rignanese.leo.slim.domain.UserAgentResolver
import it.rignanese.leo.slim.rules.RuleRegistry
import it.rignanese.leo.slim.webview.CookieConfigurator
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.TestDispatcher
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir
import java.io.File

@OptIn(ExperimentalCoroutinesApi::class)
class MainViewModelTest {

    @TempDir
    lateinit var tmp: File

    private lateinit var dsScope: CoroutineScope
    private lateinit var ds: DataStore<Preferences>
    private lateinit var repo: SettingsRepository
    private lateinit var mainDispatcher: TestDispatcher

    @BeforeEach
    fun setUp() {
        // viewModelScope dispatches on Dispatchers.Main; install a test dispatcher
        // so launches in onRenderGone/handleDeeplink resolve under runTest.
        mainDispatcher = UnconfinedTestDispatcher()
        Dispatchers.setMain(mainDispatcher)

        dsScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        ds = PreferenceDataStoreFactory.create(
            scope = dsScope,
            produceFile = { File(tmp, "test.preferences_pb") },
        )
        repo = SettingsRepository(ds)
    }

    @AfterEach
    fun tearDown() {
        dsScope.cancel()
        Dispatchers.resetMain()
    }

    /**
     * In-test cookie configurator. The production class talks to
     * `CookieManager.getInstance()` which requires a WebView runtime; the
     * unit-test JVM does not have one. We override [flush] to a no-op so the
     * VM can still be exercised without Robolectric.
     */
    private class NoopCookieConfigurator : CookieConfigurator() {
        override fun flush() = Unit
    }

    private fun newVm(): MainViewModel = MainViewModel(
        settingsRepository = repo,
        homeUrlBuilder = HomeUrlBuilder(),
        userAgentResolver = UserAgentResolver(),
        injectionComposer = InjectionComposer(),
        ruleRegistry = RuleRegistry(),
        cookieConfigurator = NoopCookieConfigurator(),
    )

    // ---------------------------------------------------------------------
    // homeUrl flow
    // ---------------------------------------------------------------------

    @Test
    fun `homeUrl emits TOUCH+default when settings are default`() = runTest {
        val vm = newVm()
        vm.homeUrl.test(timeout = 30.seconds) {
            // The seed value matches the DataStore-mapped value for default
            // settings; we just observe the first stable emission.
            awaitItem() shouldBe FbConstants.URL_TOUCH + FbConstants.SUFFIX_DEFAULT
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun `homeUrl switches to MBASIC when useMbasic toggled`() = runTest {
        val vm = newVm()
        vm.homeUrl.test(timeout = 30.seconds) {
            // Drain initial value(s) until we see the seeded TOUCH URL.
            var current = awaitItem()
            while (current != FbConstants.URL_TOUCH + FbConstants.SUFFIX_DEFAULT) {
                current = awaitItem()
            }
            repo.update { it.copy(features = it.features.copy(useMbasic = true)) }
            current = awaitItem()
            while (!current.startsWith(FbConstants.URL_MBASIC)) current = awaitItem()
            current shouldBe FbConstants.URL_MBASIC + FbConstants.SUFFIX_DEFAULT
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun `homeUrl switches to recent suffix when recentFirst toggled`() = runTest {
        val vm = newVm()
        vm.homeUrl.test(timeout = 30.seconds) {
            var current = awaitItem()
            while (current != FbConstants.URL_TOUCH + FbConstants.SUFFIX_DEFAULT) {
                current = awaitItem()
            }
            repo.update { it.copy(features = it.features.copy(recentFirst = true)) }
            current = awaitItem()
            while (!current.endsWith(FbConstants.SUFFIX_RECENT)) current = awaitItem()
            current shouldBe FbConstants.URL_TOUCH + FbConstants.SUFFIX_RECENT
            cancelAndIgnoreRemainingEvents()
        }
    }

    // ---------------------------------------------------------------------
    // userAgent flow
    // ---------------------------------------------------------------------

    @Test
    fun `userAgent starts as Firefox UA`() = runTest {
        val vm = newVm()
        vm.userAgent.test(timeout = 30.seconds) {
            var current = awaitItem()
            while (current != UserAgentResolver.UA_FIREFOX) current = awaitItem()
            current shouldBe UserAgentResolver.UA_FIREFOX
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun `userAgent switches to Opera Mini when useMbasic toggled`() = runTest {
        val vm = newVm()
        vm.userAgent.test(timeout = 30.seconds) {
            var current = awaitItem()
            while (current != UserAgentResolver.UA_FIREFOX) current = awaitItem()
            repo.update { it.copy(features = it.features.copy(useMbasic = true)) }
            current = awaitItem()
            while (current != UserAgentResolver.UA_OPERA_MINI) current = awaitItem()
            current shouldBe UserAgentResolver.UA_OPERA_MINI
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun `userAgent returns custom UA when configured`() = runTest {
        val vm = newVm()
        val custom = "Mozilla/5.0 SlimTest"
        vm.userAgent.test(timeout = 30.seconds) {
            var current = awaitItem()
            while (current != UserAgentResolver.UA_FIREFOX) current = awaitItem()
            repo.update { it.copy(webView = it.webView.copy(customUserAgent = custom)) }
            current = awaitItem()
            while (current != custom) current = awaitItem()
            current shouldBe custom
            cancelAndIgnoreRemainingEvents()
        }
    }

    // ---------------------------------------------------------------------
    // renderGone
    // ---------------------------------------------------------------------

    @Test
    fun `renderGone emits the didCrash flag`() = runTest {
        val vm = newVm()
        vm.renderGone.test(timeout = 30.seconds) {
            vm.onRenderGone(true)
            awaitItem() shouldBe true
            cancelAndIgnoreRemainingEvents()
        }
    }

    // ---------------------------------------------------------------------
    // composeInjection
    // ---------------------------------------------------------------------

    @Test
    fun `composeInjection produces non-empty CSS for default settings on FB host`() = runTest {
        val vm = newVm()
        // Allow the StateFlow to seed from DataStore before composing.
        vm.settings.first()
        val payload = vm.composeInjection("https://www.facebook.com/")
        // Defaults enable `fixedBar`, `hideMessengerSidebar`, and `hideAds` —
        // the FixedBar and HideMessengerSidebar rules emit CSS on FB hosts.
        (payload.css.isNotEmpty()) shouldBe true
    }

    // ---------------------------------------------------------------------
    // handleDeeplink
    // ---------------------------------------------------------------------

    @Test
    fun `handleDeeplink emits the URL on deeplinkUrl`() = runTest {
        val vm = newVm()
        vm.deeplinkUrl.test(timeout = 30.seconds) {
            vm.handleDeeplink("https://m.facebook.com/")
            awaitItem() shouldBe "https://m.facebook.com/"
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun `flushCookies does not throw with no-op configurator`() = runTest {
        val vm = newVm()
        vm.flushCookies()
    }
}
