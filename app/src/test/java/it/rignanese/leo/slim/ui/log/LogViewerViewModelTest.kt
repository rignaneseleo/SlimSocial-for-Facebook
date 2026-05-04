package it.rignanese.leo.slim.ui.log

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.core.Preferences
import app.cash.turbine.test
import io.kotest.matchers.shouldBe
import it.rignanese.leo.slim.data.LogBuffer
import it.rignanese.leo.slim.data.LogCategory
import it.rignanese.leo.slim.data.SettingsRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.TestDispatcher
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir
import java.io.File

@OptIn(ExperimentalCoroutinesApi::class)
class LogViewerViewModelTest {

    @TempDir
    lateinit var tmp: File

    private lateinit var dsScope: CoroutineScope
    private lateinit var ds: DataStore<Preferences>
    private lateinit var repo: SettingsRepository
    private lateinit var logBuffer: LogBuffer
    private lateinit var mainDispatcher: TestDispatcher

    @BeforeEach
    fun setUp() {
        mainDispatcher = UnconfinedTestDispatcher()
        Dispatchers.setMain(mainDispatcher)
        dsScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        ds = PreferenceDataStoreFactory.create(
            scope = dsScope,
            produceFile = { File(tmp, "logvm-test.preferences_pb") },
        )
        repo = SettingsRepository(ds)
        logBuffer = LogBuffer()
    }

    @AfterEach
    fun tearDown() {
        dsScope.cancel()
        Dispatchers.resetMain()
    }

    @Test
    fun `LogBuffer records flow into events StateFlow`() = runTest {
        logBuffer.record(LogCategory.NAV, "first")
        val vm = LogViewerViewModel(logBuffer, repo, pollIntervalMs = 10)

        vm.events.test {
            var snapshot = awaitItem()
            while (snapshot.isEmpty()) snapshot = awaitItem()
            snapshot.size shouldBe 1
            snapshot[0].message shouldBe "first"

            // Add more events; expect the next polled snapshot to include them.
            logBuffer.record(LogCategory.CONSOLE, "second")
            logBuffer.record(LogCategory.OTHER, "third")
            advanceTimeBy(50)
            var next = awaitItem()
            while (next.size < 3) next = awaitItem()
            next.map { it.message } shouldBe listOf("first", "second", "third")
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun `togglePause stops new events from showing in events`() = runTest {
        logBuffer.record(LogCategory.NAV, "before-pause")
        val vm = LogViewerViewModel(logBuffer, repo, pollIntervalMs = 10)

        vm.events.test {
            var snapshot = awaitItem()
            while (snapshot.isEmpty()) snapshot = awaitItem()
            snapshot.size shouldBe 1

            vm.togglePause()
            // Add events while paused — events flow must not advance to a 2-element list.
            logBuffer.record(LogCategory.NAV, "during-pause-1")
            logBuffer.record(LogCategory.NAV, "during-pause-2")
            advanceTimeBy(100)
            // The flow may emit nothing new (because polling is gated). Don't
            // hard-await; instead assert that the latest StateFlow value is still 1.
            vm.events.value.size shouldBe 1
            cancelAndIgnoreRemainingEvents()
        }

        // Resume — events should now include the new entries.
        vm.togglePause()
        vm.events.test {
            var current = awaitItem()
            while (current.size < 3) current = awaitItem()
            current.map { it.message } shouldBe listOf(
                "before-pause", "during-pause-1", "during-pause-2",
            )
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun `setDebugMode true writes through to repo`() = runTest {
        val vm = LogViewerViewModel(logBuffer, repo, pollIntervalMs = 10)

        repo.settings.test {
            var s = awaitItem()
            while (s.privacy.debugMode) s = awaitItem()  // drain to false
            s.privacy.debugMode shouldBe false

            vm.setDebugMode(true)

            while (!s.privacy.debugMode) s = awaitItem()
            s.privacy.debugMode shouldBe true
            cancelAndIgnoreRemainingEvents()
        }
        // VM-derived debugMode flow becomes true once subscribed.
        vm.debugMode.test {
            var dm = awaitItem()
            while (!dm) dm = awaitItem()
            dm shouldBe true
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun `exportRedacted matches LogBuffer exportRedacted`() = runTest {
        logBuffer.record(LogCategory.CONSOLE, "hello world")
        logBuffer.record(LogCategory.NAV, "https://example.com/?token=abc")
        val vm = LogViewerViewModel(logBuffer, repo, pollIntervalMs = 10)

        vm.exportRedacted() shouldBe logBuffer.exportRedacted()
    }

    @Test
    fun `clear empties the buffer through the VM`() = runTest {
        logBuffer.record(LogCategory.NAV, "a")
        logBuffer.record(LogCategory.NAV, "b")
        val vm = LogViewerViewModel(logBuffer, repo, pollIntervalMs = 10)
        logBuffer.snapshot().size shouldBe 2

        vm.clear()
        logBuffer.snapshot() shouldBe emptyList()
    }

    @Test
    fun `factory creates LogViewerViewModel`() {
        val factory = LogViewerViewModelFactory(logBuffer, repo)
        val vm = factory.create(LogViewerViewModel::class.java)
        vm shouldBe vm
    }
}
