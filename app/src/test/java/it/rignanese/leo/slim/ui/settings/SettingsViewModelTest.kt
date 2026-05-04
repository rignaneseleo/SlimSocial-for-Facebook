package it.rignanese.leo.slim.ui.settings

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.core.Preferences
import app.cash.turbine.test
import io.kotest.matchers.shouldBe
import it.rignanese.leo.slim.data.SettingsRepository
import it.rignanese.leo.slim.domain.Settings
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
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

/**
 * Pure-JVM unit tests for [SettingsViewModel] using an in-memory DataStore — no
 * Robolectric required because Preferences DataStore writes to a regular file
 * (here: [tmp]).
 *
 * Pattern matches the Phase 3 [it.rignanese.leo.slim.MainViewModelTest] setup.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class SettingsViewModelTest {

    @TempDir
    lateinit var tmp: File

    private lateinit var dsScope: CoroutineScope
    private lateinit var ds: DataStore<Preferences>
    private lateinit var repo: SettingsRepository
    private lateinit var mainDispatcher: TestDispatcher

    @BeforeEach
    fun setUp() {
        // viewModelScope dispatches on Dispatchers.Main; use an unconfined test
        // dispatcher so update() launches resolve eagerly within runTest.
        mainDispatcher = UnconfinedTestDispatcher()
        Dispatchers.setMain(mainDispatcher)

        dsScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        ds = PreferenceDataStoreFactory.create(
            scope = dsScope,
            produceFile = { File(tmp, "settings-vm-test.preferences_pb") },
        )
        repo = SettingsRepository(ds)
    }

    @AfterEach
    fun tearDown() {
        dsScope.cancel()
        Dispatchers.resetMain()
    }

    private fun newVm(): SettingsViewModel = SettingsViewModel(repo)

    @Test
    fun `initial settings emit defaults from repository`() = runTest {
        val vm = newVm()
        vm.settings.test {
            // First emission is the seed (Settings.DEFAULT). Subsequent emissions
            // come from DataStore, which for an empty file also resolves to the
            // mapped defaults — both have hideAds = true.
            var emitted = awaitItem()
            // Drain until we observe the DataStore-mapped value (may equal the seed
            // identity-wise depending on subscription timing).
            while (emitted.features.hideAds.not() && emitted == Settings.DEFAULT) {
                emitted = awaitItem()
            }
            emitted.features.hideAds shouldBe true
            emitted.features.enableMessenger shouldBe true
            emitted.style.fixedBar shouldBe true
            emitted.style.hideMessengerSidebar shouldBe true
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun `update writes through to repository`() = runTest {
        val vm = newVm()
        vm.settings.test {
            // Drain to a stable initial value.
            var current = awaitItem()
            while (current.features.hideAds.not()) current = awaitItem()

            vm.update { it.copy(features = it.features.copy(hideAds = false)) }

            current = awaitItem()
            while (current.features.hideAds) current = awaitItem()
            current.features.hideAds shouldBe false
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun `update preserves unrelated fields`() = runTest {
        val vm = newVm()
        vm.settings.test {
            var current = awaitItem()
            while (current.features.hideAds.not()) current = awaitItem()

            // Toggle two unrelated fields in sequence.
            vm.update { it.copy(features = it.features.copy(recentFirst = true)) }
            current = awaitItem()
            while (current.features.recentFirst.not()) current = awaitItem()

            vm.update { it.copy(style = it.style.copy(darkTheme = true)) }
            current = awaitItem()
            while (current.style.darkTheme.not()) current = awaitItem()

            // Both fields should now be set; defaults preserved everywhere else.
            current.features.recentFirst shouldBe true
            current.style.darkTheme shouldBe true
            current.features.hideAds shouldBe true     // legacy default preserved
            current.features.enableMessenger shouldBe true
            current.style.fixedBar shouldBe true
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun `update can change webView custom user agent and proxy in one transform`() = runTest {
        val vm = newVm()
        vm.settings.test {
            var current = awaitItem()
            while (current.features.hideAds.not()) current = awaitItem()

            vm.update {
                it.copy(
                    webView = it.webView.copy(
                        customUserAgent = "Mozilla/5.0 SlimTest",
                        customProxyEnabled = true,
                        customProxyHost = "127.0.0.1",
                        customProxyPort = "8080",
                    ),
                )
            }
            current = awaitItem()
            while (current.webView.customUserAgent != "Mozilla/5.0 SlimTest") {
                current = awaitItem()
            }
            current.webView.customUserAgent shouldBe "Mozilla/5.0 SlimTest"
            current.webView.customProxyEnabled shouldBe true
            current.webView.customProxyHost shouldBe "127.0.0.1"
            current.webView.customProxyPort shouldBe "8080"
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun `factory creates SettingsViewModel from repository`() {
        val factory = SettingsViewModelFactory(repo)
        val vm = factory.create(SettingsViewModel::class.java)
        vm shouldBe vm  // smoke: instance was constructed without error
    }
}
