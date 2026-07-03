package it.rignanese.leo.slim.platform

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import io.kotest.matchers.shouldBe
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.joinAll
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir
import java.io.File

class PlayBillingProEntitlementTest {

    @TempDir
    lateinit var tmp: File

    private lateinit var dsScope: CoroutineScope
    private lateinit var ds: DataStore<Preferences>
    private val entitlementScopes = mutableListOf<CoroutineScope>()

    /** Fixed "now" so grace-window math is deterministic. */
    private val now = 1_750_000_000_000L
    private val day = 24L * 60 * 60 * 1000

    @BeforeEach
    fun setUp() {
        dsScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        ds = PreferenceDataStoreFactory.create(
            scope = dsScope,
            produceFile = { File(tmp, "test.preferences_pb") },
        )
    }

    @AfterEach
    fun tearDown() {
        entitlementScopes.forEach { it.cancel() }
        entitlementScopes.clear()
        dsScope.cancel()
    }

    /** Configurable in-test connector: succeeds with [productIds] or fails. */
    private class FakeConnector(
        var productIds: List<String> = emptyList(),
        var fail: Boolean = false,
    ) : BillingConnector {
        override suspend fun queryActiveSubscriptionProductIds(): Result<List<String>> =
            if (fail) Result.failure(IllegalStateException("offline"))
            else Result.success(productIds)
    }

    /**
     * Constructs the entitlement on a real dispatcher and joins the init job
     * (cache seed + background refresh), so assertions observe the settled
     * post-startup state. DataStore runs on real IO threads, so virtual-time
     * schedulers can't be used here.
     */
    private fun newEntitlement(
        connector: BillingConnector,
        nowMs: Long = now,
    ): PlayBillingProEntitlement {
        val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        entitlementScopes += scope
        val entitlement = PlayBillingProEntitlement(
            dataStore = ds,
            connector = connector,
            scope = scope,
            clock = { nowMs },
        )
        runBlocking { scope.coroutineContext[Job]!!.children.toList().joinAll() }
        return entitlement
    }

    // ------------------------------------------------------------------
    // Entitlement mapping
    // ------------------------------------------------------------------

    @Test
    fun `each support tier grants PRO`() {
        for (tier in SupportSubscriptions.all) {
            val entitlement = newEntitlement(FakeConnector(listOf(tier)))
            entitlement.isPro.value shouldBe true
        }
    }

    @Test
    fun `non-support products do not grant PRO`() {
        val entitlement = newEntitlement(FakeConnector(listOf("some_other_sub")))
        entitlement.isPro.value shouldBe false
    }

    @Test
    fun `no purchases means no PRO`() {
        val entitlement = newEntitlement(FakeConnector(emptyList()))
        entitlement.isPro.value shouldBe false
    }

    @Test
    fun `support tier among other products grants PRO`() {
        val entitlement = newEntitlement(
            FakeConnector(listOf("unrelated", SupportSubscriptions.TIER_2)),
        )
        entitlement.isPro.value shouldBe true
    }

    // ------------------------------------------------------------------
    // Cache write-through
    // ------------------------------------------------------------------

    @Test
    fun `successful verification caches the state and timestamp`() {
        val entitlement = newEntitlement(FakeConnector(listOf(SupportSubscriptions.TIER_1)))
        entitlement.isPro.value shouldBe true

        runBlocking {
            val prefs = ds.data.first()
            prefs[PlayBillingProEntitlement.KEY_PRO_ACTIVE] shouldBe true
            prefs[PlayBillingProEntitlement.KEY_PRO_CACHED_AT] shouldBe now
        }
    }

    @Test
    fun `successful verification can revoke a cached PRO`() {
        runBlocking {
            ds.edit {
                it[PlayBillingProEntitlement.KEY_PRO_ACTIVE] = true
                it[PlayBillingProEntitlement.KEY_PRO_CACHED_AT] = now - day
            }
        }
        // Billing reachable and reports no active subscription → PRO revoked.
        val entitlement = newEntitlement(FakeConnector(emptyList()))
        entitlement.isPro.value shouldBe false
        runBlocking {
            ds.data.first()[PlayBillingProEntitlement.KEY_PRO_ACTIVE] shouldBe false
        }
    }

    // ------------------------------------------------------------------
    // Offline grace window
    // ------------------------------------------------------------------

    @Test
    fun `billing failure keeps cached PRO inside the grace window`() {
        runBlocking {
            ds.edit {
                it[PlayBillingProEntitlement.KEY_PRO_ACTIVE] = true
                it[PlayBillingProEntitlement.KEY_PRO_CACHED_AT] = now - 29 * day
            }
        }
        val entitlement = newEntitlement(FakeConnector(fail = true))
        entitlement.isPro.value shouldBe true
    }

    @Test
    fun `billing failure past the grace window drops PRO`() {
        runBlocking {
            ds.edit {
                it[PlayBillingProEntitlement.KEY_PRO_ACTIVE] = true
                it[PlayBillingProEntitlement.KEY_PRO_CACHED_AT] = now - 31 * day
            }
        }
        val entitlement = newEntitlement(FakeConnector(fail = true))
        entitlement.isPro.value shouldBe false
    }

    @Test
    fun `billing failure with no cache means no PRO`() {
        val entitlement = newEntitlement(FakeConnector(fail = true))
        entitlement.isPro.value shouldBe false
    }

    // ------------------------------------------------------------------
    // refresh() after purchase
    // ------------------------------------------------------------------

    @Test
    fun `refresh after a purchase flips isPro to true`() {
        val connector = FakeConnector(emptyList())
        val entitlement = newEntitlement(connector)
        entitlement.isPro.value shouldBe false

        connector.productIds = listOf(SupportSubscriptions.TIER_3)
        runBlocking { entitlement.refresh() }
        entitlement.isPro.value shouldBe true
    }
}
