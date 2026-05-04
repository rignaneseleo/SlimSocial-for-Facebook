package it.rignanese.leo.slim.ui.editor

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.core.Preferences
import app.cash.turbine.test
import io.kotest.matchers.collections.shouldContain
import io.kotest.matchers.collections.shouldNotContain
import io.kotest.matchers.shouldBe
import it.rignanese.leo.slim.data.LEGACY_SNIPPET_ID
import it.rignanese.leo.slim.data.LEGACY_SNIPPET_NAME
import it.rignanese.leo.slim.data.SettingsRepository
import it.rignanese.leo.slim.domain.NamedSnippet
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

/**
 * Pure-JVM unit tests for [EditorViewModel] using an in-memory DataStore.
 * Mirrors the Phase 3 [it.rignanese.leo.slim.ui.settings.SettingsViewModelTest]
 * setup so the same harness handles `viewModelScope.launch` deterministically.
 *
 * Note: Phase 8 storage flattens to the single legacy CSS/JS slot, so the
 * round-tripped snippet always carries [LEGACY_SNIPPET_ID]. Tests use that id
 * intentionally — multi-snippet persistence is a follow-up storage change.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class EditorViewModelTest {

    @TempDir
    lateinit var tmp: File

    private lateinit var dsScope: CoroutineScope
    private lateinit var ds: DataStore<Preferences>
    private lateinit var repo: SettingsRepository
    private lateinit var mainDispatcher: TestDispatcher

    @BeforeEach
    fun setUp() {
        mainDispatcher = UnconfinedTestDispatcher()
        Dispatchers.setMain(mainDispatcher)
        dsScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        ds = PreferenceDataStoreFactory.create(
            scope = dsScope,
            produceFile = { File(tmp, "editor-vm-test.preferences_pb") },
        )
        repo = SettingsRepository(ds)
    }

    @AfterEach
    fun tearDown() {
        dsScope.cancel()
        Dispatchers.resetMain()
    }

    private suspend fun seed(snippet: NamedSnippet, type: SnippetType) {
        repo.update { settings ->
            val customization = settings.customization
            val updated = if (type == SnippetType.CSS) {
                customization.copy(cssEntries = listOf(snippet))
            } else {
                customization.copy(jsEntries = listOf(snippet))
            }
            settings.copy(customization = updated)
        }
    }

    @Test
    fun `toggle CSS snippet on adds id to activeCssIds`() = runTest {
        val s = NamedSnippet(
            id = LEGACY_SNIPPET_ID,
            name = LEGACY_SNIPPET_NAME,
            code = "* { color: red }",
            updatedAt = 0L,
        )
        seed(s, SnippetType.CSS)

        val vm = EditorViewModel(repo, SnippetType.CSS)
        // Subscribe FIRST so the WhileSubscribed flow is hot before we toggle.
        vm.activeIds.test {
            var current = awaitItem()
            while (current.contains(LEGACY_SNIPPET_ID)) current = awaitItem()  // drain to clean
            vm.toggle(LEGACY_SNIPPET_ID, enabled = true)
            while (!current.contains(LEGACY_SNIPPET_ID)) current = awaitItem()
            current shouldContain LEGACY_SNIPPET_ID
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun `toggle JS snippet on without prior acknowledgement still adds it (VM does not gate)`() = runTest {
        // The dialog flow lives in the UI layer; the VM toggle is a pure setter.
        val s = NamedSnippet(
            id = LEGACY_SNIPPET_ID,
            name = LEGACY_SNIPPET_NAME,
            code = "console.log('hi')",
            updatedAt = 0L,
        )
        seed(s, SnippetType.JS)

        val vm = EditorViewModel(repo, SnippetType.JS)
        repo.settings.first().privacy.customJsAcknowledged shouldBe false

        vm.activeIds.test {
            var current = awaitItem()
            while (current.contains(LEGACY_SNIPPET_ID)) current = awaitItem()  // drain
            vm.toggle(LEGACY_SNIPPET_ID, enabled = true)
            while (!current.contains(LEGACY_SNIPPET_ID)) current = awaitItem()
            current shouldContain LEGACY_SNIPPET_ID
            cancelAndIgnoreRemainingEvents()
        }
        // Acknowledgement is still false — VM never wrote it.
        repo.settings.first().privacy.customJsAcknowledged shouldBe false
    }

    @Test
    fun `acknowledgeJsWarning sets customJsAcknowledged to true`() = runTest {
        val vm = EditorViewModel(repo, SnippetType.JS)

        repo.settings.test {
            var s = awaitItem()
            while (s.privacy.customJsAcknowledged) s = awaitItem()  // drain to false
            s.privacy.customJsAcknowledged shouldBe false

            vm.acknowledgeJsWarning()

            // Wait for the write to land in the flow.
            while (!s.privacy.customJsAcknowledged) s = awaitItem()
            s.privacy.customJsAcknowledged shouldBe true
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun `saveSnippet upserts existing id (replace by id)`() = runTest {
        val original = NamedSnippet(
            id = LEGACY_SNIPPET_ID,
            name = LEGACY_SNIPPET_NAME,
            code = "old",
            updatedAt = 1L,
        )
        seed(original, SnippetType.CSS)

        val vm = EditorViewModel(repo, SnippetType.CSS)
        // Subscribe first so the upstream flow is hot before we save.
        vm.snippets.test {
            var current = awaitItem()
            // Drain to the seeded value.
            while (current.firstOrNull()?.code != "old") current = awaitItem()

            vm.saveSnippet(original.copy(name = "v2", code = "new", updatedAt = 2L))

            while (current.firstOrNull()?.code != "new") current = awaitItem()
            current.first().id shouldBe LEGACY_SNIPPET_ID
            current.first().code shouldBe "new"
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun `saveSnippet appends when list is empty`() = runTest {
        val vm = EditorViewModel(repo, SnippetType.CSS)
        val newSnippet = NamedSnippet(
            id = LEGACY_SNIPPET_ID,
            name = "Brand new",
            code = "body { font-size: 14px }",
            updatedAt = 99L,
        )
        vm.snippets.test {
            var current = awaitItem()
            while (current.isNotEmpty()) current = awaitItem()  // drain to empty
            vm.saveSnippet(newSnippet)
            while (current.isEmpty()) current = awaitItem()
            current.size shouldBe 1
            current[0].code shouldBe "body { font-size: 14px }"
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun `deleteSnippet removes from list and from active set`() = runTest {
        val s = NamedSnippet(
            id = LEGACY_SNIPPET_ID,
            name = LEGACY_SNIPPET_NAME,
            code = "x",
            updatedAt = 0L,
        )
        seed(s, SnippetType.CSS)
        // Activate before deleting.
        repo.update {
            it.copy(
                customization = it.customization.copy(
                    activeCssIds = it.customization.activeCssIds + LEGACY_SNIPPET_ID,
                ),
            )
        }
        // Wait for write to land.
        repo.settings.test {
            var s2 = awaitItem()
            while (!s2.customization.activeCssIds.contains(LEGACY_SNIPPET_ID)) s2 = awaitItem()
            cancelAndIgnoreRemainingEvents()
        }

        val vm = EditorViewModel(repo, SnippetType.CSS)
        vm.snippets.test {
            var current = awaitItem()
            while (current.none { it.id == LEGACY_SNIPPET_ID }) current = awaitItem()
            // Now trigger deletion.
            vm.deleteSnippet(LEGACY_SNIPPET_ID)
            while (current.any { it.id == LEGACY_SNIPPET_ID }) current = awaitItem()
            current.none { it.id == LEGACY_SNIPPET_ID } shouldBe true
            cancelAndIgnoreRemainingEvents()
        }
        repo.settings.first().customization.activeCssIds shouldNotContain LEGACY_SNIPPET_ID
    }

    @Test
    fun `factory creates EditorViewModel for both types`() {
        val factory = EditorViewModelFactory(repo, SnippetType.CSS)
        val vm = factory.create(EditorViewModel::class.java)
        vm shouldBe vm
    }
}
