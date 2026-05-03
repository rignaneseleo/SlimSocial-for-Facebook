package it.rignanese.leo.slim.data

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.core.Preferences
import io.kotest.matchers.collections.shouldHaveSize
import io.kotest.matchers.shouldBe
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

class FlutterMigratorTest {

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

    private fun copyFixtureInto(baseDir: File): File {
        val sharedPrefsDir = File(baseDir, "shared_prefs").apply { mkdirs() }
        val target = File(sharedPrefsDir, "FlutterSharedPreferences.xml")
        val resource = checkNotNull(
            this::class.java.classLoader!!.getResourceAsStream("migration/FlutterSharedPreferences.xml"),
        ) { "fixture missing on classpath" }
        target.outputStream().use { resource.copyTo(it) }
        return target
    }

    @Test
    fun `migrates all 23 legacy keys into Settings`() {
        runBlocking {
            val baseDir = File(tmp, "app").apply { mkdirs() }
            copyFixtureInto(baseDir)

            val migrator = FlutterMigrator.forBaseDir(baseDir, ds)
            val report = migrator.migrateOnce()

            report.error shouldBe null
            // Fixture contains all 23 legacy keys (22 toggles/strings + custom_useragent string).
            report.keysFound shouldBe 23
            report.keysMissing shouldHaveSize 0

            val settings = repo.settings.first()
            settings.features.enableMessenger shouldBe false
            settings.features.hideAds shouldBe false
            settings.features.recentFirst shouldBe true
            settings.features.useMbasic shouldBe true
            settings.permissions.gps shouldBe true
            settings.permissions.camera shouldBe true
            settings.permissions.photo shouldBe true
            settings.permissions.photos shouldBe true
            settings.style.darkTheme shouldBe true
            settings.style.fixedBar shouldBe false
            settings.style.hideStories shouldBe true
            settings.style.centerText shouldBe true
            settings.style.addSpace shouldBe true
            settings.style.hideMessengerSidebar shouldBe false
            settings.webView.customUserAgent shouldBe "Mozilla/5.0 LegacyImported"
            settings.webView.customProxyEnabled shouldBe true
            settings.webView.customProxyHost shouldBe "10.0.0.1"
            settings.webView.customProxyPort shouldBe "8888"
        }
    }

    @Test
    fun `legacy custom CSS becomes a single NamedSnippet with id legacy when enabled`() {
        runBlocking {
            val baseDir = File(tmp, "app").apply { mkdirs() }
            copyFixtureInto(baseDir)
            FlutterMigrator.forBaseDir(baseDir, ds).migrateOnce()

            val custom = repo.settings.first().customization
            custom.cssEntries shouldHaveSize 1
            custom.cssEntries.first().id shouldBe LEGACY_SNIPPET_ID
            custom.cssEntries.first().name shouldBe LEGACY_SNIPPET_NAME
            custom.cssEntries.first().code shouldBe "body { background: red }"
            custom.activeCssIds shouldBe setOf(LEGACY_SNIPPET_ID)

            custom.jsEntries shouldHaveSize 1
            custom.jsEntries.first().code shouldBe "console.log('legacy')"
            custom.activeJsIds shouldBe setOf(LEGACY_SNIPPET_ID)
        }
    }

    @Test
    fun `missing source file yields empty report and no error`() {
        runBlocking {
            val baseDir = File(tmp, "app").apply { mkdirs() }
            val report = FlutterMigrator.forBaseDir(baseDir, ds).migrateOnce()
            report.keysFound shouldBe 0
            report.keysMissing shouldBe emptyList()
            report.error shouldBe null
        }
    }

    @Test
    fun `migrateOnce is idempotent — second call sees migrated marker and no-ops`() {
        runBlocking {
            val baseDir = File(tmp, "app").apply { mkdirs() }
            val source = copyFixtureInto(baseDir)

            val migrator = FlutterMigrator.forBaseDir(baseDir, ds)
            val first = migrator.migrateOnce()
            first.keysFound shouldBe 23
            // Source renamed to .migrated marker
            source.exists() shouldBe false
            File(source.parentFile, source.name + ".migrated").exists() shouldBe true

            // Subsequent run: no source, no work, no error.
            val second = migrator.migrateOnce()
            second.keysFound shouldBe 0
            second.keysMissing shouldBe emptyList()
            second.error shouldBe null
        }
    }
}
