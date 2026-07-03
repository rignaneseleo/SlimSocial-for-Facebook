package it.rignanese.leo.slim.data

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.core.Preferences
import io.kotest.matchers.collections.shouldHaveSize
import io.kotest.matchers.shouldBe
import it.rignanese.leo.slim.domain.NamedSnippet
import it.rignanese.leo.slim.domain.Settings
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir
import java.io.File

class SettingsRepositoryTest {

    @TempDir
    lateinit var tmp: File

    private lateinit var scope: CoroutineScope
    private lateinit var ds: DataStore<Preferences>
    private lateinit var repo: SettingsRepository

    @BeforeEach
    fun setUp() {
        scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        ds = PreferenceDataStoreFactory.create(
            scope = scope,
            produceFile = { File(tmp, "test.preferences_pb") },
        )
        repo = SettingsRepository(ds)
    }

    @AfterEach
    fun tearDown() {
        scope.cancel()
    }

    @Test
    fun `empty store returns Settings DEFAULT`() {
        runBlocking {
            val settings = repo.settings.first()
            settings shouldBe Settings.DEFAULT
            // Spot-check the four legacy TRUE keys
            settings.features.enableMessenger shouldBe true
            settings.features.hideAds shouldBe true
            settings.style.fixedBar shouldBe true
            settings.style.hideMessengerSidebar shouldBe true
        }
    }

    @Test
    fun `round-trips mutations across feature, style, permissions, webview, privacy`() {
        runBlocking {
            repo.update {
                it.copy(
                    features = it.features.copy(
                        enableMessenger = false,
                        hideAds = false,
                        recentFirst = true,
                        useMbasic = true,
                    ),
                    style = it.style.copy(
                        darkTheme = true,
                        fixedBar = false,
                        hideStories = true,
                        centerText = true,
                        addSpace = true,
                        hideMessengerSidebar = false,
                    ),
                    permissions = it.permissions.copy(
                        gps = true, camera = true, photo = true, photos = true,
                    ),
                    webView = it.webView.copy(
                        customUserAgent = "Mozilla/5.0 SlimTest",
                        customProxyEnabled = true,
                        customProxyHost = "127.0.0.1",
                        customProxyPort = "8080",
                    ),
                    privacy = it.privacy.copy(
                        sentryEnabled = false,
                        debugMode = true,
                        customJsAcknowledged = true,
                    ),
                )
            }
            val out = repo.settings.first()
            out.features.enableMessenger shouldBe false
            out.features.hideAds shouldBe false
            out.features.recentFirst shouldBe true
            out.features.useMbasic shouldBe true
            out.style.darkTheme shouldBe true
            out.style.fixedBar shouldBe false
            out.style.hideStories shouldBe true
            out.style.centerText shouldBe true
            out.style.addSpace shouldBe true
            out.style.hideMessengerSidebar shouldBe false
            out.permissions.gps shouldBe true
            out.permissions.camera shouldBe true
            out.permissions.photo shouldBe true
            out.permissions.photos shouldBe true
            out.webView.customUserAgent shouldBe "Mozilla/5.0 SlimTest"
            out.webView.customProxyEnabled shouldBe true
            out.webView.customProxyHost shouldBe "127.0.0.1"
            out.webView.customProxyPort shouldBe "8080"
            out.privacy.sentryEnabled shouldBe false
            out.privacy.debugMode shouldBe true
            out.privacy.customJsAcknowledged shouldBe true
        }
    }

    @Test
    fun `round-trips legacy custom CSS and JS as single NamedSnippet`() {
        runBlocking {
            repo.update {
                it.copy(
                    customization = it.customization.copy(
                        cssEntries = listOf(
                            NamedSnippet(
                                id = LEGACY_SNIPPET_ID,
                                name = LEGACY_SNIPPET_NAME,
                                code = "body { color: red }",
                                updatedAt = 0L,
                            ),
                        ),
                        jsEntries = listOf(
                            NamedSnippet(
                                id = LEGACY_SNIPPET_ID,
                                name = LEGACY_SNIPPET_NAME,
                                code = "console.log('hi')",
                                updatedAt = 0L,
                            ),
                        ),
                        activeCssIds = setOf(LEGACY_SNIPPET_ID),
                        activeJsIds = emptySet(),
                    ),
                )
            }
            val out = repo.settings.first()
            out.customization.cssEntries shouldHaveSize 1
            out.customization.cssEntries.first().code shouldBe "body { color: red }"
            out.customization.activeCssIds shouldBe setOf(LEGACY_SNIPPET_ID)
            out.customization.jsEntries shouldHaveSize 1
            out.customization.jsEntries.first().code shouldBe "console.log('hi')"
            // JS not in active set → activeJsIds empty
            out.customization.activeJsIds shouldBe emptySet()
        }
    }

    @Test
    fun `null customUserAgent persists as disabled flag`() {
        runBlocking {
            // First enable a UA…
            repo.update { it.copy(webView = it.webView.copy(customUserAgent = "X")) }
            repo.settings.first().webView.customUserAgent shouldBe "X"
            // …then null it out
            repo.update { it.copy(webView = it.webView.copy(customUserAgent = null)) }
            repo.settings.first().webView.customUserAgent shouldBe null
        }
    }

    @Test
    fun `two consecutive updates preserve both mutations`() {
        runBlocking {
            repo.update { it.copy(features = it.features.copy(recentFirst = true)) }
            repo.update { it.copy(style = it.style.copy(darkTheme = true)) }
            val out = repo.settings.first()
            out.features.recentFirst shouldBe true
            out.style.darkTheme shouldBe true
        }
    }

    @Test
    fun `selectedTheme defaults to null, round-trips a value, and clears back to null`() {
        runBlocking {
            repo.settings.first().style.selectedTheme shouldBe null

            repo.update { it.copy(style = it.style.copy(selectedTheme = "theme_amoled")) }
            repo.settings.first().style.selectedTheme shouldBe "theme_amoled"

            repo.update { it.copy(style = it.style.copy(selectedTheme = null)) }
            repo.settings.first().style.selectedTheme shouldBe null
        }
    }
}
