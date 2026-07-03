# WS1: PRO Entitlement + Facebook Page Themes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Any active `support_yearly_*` subscription unlocks PRO, which gates a new set of Facebook page themes (AMOLED, 3 accent colors, compact mode) injected as CSS through the existing rule pipeline — with all PRO code compiled out of the fdroid flavor.

**Architecture:** A `ProEntitlement` interface joins `CrashReporter`/`DonationLauncher` on the flavor-split `Platform` aggregator; the full flavor backs it with Play Billing (`queryPurchasesAsync(SUBS)`) plus a DataStore cache with a 30-day offline grace window, while fdroid returns constant `false`. Theme rules are ordinary `InjectionRule`s living in `src/full/`, surfaced to the main source set through a flavor-split `ThemeRuleSource` (same top-level-function pattern as `providePlatform`); `RuleRegistry.activeRules(settings, isPro)` appends the selected theme after the free dark rules (theme wins on conflicting selectors, user snippets stay last). All PRO UI (theme picker, "Get PRO" reframe, PRO badge) lives in `src/full/` — the fdroid build keeps its current donation screen and shows zero paywall.

**Tech Stack:** Kotlin, Jetpack Compose (M3), Play Billing `billing-ktx 7.+` (already a `fullImplementation` dep — no gradle changes), DataStore Preferences, JUnit 5 + Kotest + Turbine + MockK.

**Baseline:** branch `feature/pro-entitlement-themes` off `claude/optimistic-jones-0b0a45` (0426c9d).

---

## Design decisions locked by the spec (do not reopen)

- Any active `support_yearly_1..4` ⇒ PRO. No new Play products. No server-side receipt validation.
- Entitlement cache keys `pro_active` / `pro_cached_at` in the existing settings DataStore; 30-day grace.
- fdroid: constant-false entitlement; theme rules, picker, and Get PRO CTAs are **not compiled** into the fdroid APK (CI dex grep for `io.sentry|com.android.billingclient|play.review` must stay green — we add no new proprietary imports outside `src/full/`).
- Theme selection: single `selectedTheme: String?` in DataStore; themes compose with free dark mode, theme wins on conflicts (achieved by rule order + `!important`); free tier untouched.
- Donate screen reframed as "Get PRO" **in the full flavor only**, via resource overrides in `src/full/res/values/strings.xml` (safe: the donate strings exist only in the default `values/strings.xml`, no locale files override them).

## Flavor-split mechanics used throughout

The codebase's established pattern (see `providePlatform` in `src/full/.../platform/PlatformProvider.kt` and `src/fdroid/.../PlatformProvider.kt`): declare the same **top-level function** in both flavor source sets; `src/main` calls it; Kotlin resolves the flavor's definition at build time. We use this three times:

| Function | main caller | full | fdroid |
|---|---|---|---|
| `providePlatform(context, dataStore, scope)` | `AppContainer` | `FullPlatform` (+ `PlayBillingProEntitlement`) | `FdroidPlatform` (+ `NoProEntitlement`) |
| `provideThemeRuleSource()` | `AppContainer` | `FullThemeRuleSource` (real catalog) | returns `NoThemeRuleSource` (defined in main) |
| `ProSettingsSection(...)` / `NavGraphBuilder.proDestinations(...)` | `SettingsScreen` / `SettingsNavGraph` | Themes row + badge / `"themes"` route | empty bodies |

Because both flavors compile on every commit, any task that touches a shared interface updates **both** flavor implementations in the same commit.

## File map

**Create — `src/main`:**
- `app/src/main/java/it/rignanese/leo/slim/rules/ThemeRuleSource.kt` — `ThemeDescriptor`, `ThemeRuleSource`, `NoThemeRuleSource`

**Create — `src/full`:**
- `.../platform/BillingConnector.kt` — `BillingConnector` interface + `PlayBillingConnector` (real Play Billing query)
- `.../platform/PlayBillingProEntitlement.kt` — entitlement mapping + cache + grace window
- `.../rules/ThemeIds.kt`, `.../rules/AmoledThemeRule.kt`, `.../rules/AccentThemeRule.kt`, `.../rules/CompactThemeRule.kt`, `.../rules/ThemeRuleProvider.kt`
- `.../ui/settings/ProSettingsSection.kt`, `.../ui/settings/ThemePickerScreen.kt`, `.../ui/settings/ProNavGraph.kt`
- `app/src/full/res/values/strings.xml` — donate→PRO overrides + theme strings

**Create — `src/fdroid`:**
- `.../rules/ThemeRuleProvider.kt`, `.../ui/settings/ProSettingsSection.kt`, `.../ui/settings/ProNavGraph.kt` — no-op counterparts (`NoProEntitlement` goes in the existing `PlatformProvider.kt`)

**Modify — `src/main`:**
- `platform/Platform.kt` (+`ProEntitlement`, +`Platform.proEntitlement`)
- `domain/Settings.kt` (`StyleToggles.selectedTheme`)
- `data/SettingsKeys.kt` (`SELECTED_THEME`), `data/SettingsRepository.kt` (mapping)
- `rules/RuleRegistry.kt` (ctor + `isPro` param)
- `MainViewModel.kt` (inject `ProEntitlement`)
- `app/AppContainer.kt` (`appScope`, new `providePlatform` args, `themeRuleSource`)
- `ui/settings/Navigation.kt`, `ui/settings/SettingsScreen.kt`, `ui/settings/DonateScreen.kt`

**Modify — flavors:** both `PlatformProvider.kt` files.

**Tests:** `testFull/.../platform/PlayBillingProEntitlementTest.kt`, `testFull/.../platform/PlayBillingConnectorTest.kt`, `testFull/.../rules/{AmoledThemeRuleTest,AccentThemeRuleTest,CompactThemeRuleTest,FullThemeRuleSourceTest}.kt`, `testFdroid/.../platform/NoProEntitlementTest.kt`, `testFdroid/.../rules/FdroidThemeRuleSourceTest.kt`, plus modified `test/.../rules/RuleRegistryTest.kt`, `test/.../data/SettingsRepositoryTest.kt`, `test/.../MainViewModelTest.kt`.

**Docs:** `TESTING.md` (manual purchase/restore matrix + test-count row).

**Verification gate (every task):** the four commands from the workstream contract —
```bash
./gradlew testFullDebugUnitTest testFdroidDebugUnitTest   # per-task: at least the affected variant
./gradlew lintFullDebug lintFdroidDebug                    # final task, plus spot checks
```

---

### Task 1: `ProEntitlement` interface + full-flavor Play Billing implementation

**Files:**
- Modify: `app/src/main/java/it/rignanese/leo/slim/platform/Platform.kt`
- Create: `app/src/full/java/it/rignanese/leo/slim/platform/BillingConnector.kt`
- Create: `app/src/full/java/it/rignanese/leo/slim/platform/PlayBillingProEntitlement.kt`
- Test: `app/src/testFull/java/it/rignanese/leo/slim/platform/PlayBillingProEntitlementTest.kt`
- Test: `app/src/testFull/java/it/rignanese/leo/slim/platform/PlayBillingConnectorTest.kt`

Note: this task does **not** touch the `Platform` aggregator interface, so fdroid keeps compiling; wiring happens in Task 2.

- [ ] **Step 1: Add the `ProEntitlement` interface to main**

In `app/src/main/java/it/rignanese/leo/slim/platform/Platform.kt`, add imports and the interface (before the `Platform` interface):

```kotlin
import kotlinx.coroutines.flow.StateFlow
```

```kotlin
/**
 * PRO entitlement abstraction. Any active `support_yearly_*` subscription
 * (see [SupportSubscriptions]) makes the user PRO.
 *
 * `full` flavor backs this with Play Billing plus a DataStore cache that
 * tolerates up to 30 days offline; `fdroid` is constant `false` and all
 * PRO-gated UI is compiled out of that flavor.
 */
interface ProEntitlement {
    /** Reactive PRO state; seeded from cache at startup, re-verified in background. */
    val isPro: StateFlow<Boolean>

    /** Re-query the billing backend and update [isPro] plus the cached state. */
    suspend fun refresh()
}
```

- [ ] **Step 2: Write the failing entitlement tests**

Create `app/src/testFull/java/it/rignanese/leo/slim/platform/PlayBillingProEntitlementTest.kt`:

```kotlin
package it.rignanese.leo.slim.platform

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import io.kotest.matchers.shouldBe
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir
import java.io.File

@OptIn(ExperimentalCoroutinesApi::class)
class PlayBillingProEntitlementTest {

    @TempDir
    lateinit var tmp: File

    private lateinit var dsScope: CoroutineScope
    private lateinit var ds: DataStore<Preferences>

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

    private fun TestScopeEntitlement(
        connector: BillingConnector,
        scope: CoroutineScope,
        nowMs: Long = now,
    ) = PlayBillingProEntitlement(
        dataStore = ds,
        connector = connector,
        scope = scope,
        clock = { nowMs },
    )

    // ------------------------------------------------------------------
    // Entitlement mapping
    // ------------------------------------------------------------------

    @Test
    fun `each support tier grants PRO`() = runTest {
        for (tier in SupportSubscriptions.all) {
            val entitlement = TestScopeEntitlement(FakeConnector(listOf(tier)), this)
            advanceUntilIdle()
            entitlement.isPro.value shouldBe true
        }
    }

    @Test
    fun `non-support products do not grant PRO`() = runTest {
        val entitlement = TestScopeEntitlement(FakeConnector(listOf("some_other_sub")), this)
        advanceUntilIdle()
        entitlement.isPro.value shouldBe false
    }

    @Test
    fun `no purchases means no PRO`() = runTest {
        val entitlement = TestScopeEntitlement(FakeConnector(emptyList()), this)
        advanceUntilIdle()
        entitlement.isPro.value shouldBe false
    }

    @Test
    fun `support tier among other products grants PRO`() = runTest {
        val entitlement = TestScopeEntitlement(
            FakeConnector(listOf("unrelated", SupportSubscriptions.TIER_2)),
            this,
        )
        advanceUntilIdle()
        entitlement.isPro.value shouldBe true
    }

    // ------------------------------------------------------------------
    // Cache write-through
    // ------------------------------------------------------------------

    @Test
    fun `successful verification caches the state and timestamp`() = runTest {
        val entitlement = TestScopeEntitlement(FakeConnector(listOf(SupportSubscriptions.TIER_1)), this)
        advanceUntilIdle()
        entitlement.isPro.value shouldBe true

        val prefs = ds.data.first()
        prefs[PlayBillingProEntitlement.KEY_PRO_ACTIVE] shouldBe true
        prefs[PlayBillingProEntitlement.KEY_PRO_CACHED_AT] shouldBe now
    }

    @Test
    fun `successful verification can revoke a cached PRO`() = runTest {
        ds.edit {
            it[PlayBillingProEntitlement.KEY_PRO_ACTIVE] = true
            it[PlayBillingProEntitlement.KEY_PRO_CACHED_AT] = now - day
        }
        // Billing reachable and reports no active subscription → PRO revoked.
        val entitlement = TestScopeEntitlement(FakeConnector(emptyList()), this)
        advanceUntilIdle()
        entitlement.isPro.value shouldBe false
        ds.data.first()[PlayBillingProEntitlement.KEY_PRO_ACTIVE] shouldBe false
    }

    // ------------------------------------------------------------------
    // Offline grace window
    // ------------------------------------------------------------------

    @Test
    fun `billing failure keeps cached PRO inside the grace window`() = runTest {
        ds.edit {
            it[PlayBillingProEntitlement.KEY_PRO_ACTIVE] = true
            it[PlayBillingProEntitlement.KEY_PRO_CACHED_AT] = now - 29 * day
        }
        val entitlement = TestScopeEntitlement(FakeConnector(fail = true), this)
        advanceUntilIdle()
        entitlement.isPro.value shouldBe true
    }

    @Test
    fun `billing failure past the grace window drops PRO`() = runTest {
        ds.edit {
            it[PlayBillingProEntitlement.KEY_PRO_ACTIVE] = true
            it[PlayBillingProEntitlement.KEY_PRO_CACHED_AT] = now - 31 * day
        }
        val entitlement = TestScopeEntitlement(FakeConnector(fail = true), this)
        advanceUntilIdle()
        entitlement.isPro.value shouldBe false
    }

    @Test
    fun `billing failure with no cache means no PRO`() = runTest {
        val entitlement = TestScopeEntitlement(FakeConnector(fail = true), this)
        advanceUntilIdle()
        entitlement.isPro.value shouldBe false
    }

    // ------------------------------------------------------------------
    // refresh() after purchase
    // ------------------------------------------------------------------

    @Test
    fun `refresh after a purchase flips isPro to true`() = runTest {
        val connector = FakeConnector(emptyList())
        val entitlement = TestScopeEntitlement(connector, this)
        advanceUntilIdle()
        entitlement.isPro.value shouldBe false

        connector.productIds = listOf(SupportSubscriptions.TIER_3)
        entitlement.refresh()
        entitlement.isPro.value shouldBe true
    }
}
```

- [ ] **Step 3: Run the test to verify it fails to compile**

Run: `./gradlew :app:compileFullDebugUnitTestKotlin 2>&1 | tail -20`
Expected: FAIL — `unresolved reference: BillingConnector` / `PlayBillingProEntitlement`.

- [ ] **Step 4: Implement `BillingConnector`**

Create `app/src/full/java/it/rignanese/leo/slim/platform/BillingConnector.kt`:

```kotlin
package it.rignanese.leo.slim.platform

import android.content.Context
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.QueryPurchasesParams
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume

/**
 * Thin seam over the Play Billing "query current subscriptions" call so
 * [PlayBillingProEntitlement]'s mapping/cache logic is unit-testable with a
 * fake. Only the `full` flavor has an implementation talking to Play.
 */
interface BillingConnector {
    /**
     * Product ids of all subscriptions currently in the PURCHASED state for
     * this Google account, or a failure when Play is unreachable (offline,
     * no Play services, connection error).
     */
    suspend fun queryActiveSubscriptionProductIds(): Result<List<String>>
}

/**
 * Real Play Billing connector. One short-lived [BillingClient] per query —
 * the entitlement refreshes rarely (app start + after purchase), so holding
 * a persistent connection isn't worth the lifecycle complexity. Mirrors the
 * connection dance in [PlayBillingDonationLauncher].
 */
class PlayBillingConnector(private val context: Context) : BillingConnector {

    override suspend fun queryActiveSubscriptionProductIds(): Result<List<String>> =
        suspendCancellableCoroutine { cont ->
            lateinit var client: BillingClient
            client = BillingClient.newBuilder(context)
                .enablePendingPurchases(
                    PendingPurchasesParams.newBuilder()
                        .enableOneTimeProducts()
                        .enablePrepaidPlans()
                        .build()
                )
                // Purchase updates are handled by PlayBillingDonationLauncher;
                // this client only queries, but the SDK requires a listener.
                .setListener { _, _ -> }
                .build()

            cont.invokeOnCancellation {
                runCatching { client.endConnection() }
            }

            client.startConnection(object : BillingClientStateListener {
                override fun onBillingSetupFinished(result: BillingResult) {
                    if (result.responseCode != BillingClient.BillingResponseCode.OK) {
                        if (cont.isActive) {
                            cont.resume(
                                Result.failure(IllegalStateException("connection ${result.responseCode}"))
                            )
                        }
                        return
                    }
                    val params = QueryPurchasesParams.newBuilder()
                        .setProductType(BillingClient.ProductType.SUBS)
                        .build()
                    client.queryPurchasesAsync(params) { queryResult, purchases ->
                        runCatching { client.endConnection() }
                        if (!cont.isActive) return@queryPurchasesAsync
                        if (queryResult.responseCode == BillingClient.BillingResponseCode.OK) {
                            val ids = purchases
                                .filter { it.purchaseState == Purchase.PurchaseState.PURCHASED }
                                .flatMap { it.products }
                            cont.resume(Result.success(ids))
                        } else {
                            cont.resume(
                                Result.failure(IllegalStateException("query ${queryResult.responseCode}"))
                            )
                        }
                    }
                }

                override fun onBillingServiceDisconnected() {
                    // SDK schedules its own reconnect; nothing to do here.
                }
            })
        }
}
```

- [ ] **Step 5: Implement `PlayBillingProEntitlement`**

Create `app/src/full/java/it/rignanese/leo/slim/platform/PlayBillingProEntitlement.kt`:

```kotlin
package it.rignanese.leo.slim.platform

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

/**
 * Play Billing-backed [ProEntitlement] for the `full` flavor.
 *
 * Any active [SupportSubscriptions] subscription ⇒ PRO (spec §3.1). The last
 * verified state is cached in DataStore ([KEY_PRO_ACTIVE]/[KEY_PRO_CACHED_AT]):
 * on construction the cached value is published immediately and billing
 * re-verifies in the background. When billing is unreachable, the cache is
 * honoured for [GRACE_WINDOW_MS] (30 days) after its last successful
 * verification, then PRO lapses until Play answers again.
 *
 * No server-side receipt validation by design — the app is open source and a
 * determined user can patch the APK regardless (spec §3.1).
 */
class PlayBillingProEntitlement(
    private val dataStore: DataStore<Preferences>,
    private val connector: BillingConnector,
    scope: CoroutineScope,
    private val clock: () -> Long = System::currentTimeMillis,
) : ProEntitlement {

    private val _isPro = MutableStateFlow(false)
    override val isPro: StateFlow<Boolean> = _isPro.asStateFlow()

    init {
        scope.launch {
            _isPro.value = cachedEntitlement()
            refresh()
        }
    }

    override suspend fun refresh() {
        connector.queryActiveSubscriptionProductIds().fold(
            onSuccess = { productIds ->
                val active = productIds.any { it in SupportSubscriptions.all }
                dataStore.edit { prefs ->
                    prefs[KEY_PRO_ACTIVE] = active
                    prefs[KEY_PRO_CACHED_AT] = clock()
                }
                _isPro.value = active
            },
            onFailure = {
                // Billing unreachable — fall back to the cached state within grace.
                _isPro.value = cachedEntitlement()
            },
        )
    }

    private suspend fun cachedEntitlement(): Boolean {
        val prefs = dataStore.data.first()
        val cachedAt = prefs[KEY_PRO_CACHED_AT] ?: return false
        if (clock() - cachedAt > GRACE_WINDOW_MS) return false
        return prefs[KEY_PRO_ACTIVE] ?: false
    }

    companion object {
        val KEY_PRO_ACTIVE = booleanPreferencesKey("pro_active")
        val KEY_PRO_CACHED_AT = longPreferencesKey("pro_cached_at")

        /** 30 days — annual subs tolerate long offline stretches without enabling freeloading. */
        const val GRACE_WINDOW_MS: Long = 30L * 24 * 60 * 60 * 1000
    }
}
```

- [ ] **Step 6: Add the connector smoke test**

Create `app/src/testFull/java/it/rignanese/leo/slim/platform/PlayBillingConnectorTest.kt` (same rationale as `PlayBillingDonationLauncherTest` — a real connection needs a Play binder):

```kotlin
package it.rignanese.leo.slim.platform

import android.content.Context
import io.mockk.mockk
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertDoesNotThrow

/**
 * Smoke test only — a real BillingClient connection needs an attached Play
 * Services binder which the JVM doesn't have. Deeper coverage is the manual
 * purchase/restore matrix in TESTING.md; the mapping/cache logic is covered
 * by [PlayBillingProEntitlementTest] via [BillingConnector] fakes.
 */
class PlayBillingConnectorTest {

    @Test
    fun `can be constructed`() {
        val context: Context = mockk(relaxed = true)
        assertDoesNotThrow { PlayBillingConnector(context) }
    }
}
```

- [ ] **Step 7: Run the full-flavor tests**

Run: `./gradlew testFullDebugUnitTest --tests "it.rignanese.leo.slim.platform.*" 2>&1 | tail -15`
Expected: PASS (new tests green, existing platform tests untouched).

- [ ] **Step 8: Run the fdroid tests to prove nothing broke**

Run: `./gradlew testFdroidDebugUnitTest 2>&1 | tail -5`
Expected: PASS (fdroid never references the new classes).

- [ ] **Step 9: Commit**

```bash
git add app/src/main/java/it/rignanese/leo/slim/platform/Platform.kt \
        app/src/full/java/it/rignanese/leo/slim/platform/BillingConnector.kt \
        app/src/full/java/it/rignanese/leo/slim/platform/PlayBillingProEntitlement.kt \
        app/src/testFull/java/it/rignanese/leo/slim/platform/PlayBillingProEntitlementTest.kt \
        app/src/testFull/java/it/rignanese/leo/slim/platform/PlayBillingConnectorTest.kt
git commit -m "feat(pro): ProEntitlement interface + Play Billing implementation with 30-day offline grace"
```

---

### Task 2: Wire `ProEntitlement` into `Platform` + fdroid no-op

**Files:**
- Modify: `app/src/main/java/it/rignanese/leo/slim/platform/Platform.kt` (aggregator)
- Modify: `app/src/full/java/it/rignanese/leo/slim/platform/PlatformProvider.kt`
- Modify: `app/src/fdroid/java/it/rignanese/leo/slim/platform/PlatformProvider.kt`
- Modify: `app/src/main/java/it/rignanese/leo/slim/app/AppContainer.kt`
- Test: `app/src/testFdroid/java/it/rignanese/leo/slim/platform/NoProEntitlementTest.kt`

- [ ] **Step 1: Write the failing fdroid test**

Create `app/src/testFdroid/java/it/rignanese/leo/slim/platform/NoProEntitlementTest.kt`:

```kotlin
package it.rignanese.leo.slim.platform

import io.kotest.matchers.shouldBe
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Test

/**
 * The F-Droid build has no billing, therefore no PRO: the entitlement is a
 * hard constant `false`. All PRO UI is compiled out of this flavor, but the
 * constant also defends the shared gating logic (RuleRegistry) in depth.
 */
class NoProEntitlementTest {

    @Test
    fun `isPro is false`() {
        NoProEntitlement.isPro.value shouldBe false
    }

    @Test
    fun `refresh does not throw and stays false`() {
        runBlocking { NoProEntitlement.refresh() }
        NoProEntitlement.isPro.value shouldBe false
    }
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `./gradlew :app:compileFdroidDebugUnitTestKotlin 2>&1 | tail -10`
Expected: FAIL — `unresolved reference: NoProEntitlement`.

- [ ] **Step 3: Extend the `Platform` aggregator (main)**

In `app/src/main/java/it/rignanese/leo/slim/platform/Platform.kt`, extend the aggregator (the interface's KDoc already describes the flavor-split factory; update the factory description to mention the new parameters):

```kotlin
/**
 * Aggregator of platform-flavored services. Constructed via the
 * `providePlatform(Context, DataStore<Preferences>, CoroutineScope)` top-level
 * factory function provided by each flavor source set (`src/full` and
 * `src/fdroid`). The DataStore and scope are used by the `full` flavor's
 * [ProEntitlement] for its offline cache and background re-verification.
 */
interface Platform {
    val crashReporter: CrashReporter
    val donationLauncher: DonationLauncher
    val reviewLauncher: ReviewLauncher
    val proEntitlement: ProEntitlement
}
```

- [ ] **Step 4: Update the full-flavor provider**

Replace `app/src/full/java/it/rignanese/leo/slim/platform/PlatformProvider.kt` content:

```kotlin
package it.rignanese.leo.slim.platform

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import kotlinx.coroutines.CoroutineScope

/**
 * Full (Play Store) flavor entry point. The same top-level function is
 * declared in the `fdroid` source set; Kotlin resolves the correct definition
 * at flavor build time.
 */
fun providePlatform(
    context: Context,
    dataStore: DataStore<Preferences>,
    scope: CoroutineScope,
): Platform = FullPlatform(context.applicationContext, dataStore, scope)

internal class FullPlatform(
    private val context: Context,
    dataStore: DataStore<Preferences>,
    scope: CoroutineScope,
) : Platform {
    override val crashReporter: CrashReporter = SentryCrashReporter()
    override val donationLauncher: DonationLauncher = PlayBillingDonationLauncher(context)
    override val reviewLauncher: ReviewLauncher = PlayReviewLauncher()
    override val proEntitlement: ProEntitlement =
        PlayBillingProEntitlement(dataStore, PlayBillingConnector(context), scope)
}
```

- [ ] **Step 5: Update the fdroid provider**

In `app/src/fdroid/java/it/rignanese/leo/slim/platform/PlatformProvider.kt`, update the factory + `FdroidPlatform` and append `NoProEntitlement`:

```kotlin
// New/changed imports at the top of the file:
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
```

```kotlin
fun providePlatform(
    context: Context,
    dataStore: DataStore<Preferences>,
    scope: CoroutineScope,
): Platform = FdroidPlatform()

internal class FdroidPlatform : Platform {
    override val crashReporter: CrashReporter = NoOpCrashReporter()
    override val donationLauncher: DonationLauncher = ExternalDonationLauncher()
    override val reviewLauncher: ReviewLauncher = NoOpReviewLauncher()
    override val proEntitlement: ProEntitlement = NoProEntitlement
}
```

Append at the end of the file:

```kotlin
/**
 * F-Droid has no billing, therefore no PRO: constant `false`. PRO UI is
 * compiled out of this flavor entirely; this object only exists so shared
 * code (e.g. rule gating) can consume the same [ProEntitlement] interface.
 */
internal object NoProEntitlement : ProEntitlement {
    private val state = MutableStateFlow(false)
    override val isPro: StateFlow<Boolean> = state.asStateFlow()
    override suspend fun refresh() {}
}
```

- [ ] **Step 6: Wire the new factory signature in `AppContainer`**

In `app/src/main/java/it/rignanese/leo/slim/app/AppContainer.kt`, add imports:

```kotlin
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
```

Add an application scope (right after `val dataStore ...`) and update the `platform` property:

```kotlin
    /**
     * Application-lifetime scope for platform background work (entitlement
     * cache seeding + billing re-verification). Never cancelled — it dies
     * with the process, like every other AppContainer singleton.
     */
    val appScope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
```

```kotlin
    val platform: Platform = providePlatform(appContext, dataStore, appScope)
```

- [ ] **Step 7: Run both flavors' tests**

Run: `./gradlew testFullDebugUnitTest testFdroidDebugUnitTest 2>&1 | tail -5`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add app/src/main/java/it/rignanese/leo/slim/platform/Platform.kt \
        app/src/full/java/it/rignanese/leo/slim/platform/PlatformProvider.kt \
        app/src/fdroid/java/it/rignanese/leo/slim/platform/PlatformProvider.kt \
        app/src/main/java/it/rignanese/leo/slim/app/AppContainer.kt \
        app/src/testFdroid/java/it/rignanese/leo/slim/platform/NoProEntitlementTest.kt
git commit -m "feat(pro): expose ProEntitlement on Platform aggregator; fdroid constant-false no-op"
```

---

### Task 3: `selectedTheme` setting (model + DataStore mapping)

**Files:**
- Modify: `app/src/main/java/it/rignanese/leo/slim/domain/Settings.kt`
- Modify: `app/src/main/java/it/rignanese/leo/slim/data/SettingsKeys.kt`
- Modify: `app/src/main/java/it/rignanese/leo/slim/data/SettingsRepository.kt`
- Test: `app/src/test/java/it/rignanese/leo/slim/data/SettingsRepositoryTest.kt`

- [ ] **Step 1: Write the failing round-trip test**

Append to `app/src/test/java/it/rignanese/leo/slim/data/SettingsRepositoryTest.kt`:

```kotlin
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
```

- [ ] **Step 2: Run it to verify it fails**

Run: `./gradlew testFullDebugUnitTest --tests "it.rignanese.leo.slim.data.SettingsRepositoryTest" 2>&1 | tail -10`
Expected: FAIL — `unresolved reference: selectedTheme`.

- [ ] **Step 3: Add the field, key, and mapping**

In `app/src/main/java/it/rignanese/leo/slim/domain/Settings.kt`, extend `StyleToggles` (last field):

```kotlin
data class StyleToggles(
    val darkTheme: Boolean = false,
    val fixedBar: Boolean = true,                  // legacy TRUE
    val hideStories: Boolean = false,
    val centerText: Boolean = false,
    val addSpace: Boolean = false,
    val hideMessengerSidebar: Boolean = true,      // legacy TRUE
    val darkThemeMessenger: Boolean = false,
    val removeMessengerDownload: Boolean = false,
    val removeBrowserNotSupported: Boolean = false,
    val hideAdsAndPeopleYouMayKnow: Boolean = false,
    val fabBtn: Boolean = false,
    val adaptMessenger: Boolean = false,
    /** PRO page theme id (see ThemeRuleSource), or null for no theme. New in WS1, no legacy key. */
    val selectedTheme: String? = null,
)
```

In `app/src/main/java/it/rignanese/leo/slim/data/SettingsKeys.kt`, add below the privacy/debug block (it is **not** added to `LEGACY_NAMES` — no Flutter equivalent):

```kotlin
    // PRO page theme — new in WS1 (PRO + themes), no legacy equivalent
    val SELECTED_THEME = stringPreferencesKey("selected_theme")
```

In `app/src/main/java/it/rignanese/leo/slim/data/SettingsRepository.kt`:

`toSettings()` — inside the `style = StyleToggles(...)` block, after `hideMessengerSidebar = ...`:

```kotlin
        selectedTheme = this[SettingsKeys.SELECTED_THEME],
```

`writeInto()` — after `prefs[SettingsKeys.HIDE_MESSENGER_SIDEBAR] = style.hideMessengerSidebar`:

```kotlin
    if (style.selectedTheme != null) {
        prefs[SettingsKeys.SELECTED_THEME] = style.selectedTheme
    } else {
        prefs.remove(SettingsKeys.SELECTED_THEME)
    }
```

- [ ] **Step 4: Run the data tests**

Run: `./gradlew testFullDebugUnitTest --tests "it.rignanese.leo.slim.data.*" 2>&1 | tail -5`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/src/main/java/it/rignanese/leo/slim/domain/Settings.kt \
        app/src/main/java/it/rignanese/leo/slim/data/SettingsKeys.kt \
        app/src/main/java/it/rignanese/leo/slim/data/SettingsRepository.kt \
        app/src/test/java/it/rignanese/leo/slim/data/SettingsRepositoryTest.kt
git commit -m "feat(pro): selectedTheme setting with DataStore round-trip"
```

---

### Task 4: `ThemeRuleSource` seam + AMOLED theme rule

**Files:**
- Create: `app/src/main/java/it/rignanese/leo/slim/rules/ThemeRuleSource.kt`
- Create: `app/src/full/java/it/rignanese/leo/slim/rules/ThemeIds.kt`
- Create: `app/src/full/java/it/rignanese/leo/slim/rules/AmoledThemeRule.kt`
- Test: `app/src/testFull/java/it/rignanese/leo/slim/rules/AmoledThemeRuleTest.kt`

- [ ] **Step 1: Create the main-source seam (no test — pure declarations)**

Create `app/src/main/java/it/rignanese/leo/slim/rules/ThemeRuleSource.kt`:

```kotlin
package it.rignanese.leo.slim.rules

import it.rignanese.leo.slim.domain.InjectionRule

/**
 * Descriptor of a PRO page theme, consumed by the full-flavor theme picker.
 *
 * @param id stable theme id stored in `Settings.style.selectedTheme`
 * @param nameRes display-name string resource (lives in the flavor's res)
 * @param previewArgb ARGB swatch color shown in the picker preview
 */
data class ThemeDescriptor(
    val id: String,
    val nameRes: Int,
    val previewArgb: Long,
)

/**
 * Flavor-split source of PRO theme rules. The `full` flavor provides the
 * real catalog; `fdroid` returns [NoThemeRuleSource] so no PRO theme code
 * ships on F-Droid. Resolved via the top-level `provideThemeRuleSource()`
 * function declared in each flavor source set — the same pattern as
 * `providePlatform` (see `platform/PlatformProvider.kt` in both flavors).
 */
interface ThemeRuleSource {
    val availableThemes: List<ThemeDescriptor>

    /** The [InjectionRule] for [themeId], or null when the id is unknown. */
    fun ruleFor(themeId: String): InjectionRule?
}

/** Empty source: no themes. Used by `fdroid` and as the [RuleRegistry] default. */
object NoThemeRuleSource : ThemeRuleSource {
    override val availableThemes: List<ThemeDescriptor> = emptyList()
    override fun ruleFor(themeId: String): InjectionRule? = null
}
```

- [ ] **Step 2: Write the failing AMOLED rule test**

Create `app/src/testFull/java/it/rignanese/leo/slim/rules/AmoledThemeRuleTest.kt` (mirrors `DarkThemeRuleTest`'s shape):

```kotlin
package it.rignanese.leo.slim.rules

import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import org.junit.jupiter.api.Test

class AmoledThemeRuleTest {
    private val rule = AmoledThemeRule()

    @Test
    fun `id matches`() {
        rule.id shouldBe ThemeIds.AMOLED
    }

    @Test
    fun `applies on facebook hosts`() {
        rule.cssFor("https://m.facebook.com/home.php")!! shouldContain "#000000"
    }

    @Test
    fun `does not apply on messenger`() {
        rule.cssFor("https://www.messenger.com/inbox") shouldBe null
    }

    @Test
    fun `does not apply on unknown hosts`() {
        rule.cssFor("https://example.com/") shouldBe null
    }

    @Test
    fun `has no JS payload`() {
        rule.jsFor("https://m.facebook.com/") shouldBe null
    }

    @Test
    fun `every declaration is important so the theme wins over the free dark css`() {
        val css = rule.cssFor("https://m.facebook.com/")!!
        val declarations = css.lines().count { it.trim().endsWith(";") }
        val importants = css.lines().count { it.contains("!important") }
        (importants >= declarations) shouldBe true
    }
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `./gradlew :app:compileFullDebugUnitTestKotlin 2>&1 | tail -10`
Expected: FAIL — `unresolved reference: AmoledThemeRule` / `ThemeIds`.

- [ ] **Step 4: Implement `ThemeIds` and `AmoledThemeRule`**

Create `app/src/full/java/it/rignanese/leo/slim/rules/ThemeIds.kt`:

```kotlin
package it.rignanese.leo.slim.rules

/**
 * Stable ids for the PRO page themes, persisted in
 * `Settings.style.selectedTheme`. Never rename a shipped id — users'
 * stored selections reference them.
 */
object ThemeIds {
    const val AMOLED = "theme_amoled"
    const val ACCENT_GREEN = "theme_accent_green"
    const val ACCENT_PURPLE = "theme_accent_purple"
    const val ACCENT_ORANGE = "theme_accent_orange"
    const val COMPACT = "theme_compact"
}
```

Create `app/src/full/java/it/rignanese/leo/slim/rules/AmoledThemeRule.kt`:

```kotlin
package it.rignanese.leo.slim.rules

import it.rignanese.leo.slim.domain.InjectionRule

/**
 * PRO theme: true-black AMOLED variant. Composes after the free
 * [DarkThemeRule] in [RuleRegistry] order, so on shared selectors the
 * later-injected `!important` declarations win the cascade and true black
 * replaces the free theme's translucent grays.
 */
class AmoledThemeRule : InjectionRule {
    override val id: String = ThemeIds.AMOLED

    override fun cssFor(url: String): String? {
        if (!RuleGates.isFbHost(url)) return null
        return CSS
    }

    private companion object {
        val CSS = """
/* SlimSocial PRO — AMOLED black */
* {
    border-color: #111111 !important;
    color: #e4e6eb !important;
    background-color: transparent !important;
}
html, body, body ._li, #root, #page, #viewport, #screen-root {
    background: #000000 !important;
    background-color: #000000 !important;
}
#header, #pagelet_bluebar, ._52z5, .stickyHeaderWrap, ._1kf5 {
    background-color: #000000 !important;
    border-bottom: 1px solid #111111 !important;
}
._4-u2, ._55wo, ._55wm, ._5rgr, .card, .fbNubFlyoutOuter, .uiMenuInner {
    background-color: #000000 !important;
    border-color: #111111 !important;
}
input, textarea, select, td .inputtext {
    background-color: #0a0a0a !important;
    color: #e4e6eb !important;
}
a {
    color: #8ab4f8 !important;
}
"""
    }
}
```

- [ ] **Step 5: Run the test**

Run: `./gradlew testFullDebugUnitTest --tests "it.rignanese.leo.slim.rules.AmoledThemeRuleTest" 2>&1 | tail -5`
Expected: PASS.

- [ ] **Step 6: Compile fdroid to prove the seam doesn't leak**

Run: `./gradlew :app:compileFdroidDebugKotlin 2>&1 | tail -5`
Expected: BUILD SUCCESSFUL (fdroid sees only `ThemeRuleSource.kt` in main).

- [ ] **Step 7: Commit**

```bash
git add app/src/main/java/it/rignanese/leo/slim/rules/ThemeRuleSource.kt \
        app/src/full/java/it/rignanese/leo/slim/rules/ThemeIds.kt \
        app/src/full/java/it/rignanese/leo/slim/rules/AmoledThemeRule.kt \
        app/src/testFull/java/it/rignanese/leo/slim/rules/AmoledThemeRuleTest.kt
git commit -m "feat(themes): ThemeRuleSource seam + AMOLED black theme rule (full flavor)"
```

---

### Task 5: Accent + compact theme rules

**Files:**
- Create: `app/src/full/java/it/rignanese/leo/slim/rules/AccentThemeRule.kt`
- Create: `app/src/full/java/it/rignanese/leo/slim/rules/CompactThemeRule.kt`
- Test: `app/src/testFull/java/it/rignanese/leo/slim/rules/AccentThemeRuleTest.kt`
- Test: `app/src/testFull/java/it/rignanese/leo/slim/rules/CompactThemeRuleTest.kt`

- [ ] **Step 1: Write the failing accent test**

Create `app/src/testFull/java/it/rignanese/leo/slim/rules/AccentThemeRuleTest.kt`:

```kotlin
package it.rignanese.leo.slim.rules

import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import org.junit.jupiter.api.Test

class AccentThemeRuleTest {
    private val rule = AccentThemeRule(ThemeIds.ACCENT_GREEN, "#1b7f4d")

    @Test
    fun `id matches the constructor argument`() {
        rule.id shouldBe ThemeIds.ACCENT_GREEN
    }

    @Test
    fun `css re-tints the chrome with the accent color`() {
        rule.cssFor("https://m.facebook.com/")!! shouldContain "#1b7f4d"
    }

    @Test
    fun `header content stays readable on the accent background`() {
        // The accent is applied to #header's background AND to link text; a
        // higher-specificity override must keep header links white.
        rule.cssFor("https://m.facebook.com/")!! shouldContain "#header a"
    }

    @Test
    fun `does not apply off facebook`() {
        rule.cssFor("https://example.com/") shouldBe null
        rule.cssFor("https://www.messenger.com/") shouldBe null
    }

    @Test
    fun `each accent variant carries its own color`() {
        AccentThemeRule(ThemeIds.ACCENT_PURPLE, "#7b46b8")
            .cssFor("https://m.facebook.com/")!! shouldContain "#7b46b8"
        AccentThemeRule(ThemeIds.ACCENT_ORANGE, "#d9662a")
            .cssFor("https://m.facebook.com/")!! shouldContain "#d9662a"
    }
}
```

- [ ] **Step 2: Write the failing compact test**

Create `app/src/testFull/java/it/rignanese/leo/slim/rules/CompactThemeRuleTest.kt`:

```kotlin
package it.rignanese.leo.slim.rules

import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import org.junit.jupiter.api.Test

class CompactThemeRuleTest {
    private val rule = CompactThemeRule()

    @Test
    fun `id matches`() {
        rule.id shouldBe ThemeIds.COMPACT
    }

    @Test
    fun `css reduces font size and paddings`() {
        val css = rule.cssFor("https://m.facebook.com/")!!
        css shouldContain "font-size"
        css shouldContain "padding"
    }

    @Test
    fun `does not apply off facebook`() {
        rule.cssFor("https://example.com/") shouldBe null
    }
}
```

- [ ] **Step 3: Run to verify both fail**

Run: `./gradlew :app:compileFullDebugUnitTestKotlin 2>&1 | tail -10`
Expected: FAIL — `unresolved reference: AccentThemeRule` / `CompactThemeRule`.

- [ ] **Step 4: Implement `AccentThemeRule`**

Create `app/src/full/java/it/rignanese/leo/slim/rules/AccentThemeRule.kt`:

```kotlin
package it.rignanese.leo.slim.rules

import it.rignanese.leo.slim.domain.InjectionRule

/**
 * PRO theme: re-tints the Facebook chrome (top bar, links, action buttons,
 * badges) with a single accent color. One class, one instance per shipped
 * variant — see the catalog in `ThemeRuleProvider.kt`.
 */
class AccentThemeRule(
    override val id: String,
    private val accentHex: String,
) : InjectionRule {

    override fun cssFor(url: String): String? {
        if (!RuleGates.isFbHost(url)) return null
        return """
/* SlimSocial PRO — accent theme ($accentHex) */
#header, #pagelet_bluebar, ._52z5, ._1kf5, .stickyHeaderWrap {
    background-color: $accentHex !important;
}
a, ._5fpq, ._52jh, ._4g34 {
    color: $accentHex !important;
}
span._59tg, .jewelItemNew, ._1b1b {
    background-color: $accentHex !important;
}
button[type=submit], ._4jy1, input[type=submit], ._54k8._56bs {
    background-color: $accentHex !important;
    border-color: $accentHex !important;
}
/* Keep header content readable on the accent background. */
#header a, #header ._52jh, #header span {
    color: #ffffff !important;
}
"""
    }
}
```

- [ ] **Step 5: Implement `CompactThemeRule`**

Create `app/src/full/java/it/rignanese/leo/slim/rules/CompactThemeRule.kt`:

```kotlin
package it.rignanese.leo.slim.rules

import it.rignanese.leo.slim.domain.InjectionRule

/**
 * PRO theme: compact mode — smaller base font, tighter paddings and story
 * spacing for information density on small screens.
 */
class CompactThemeRule : InjectionRule {
    override val id: String = ThemeIds.COMPACT

    override fun cssFor(url: String): String? {
        if (!RuleGates.isFbHost(url)) return null
        return CSS
    }

    private companion object {
        val CSS = """
/* SlimSocial PRO — compact mode */
body {
    font-size: 13px !important;
    line-height: 1.25 !important;
}
._55wo, ._55wm, ._4-u2, ._5rgr, .story_body_container {
    padding: 4px 6px !important;
    margin: 0 0 4px 0 !important;
}
._2vxa, ._5rgt, ._5msi {
    font-size: 13px !important;
}
#header, ._52z5 {
    min-height: 36px !important;
}
._4-u8, .item {
    margin-bottom: 4px !important;
}
"""
    }
}
```

- [ ] **Step 6: Run the theme rule tests**

Run: `./gradlew testFullDebugUnitTest --tests "it.rignanese.leo.slim.rules.*" 2>&1 | tail -5`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add app/src/full/java/it/rignanese/leo/slim/rules/AccentThemeRule.kt \
        app/src/full/java/it/rignanese/leo/slim/rules/CompactThemeRule.kt \
        app/src/testFull/java/it/rignanese/leo/slim/rules/AccentThemeRuleTest.kt \
        app/src/testFull/java/it/rignanese/leo/slim/rules/CompactThemeRuleTest.kt
git commit -m "feat(themes): accent color and compact mode theme rules (full flavor)"
```

---

### Task 6: Theme catalog + flavor providers + container wiring

**Files:**
- Create: `app/src/full/java/it/rignanese/leo/slim/rules/ThemeRuleProvider.kt`
- Create: `app/src/full/res/values/strings.xml` (theme names only — donate overrides come in Task 8)
- Create: `app/src/fdroid/java/it/rignanese/leo/slim/rules/ThemeRuleProvider.kt`
- Modify: `app/src/main/java/it/rignanese/leo/slim/app/AppContainer.kt`
- Test: `app/src/testFull/java/it/rignanese/leo/slim/rules/FullThemeRuleSourceTest.kt`
- Test: `app/src/testFdroid/java/it/rignanese/leo/slim/rules/FdroidThemeRuleSourceTest.kt`

- [ ] **Step 1: Write the failing full-flavor catalog test**

Create `app/src/testFull/java/it/rignanese/leo/slim/rules/FullThemeRuleSourceTest.kt`:

```kotlin
package it.rignanese.leo.slim.rules

import io.kotest.matchers.collections.shouldHaveSize
import io.kotest.matchers.nulls.shouldNotBeNull
import io.kotest.matchers.shouldBe
import org.junit.jupiter.api.Test

class FullThemeRuleSourceTest {
    private val source = provideThemeRuleSource()

    @Test
    fun `catalog has five themes with unique ids`() {
        source.availableThemes shouldHaveSize 5
        source.availableThemes.map { it.id }.toSet() shouldHaveSize 5
    }

    @Test
    fun `every descriptor resolves to a rule with a matching id`() {
        for (descriptor in source.availableThemes) {
            val rule = source.ruleFor(descriptor.id).shouldNotBeNull()
            rule.id shouldBe descriptor.id
        }
    }

    @Test
    fun `unknown ids resolve to null`() {
        source.ruleFor("theme_that_does_not_exist") shouldBe null
    }

    @Test
    fun `every theme emits css on facebook and nothing elsewhere`() {
        for (descriptor in source.availableThemes) {
            val rule = source.ruleFor(descriptor.id)!!
            (rule.cssFor("https://m.facebook.com/")!!.isNotBlank()) shouldBe true
            rule.cssFor("https://example.com/") shouldBe null
        }
    }
}
```

- [ ] **Step 2: Write the failing fdroid test**

Create `app/src/testFdroid/java/it/rignanese/leo/slim/rules/FdroidThemeRuleSourceTest.kt`:

```kotlin
package it.rignanese.leo.slim.rules

import io.kotest.matchers.shouldBe
import org.junit.jupiter.api.Test

/**
 * F-Droid ships no PRO themes: the provider returns the empty source, so the
 * picker has nothing to show and the registry can never resolve a theme rule.
 */
class FdroidThemeRuleSourceTest {

    @Test
    fun `provider returns the empty source`() {
        provideThemeRuleSource() shouldBe NoThemeRuleSource
    }

    @Test
    fun `no themes are available and no id resolves`() {
        val source = provideThemeRuleSource()
        source.availableThemes shouldBe emptyList()
        source.ruleFor("theme_amoled") shouldBe null
    }
}
```

- [ ] **Step 3: Run to verify both fail**

Run: `./gradlew :app:compileFullDebugUnitTestKotlin :app:compileFdroidDebugUnitTestKotlin 2>&1 | tail -10`
Expected: FAIL — `unresolved reference: provideThemeRuleSource` in both.

- [ ] **Step 4: Add the theme name strings (full flavor)**

Create `app/src/full/res/values/strings.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- PRO theme names (full flavor only — the picker is compiled out of fdroid) -->
    <string name="theme_amoled">AMOLED black</string>
    <string name="theme_accent_green">Green accent</string>
    <string name="theme_accent_purple">Purple accent</string>
    <string name="theme_accent_orange">Orange accent</string>
    <string name="theme_compact">Compact mode</string>
</resources>
```

- [ ] **Step 5: Implement the full-flavor provider**

Create `app/src/full/java/it/rignanese/leo/slim/rules/ThemeRuleProvider.kt`:

```kotlin
package it.rignanese.leo.slim.rules

import it.rignanese.leo.slim.R
import it.rignanese.leo.slim.domain.InjectionRule

/**
 * Full (Play Store) flavor theme catalog. The same top-level function is
 * declared in the `fdroid` source set (returning [NoThemeRuleSource]);
 * Kotlin resolves the correct definition at flavor build time.
 */
fun provideThemeRuleSource(): ThemeRuleSource = FullThemeRuleSource

internal object FullThemeRuleSource : ThemeRuleSource {

    private val rules: Map<String, InjectionRule> = listOf(
        AmoledThemeRule(),
        AccentThemeRule(ThemeIds.ACCENT_GREEN, "#1b7f4d"),
        AccentThemeRule(ThemeIds.ACCENT_PURPLE, "#7b46b8"),
        AccentThemeRule(ThemeIds.ACCENT_ORANGE, "#d9662a"),
        CompactThemeRule(),
    ).associateBy { it.id }

    override val availableThemes: List<ThemeDescriptor> = listOf(
        ThemeDescriptor(ThemeIds.AMOLED, R.string.theme_amoled, 0xFF000000),
        ThemeDescriptor(ThemeIds.ACCENT_GREEN, R.string.theme_accent_green, 0xFF1B7F4D),
        ThemeDescriptor(ThemeIds.ACCENT_PURPLE, R.string.theme_accent_purple, 0xFF7B46B8),
        ThemeDescriptor(ThemeIds.ACCENT_ORANGE, R.string.theme_accent_orange, 0xFFD9662A),
        ThemeDescriptor(ThemeIds.COMPACT, R.string.theme_compact, 0xFF9AA0A6),
    )

    override fun ruleFor(themeId: String): InjectionRule? = rules[themeId]
}
```

- [ ] **Step 6: Implement the fdroid provider**

Create `app/src/fdroid/java/it/rignanese/leo/slim/rules/ThemeRuleProvider.kt`:

```kotlin
package it.rignanese.leo.slim.rules

/**
 * F-Droid flavor: no PRO themes — the real catalog lives only in `src/full`
 * so no theme code (or dead paywall) ships on F-Droid. Same flavor-split
 * pattern as `providePlatform`.
 */
fun provideThemeRuleSource(): ThemeRuleSource = NoThemeRuleSource
```

- [ ] **Step 7: Expose the source on `AppContainer`**

In `app/src/main/java/it/rignanese/leo/slim/app/AppContainer.kt`, add import `it.rignanese.leo.slim.rules.ThemeRuleSource` and `it.rignanese.leo.slim.rules.provideThemeRuleSource`, then next to `ruleRegistry`:

```kotlin
    /** Flavor-resolved PRO theme catalog (full: real themes; fdroid: empty). */
    val themeRuleSource: ThemeRuleSource = provideThemeRuleSource()
```

(`ruleRegistry` itself changes in Task 7.)

- [ ] **Step 8: Run both flavors' tests**

Run: `./gradlew testFullDebugUnitTest testFdroidDebugUnitTest 2>&1 | tail -5`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add app/src/full/java/it/rignanese/leo/slim/rules/ThemeRuleProvider.kt \
        app/src/full/res/values/strings.xml \
        app/src/fdroid/java/it/rignanese/leo/slim/rules/ThemeRuleProvider.kt \
        app/src/main/java/it/rignanese/leo/slim/app/AppContainer.kt \
        app/src/testFull/java/it/rignanese/leo/slim/rules/FullThemeRuleSourceTest.kt \
        app/src/testFdroid/java/it/rignanese/leo/slim/rules/FdroidThemeRuleSourceTest.kt
git commit -m "feat(themes): flavor-split theme catalog provider; empty on fdroid"
```

---

### Task 7: PRO gating in `RuleRegistry` + `MainViewModel`

**Files:**
- Modify: `app/src/main/java/it/rignanese/leo/slim/rules/RuleRegistry.kt`
- Modify: `app/src/main/java/it/rignanese/leo/slim/MainViewModel.kt`
- Modify: `app/src/main/java/it/rignanese/leo/slim/ui/settings/Navigation.kt` (debug screen's `activeRules` call)
- Test: `app/src/test/java/it/rignanese/leo/slim/rules/RuleRegistryTest.kt`
- Test: `app/src/test/java/it/rignanese/leo/slim/MainViewModelTest.kt`

- [ ] **Step 1: Write the failing registry gating tests**

Append to `app/src/test/java/it/rignanese/leo/slim/rules/RuleRegistryTest.kt` (inside the class), plus the fake at the bottom of the file:

```kotlin
    // ------------------------------------------------------------------
    // PRO theme gating
    // ------------------------------------------------------------------

    private val themedRegistry = RuleRegistry(FakeThemeRuleSource)

    private fun themedSettings(theme: String? = "test_theme") = Settings.DEFAULT.copy(
        style = Settings.DEFAULT.style.copy(darkTheme = true, selectedTheme = theme),
    )

    @Test
    fun `pro user with a selected theme gets the theme rule`() {
        val ids = themedRegistry.activeRules(themedSettings(), isPro = true).map { it.id }
        ids shouldContain "test_theme"
    }

    @Test
    fun `theme rule composes after dark theme and before user custom rules`() {
        val ids = themedRegistry.activeRules(themedSettings(), isPro = true).map { it.id }
        // Later CSS wins on equal-specificity !important conflicts, so the
        // theme must come after the free dark rule; user snippets stay last.
        (ids.indexOf("test_theme") > ids.indexOf("dark_theme")) shouldBe true
        (ids.indexOf("test_theme") < ids.indexOf("user_css")) shouldBe true
    }

    @Test
    fun `non-pro user never gets the theme rule even with a stored selection`() {
        val ids = themedRegistry.activeRules(themedSettings(), isPro = false).map { it.id }
        (ids.contains("test_theme")) shouldBe false
    }

    @Test
    fun `pro user with no selected theme gets no theme rule`() {
        val ids = themedRegistry.activeRules(themedSettings(theme = null), isPro = true).map { it.id }
        (ids.contains("test_theme")) shouldBe false
    }

    @Test
    fun `unknown theme id resolves to no rule`() {
        val ids = themedRegistry.activeRules(themedSettings(theme = "gone"), isPro = true).map { it.id }
        (ids.contains("gone")) shouldBe false
    }

    @Test
    fun `default registry has no theme source and stays theme-free`() {
        val ids = registry.activeRules(themedSettings(), isPro = true).map { it.id }
        (ids.contains("test_theme")) shouldBe false
    }
```

At the bottom of the file (outside the class):

```kotlin
private object FakeThemeRuleSource : ThemeRuleSource {
    override val availableThemes = listOf(ThemeDescriptor("test_theme", 0, 0xFF000000))
    override fun ruleFor(themeId: String): InjectionRule? =
        if (themeId == "test_theme") {
            object : InjectionRule {
                override val id = "test_theme"
                override fun cssFor(url: String) = "/* test theme css */"
            }
        } else {
            null
        }
}
```

Add the needed imports to the test file: `it.rignanese.leo.slim.domain.InjectionRule`.

- [ ] **Step 2: Run to verify it fails**

Run: `./gradlew testFullDebugUnitTest --tests "it.rignanese.leo.slim.rules.RuleRegistryTest" 2>&1 | tail -10`
Expected: FAIL — no `RuleRegistry(ThemeRuleSource)` constructor / no `isPro` parameter.

- [ ] **Step 3: Implement the registry gating**

Replace `app/src/main/java/it/rignanese/leo/slim/rules/RuleRegistry.kt` body:

```kotlin
package it.rignanese.leo.slim.rules

import it.rignanese.leo.slim.domain.InjectionRule
import it.rignanese.leo.slim.domain.Settings

/**
 * Resolves the active set of [InjectionRule]s for the given [Settings].
 * Pure function — no Android imports, no I/O — so it can be unit tested
 * directly on the JVM.
 *
 * PRO page themes come from the flavor-split [themeRuleSource] and apply
 * only when [activeRules] is called with `isPro = true`. The theme rule is
 * appended after the free dark rules — later CSS wins equal-specificity
 * `!important` conflicts, so the theme overrides the free dark mode — and
 * before the user-custom rules, so user snippets keep the last word.
 */
class RuleRegistry(
    private val themeRuleSource: ThemeRuleSource = NoThemeRuleSource,
) {
    fun activeRules(s: Settings, isPro: Boolean = false): List<InjectionRule> = buildList {
        if (s.style.centerText) add(CenterTextRule())
        if (s.style.hideMessengerSidebar) add(HideMessengerSidebarRule())
        if (s.style.addSpace) add(AddSpaceRule())
        if (s.style.hideStories) add(HideStoriesRule())
        if (s.style.fixedBar) add(FixedBarRule())
        if (s.style.removeMessengerDownload) add(RemoveMessengerDownloadRule())
        if (s.style.removeBrowserNotSupported) add(RemoveBrowserNotSupportedRule())
        if (s.style.hideAdsAndPeopleYouMayKnow) add(HideAdsAndPYMKRule())
        if (s.style.fabBtn) add(FabButtonRule())
        if (s.style.adaptMessenger) add(AdaptMessengerRule())
        if (s.style.darkTheme) add(DarkThemeRule())
        if (s.style.darkThemeMessenger) add(DarkThemeMessengerRule())
        if (isPro) {
            s.style.selectedTheme
                ?.let { themeRuleSource.ruleFor(it) }
                ?.let { add(it) }
        }
        if (s.features.hideAds) add(RemoveAdsRule())
        add(UserCustomCssRule(s.customization))
        add(UserCustomJsRule(s.customization))
    }
}
```

- [ ] **Step 4: Run the registry tests**

Run: `./gradlew testFullDebugUnitTest --tests "it.rignanese.leo.slim.rules.RuleRegistryTest" 2>&1 | tail -5`
Expected: PASS (including the four pre-existing tests — the new parameters are defaulted).

- [ ] **Step 5: Write the failing MainViewModel test**

In `app/src/test/java/it/rignanese/leo/slim/MainViewModelTest.kt`:

Add imports:

```kotlin
import it.rignanese.leo.slim.domain.InjectionRule
import it.rignanese.leo.slim.platform.ProEntitlement
import it.rignanese.leo.slim.rules.ThemeDescriptor
import it.rignanese.leo.slim.rules.ThemeRuleSource
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
```

Add fakes (next to `NoopCookieConfigurator`):

```kotlin
    private class FakeProEntitlement(active: Boolean) : ProEntitlement {
        private val state = MutableStateFlow(active)
        override val isPro: StateFlow<Boolean> = state
        override suspend fun refresh() {}
    }

    private object FakeThemeSource : ThemeRuleSource {
        override val availableThemes = listOf(ThemeDescriptor("test_theme", 0, 0xFF000000))
        override fun ruleFor(themeId: String): InjectionRule? =
            if (themeId == "test_theme") {
                object : InjectionRule {
                    override val id = "test_theme"
                    override fun cssFor(url: String) = "/* pro theme marker */"
                }
            } else {
                null
            }
    }
```

Update `newVm()` to:

```kotlin
    private fun newVm(isPro: Boolean = false): MainViewModel = MainViewModel(
        settingsRepository = repo,
        homeUrlBuilder = HomeUrlBuilder(),
        userAgentResolver = UserAgentResolver(),
        injectionComposer = InjectionComposer(),
        ruleRegistry = RuleRegistry(FakeThemeSource),
        cookieConfigurator = NoopCookieConfigurator(),
        proEntitlement = FakeProEntitlement(isPro),
    )
```

Add tests after the existing `composeInjection` test:

```kotlin
    @Test
    fun `composeInjection includes the selected theme for PRO users`() = runBlocking {
        repo.update { it.copy(style = it.style.copy(selectedTheme = "test_theme")) }
        val vm = newVm(isPro = true)
        vm.settings.first { it.style.selectedTheme == "test_theme" }
        val payload = vm.composeInjection("https://m.facebook.com/")
        payload.css.contains("/* pro theme marker */") shouldBe true
    }

    @Test
    fun `composeInjection ignores the selected theme for non-PRO users`() = runBlocking {
        repo.update { it.copy(style = it.style.copy(selectedTheme = "test_theme")) }
        val vm = newVm(isPro = false)
        vm.settings.first { it.style.selectedTheme == "test_theme" }
        val payload = vm.composeInjection("https://m.facebook.com/")
        payload.css.contains("/* pro theme marker */") shouldBe false
    }
```

- [ ] **Step 6: Run to verify it fails**

Run: `./gradlew testFullDebugUnitTest --tests "it.rignanese.leo.slim.MainViewModelTest" 2>&1 | tail -10`
Expected: FAIL — no `proEntitlement` parameter on `MainViewModel`.

- [ ] **Step 7: Inject the entitlement into `MainViewModel`**

In `app/src/main/java/it/rignanese/leo/slim/MainViewModel.kt`:

Add import `it.rignanese.leo.slim.platform.ProEntitlement`. Add the constructor parameter (last position) and wire the secondary constructor:

```kotlin
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
```

Update `composeInjection`:

```kotlin
    fun composeInjection(currentUrl: String): InjectionPayload {
        val rules = ruleRegistry.activeRules(settings.value, isPro = proEntitlement.isPro.value)
        return injectionComposer.compose(rules, currentUrl)
    }
```

- [ ] **Step 8: Update `AppContainer.ruleRegistry` and the debug screen**

`app/src/main/java/it/rignanese/leo/slim/app/AppContainer.kt`:

```kotlin
    val ruleRegistry: RuleRegistry = RuleRegistry(themeRuleSource)
```

(Move/keep `themeRuleSource` declared **before** `ruleRegistry` — property initializers run in declaration order.)

`app/src/main/java/it/rignanese/leo/slim/ui/settings/Navigation.kt`, in the `composable("debug")` block, pass the live entitlement so the debug snapshot shows the theme rule:

```kotlin
        composable("debug") {
            val settings by vm.settings.collectAsStateWithLifecycle()
            val isPro by container.platform.proEntitlement.isPro.collectAsStateWithLifecycle()
            val activeRuleIds = remember(settings, isPro) {
                container.ruleRegistry.activeRules(settings, isPro).map { it.id }
            }
            ...
```

- [ ] **Step 9: Run the full suites for both flavors**

Run: `./gradlew testFullDebugUnitTest testFdroidDebugUnitTest 2>&1 | tail -5`
Expected: PASS.

- [ ] **Step 10: Commit**

```bash
git add app/src/main/java/it/rignanese/leo/slim/rules/RuleRegistry.kt \
        app/src/main/java/it/rignanese/leo/slim/MainViewModel.kt \
        app/src/main/java/it/rignanese/leo/slim/app/AppContainer.kt \
        app/src/main/java/it/rignanese/leo/slim/ui/settings/Navigation.kt \
        app/src/test/java/it/rignanese/leo/slim/rules/RuleRegistryTest.kt \
        app/src/test/java/it/rignanese/leo/slim/MainViewModelTest.kt
git commit -m "feat(pro): gate selected theme on PRO entitlement in rule registry and injection"
```

---

### Task 8: Settings entry + PRO badge (flavor-split section) and "Get PRO" copy

**Files:**
- Modify: `app/src/full/res/values/strings.xml` (donate overrides + picker strings)
- Create: `app/src/full/java/it/rignanese/leo/slim/ui/settings/ProSettingsSection.kt`
- Create: `app/src/fdroid/java/it/rignanese/leo/slim/ui/settings/ProSettingsSection.kt`
- Modify: `app/src/main/java/it/rignanese/leo/slim/ui/settings/SettingsScreen.kt`
- Modify: `app/src/main/java/it/rignanese/leo/slim/ui/settings/Navigation.kt`

No JVM-testable logic here (pure Compose UI, no ViewModel changes); verified by compilation, lint, and the existing suites staying green. Manual verification lands in TESTING.md (Task 11).

- [ ] **Step 1: Extend the full-flavor strings**

In `app/src/full/res/values/strings.xml`, append inside `<resources>`:

```xml
    <!-- Get PRO reframe — overrides the main donate strings (spec §3.2).
         Safe: the donate keys exist only in the default values/strings.xml,
         so this flavor override wins for every locale. -->
    <string name="donate">Get PRO</string>
    <string name="donate_become_hero">Get PRO / Support the project</string>
    <string name="donate_support_headline">Get PRO — support the project and unlock extras</string>
    <string name="donate_support_body">SlimSocial is free and open source. Pick an annual contribution that feels right — any tier unlocks PRO page themes and keeps an indie project alive.</string>
    <string name="donate_cta">Get PRO yearly</string>

    <!-- Themes picker + PRO badge (full flavor only) -->
    <string name="themes">Themes</string>
    <string name="themes_desc">AMOLED, accent colors, compact mode</string>
    <string name="themes_locked_subtitle">PRO feature — tap to preview</string>
    <string name="theme_default">Default (no theme)</string>
    <string name="pro_badge">PRO</string>
    <string name="get_pro_cta">Get PRO</string>
    <string name="themes_locked_banner">Themes are a PRO extra. Any yearly support tier unlocks them — and keeps SlimSocial alive.</string>
```

- [ ] **Step 2: Create the full-flavor settings section**

Create `app/src/full/java/it/rignanese/leo/slim/ui/settings/ProSettingsSection.kt`:

```kotlin
package it.rignanese.leo.slim.ui.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import it.rignanese.leo.slim.R
import it.rignanese.leo.slim.platform.ProEntitlement

/**
 * Full-flavor Settings entry for the PRO theme picker, with the PRO badge
 * when the entitlement is active (spec §3.2) and a lock hint when it isn't.
 * The same composable is declared as an empty body in `src/fdroid` so no
 * PRO UI is compiled into the F-Droid build.
 */
@Composable
fun ProSettingsSection(
    proEntitlement: ProEntitlement,
    onNavigate: (route: String) -> Unit,
) {
    val isPro by proEntitlement.isPro.collectAsStateWithLifecycle()
    SettingsRow(
        title = stringResource(R.string.themes),
        subtitle = stringResource(
            if (isPro) R.string.themes_desc else R.string.themes_locked_subtitle
        ),
        trailing = {
            if (isPro) {
                ProBadge()
            } else {
                Icon(imageVector = Icons.Filled.Lock, contentDescription = null)
            }
        },
        onClick = { onNavigate("themes") },
    )
}

/** Small "PRO" chip shown in Settings while the entitlement is active. */
@Composable
internal fun ProBadge() {
    Text(
        text = stringResource(R.string.pro_badge),
        style = MaterialTheme.typography.labelSmall,
        color = MaterialTheme.colorScheme.onPrimary,
        modifier = Modifier
            .background(MaterialTheme.colorScheme.primary, RoundedCornerShape(6.dp))
            .padding(horizontal = 8.dp, vertical = 2.dp),
    )
}
```

(If `SettingsRow`'s actual parameter list differs, adapt to it — it is the row primitive `NavigationRow` builds on, taking `title`, `subtitle`, `trailing`, `onClick`.)

- [ ] **Step 3: Create the fdroid no-op section**

Create `app/src/fdroid/java/it/rignanese/leo/slim/ui/settings/ProSettingsSection.kt`:

```kotlin
package it.rignanese.leo.slim.ui.settings

import androidx.compose.runtime.Composable
import it.rignanese.leo.slim.platform.ProEntitlement

/**
 * F-Droid flavor: PRO UI is compiled out — no themes entry, no paywall
 * (spec §3.1). Empty body keeps the shared SettingsScreen flavor-agnostic.
 */
@Suppress("UNUSED_PARAMETER")
@Composable
fun ProSettingsSection(
    proEntitlement: ProEntitlement,
    onNavigate: (route: String) -> Unit,
) {
}
```

- [ ] **Step 4: Call the section from `SettingsScreen`**

In `app/src/main/java/it/rignanese/leo/slim/ui/settings/SettingsScreen.kt`:

Add import `it.rignanese.leo.slim.platform.ProEntitlement`, add the parameter:

```kotlin
fun SettingsScreen(
    vm: SettingsViewModel,
    onNavigate: (route: String) -> Unit,
    onBack: () -> Unit,
    osReader: OsPermissionStateReader,
    proEntitlement: ProEntitlement,
) {
```

At the end of the Style section (right after the `adaptMessenger` ToggleRow, before the `HorizontalDivider()` that precedes Permissions):

```kotlin
            // PRO themes entry — full flavor renders the row (+ badge/lock),
            // fdroid's ProSettingsSection is an empty composable.
            ProSettingsSection(proEntitlement = proEntitlement, onNavigate = onNavigate)
```

- [ ] **Step 5: Pass the entitlement from `Navigation.kt`**

In the `composable("settings/root")` block:

```kotlin
            SettingsScreen(
                vm = vm,
                onNavigate = { route -> navController.navigate(route) },
                onBack = onExitSettings,
                osReader = container.osPermissionReader,
                proEntitlement = container.platform.proEntitlement,
            )
```

- [ ] **Step 6: Build both flavors**

Run: `./gradlew :app:compileFullDebugKotlin :app:compileFdroidDebugKotlin 2>&1 | tail -5`
Expected: BUILD SUCCESSFUL ×2.

- [ ] **Step 7: Run both test suites**

Run: `./gradlew testFullDebugUnitTest testFdroidDebugUnitTest 2>&1 | tail -5`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add app/src/full/res/values/strings.xml \
        app/src/full/java/it/rignanese/leo/slim/ui/settings/ProSettingsSection.kt \
        app/src/fdroid/java/it/rignanese/leo/slim/ui/settings/ProSettingsSection.kt \
        app/src/main/java/it/rignanese/leo/slim/ui/settings/SettingsScreen.kt \
        app/src/main/java/it/rignanese/leo/slim/ui/settings/Navigation.kt
git commit -m "feat(pro): Themes settings entry with PRO badge (full); Get PRO copy overrides; fdroid compiled out"
```

---

### Task 9: Theme picker screen + flavor-split navigation

**Files:**
- Create: `app/src/full/java/it/rignanese/leo/slim/ui/settings/ThemePickerScreen.kt`
- Create: `app/src/full/java/it/rignanese/leo/slim/ui/settings/ProNavGraph.kt`
- Create: `app/src/fdroid/java/it/rignanese/leo/slim/ui/settings/ProNavGraph.kt`
- Modify: `app/src/main/java/it/rignanese/leo/slim/ui/settings/Navigation.kt`

- [ ] **Step 1: Create the picker screen (full flavor)**

Create `app/src/full/java/it/rignanese/leo/slim/ui/settings/ThemePickerScreen.kt`:

```kotlin
package it.rignanese.leo.slim.ui.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import it.rignanese.leo.slim.R
import it.rignanese.leo.slim.platform.ProEntitlement
import it.rignanese.leo.slim.rules.ThemeRuleSource

/**
 * PRO theme picker (full flavor only). One theme active at a time; the
 * "Default" row clears the selection. Non-PRO users see the full catalog
 * with lock icons — tapping any theme (or the banner CTA) deep-links to the
 * Get PRO screen (spec §3.3).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ThemePickerScreen(
    vm: SettingsViewModel,
    proEntitlement: ProEntitlement,
    themeRuleSource: ThemeRuleSource,
    onGetPro: () -> Unit,
    onBack: () -> Unit,
) {
    val settings by vm.settings.collectAsStateWithLifecycle()
    val isPro by proEntitlement.isPro.collectAsStateWithLifecycle()
    val selected = settings.style.selectedTheme

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.themes)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = stringResource(R.string.back),
                        )
                    }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            if (!isPro) {
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(
                        modifier = Modifier.padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Text(
                            text = stringResource(R.string.themes_locked_banner),
                            style = MaterialTheme.typography.bodyMedium,
                        )
                        Button(onClick = onGetPro) {
                            Text(stringResource(R.string.get_pro_cta))
                        }
                    }
                }
            }

            ThemeRowItem(
                name = stringResource(R.string.theme_default),
                swatch = MaterialTheme.colorScheme.surfaceVariant,
                selected = selected == null,
                locked = false,
                onClick = {
                    vm.update { it.copy(style = it.style.copy(selectedTheme = null)) }
                },
            )

            for (theme in themeRuleSource.availableThemes) {
                ThemeRowItem(
                    name = stringResource(theme.nameRes),
                    swatch = Color(theme.previewArgb),
                    selected = selected == theme.id,
                    locked = !isPro,
                    onClick = {
                        if (isPro) {
                            vm.update { it.copy(style = it.style.copy(selectedTheme = theme.id)) }
                        } else {
                            onGetPro()
                        }
                    },
                )
            }
        }
    }
}

@Composable
private fun ThemeRowItem(
    name: String,
    swatch: Color,
    selected: Boolean,
    locked: Boolean,
    onClick: () -> Unit,
) {
    SettingsRow(
        title = name,
        subtitle = null,
        trailing = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                androidx.compose.foundation.layout.Box(
                    modifier = Modifier
                        .size(24.dp)
                        .background(swatch, CircleShape),
                )
                Spacer(modifier = Modifier.width(8.dp))
                if (locked) {
                    Icon(imageVector = Icons.Filled.Lock, contentDescription = null)
                } else {
                    RadioButton(selected = selected, onClick = onClick)
                }
            }
        },
        onClick = onClick,
    )
}
```

(As in Task 8: adapt to `SettingsRow`'s actual signature if it differs.)

- [ ] **Step 2: Create the full-flavor nav extension**

Create `app/src/full/java/it/rignanese/leo/slim/ui/settings/ProNavGraph.kt`:

```kotlin
package it.rignanese.leo.slim.ui.settings

import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.compose.composable
import it.rignanese.leo.slim.app.AppContainer

/**
 * Full-flavor PRO destinations for the Settings nav graph. The `fdroid`
 * source set declares the same function with an empty body, so the shared
 * [SettingsNavGraph] never references PRO screens directly.
 */
fun NavGraphBuilder.proDestinations(
    container: AppContainer,
    navController: NavHostController,
    vm: SettingsViewModel,
) {
    composable("themes") {
        ThemePickerScreen(
            vm = vm,
            proEntitlement = container.platform.proEntitlement,
            themeRuleSource = container.themeRuleSource,
            onGetPro = { navController.navigate("donate") },
            onBack = { navController.popBackStack() },
        )
    }
}
```

- [ ] **Step 3: Create the fdroid no-op nav extension**

Create `app/src/fdroid/java/it/rignanese/leo/slim/ui/settings/ProNavGraph.kt`:

```kotlin
package it.rignanese.leo.slim.ui.settings

import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import it.rignanese.leo.slim.app.AppContainer

/** F-Droid flavor: no PRO destinations — the picker is compiled out (spec §3.1). */
@Suppress("UNUSED_PARAMETER")
fun NavGraphBuilder.proDestinations(
    container: AppContainer,
    navController: NavHostController,
    vm: SettingsViewModel,
) {
}
```

- [ ] **Step 4: Register the destinations in the shared graph**

In `app/src/main/java/it/rignanese/leo/slim/ui/settings/Navigation.kt`, inside the `NavHost` builder (after the `composable("donate")` block):

```kotlin
        proDestinations(container = container, navController = navController, vm = vm)
```

- [ ] **Step 5: Build both flavors + run both suites**

Run: `./gradlew :app:compileFullDebugKotlin :app:compileFdroidDebugKotlin testFullDebugUnitTest testFdroidDebugUnitTest 2>&1 | tail -5`
Expected: BUILD SUCCESSFUL, all tests PASS.

- [ ] **Step 6: Commit**

```bash
git add app/src/full/java/it/rignanese/leo/slim/ui/settings/ThemePickerScreen.kt \
        app/src/full/java/it/rignanese/leo/slim/ui/settings/ProNavGraph.kt \
        app/src/fdroid/java/it/rignanese/leo/slim/ui/settings/ProNavGraph.kt \
        app/src/main/java/it/rignanese/leo/slim/ui/settings/Navigation.kt
git commit -m "feat(pro): theme picker with locked previews deep-linking to Get PRO (full flavor)"
```

---

### Task 10: Entitlement refresh after purchase

**Files:**
- Modify: `app/src/main/java/it/rignanese/leo/slim/ui/settings/DonateScreen.kt`
- Modify: `app/src/main/java/it/rignanese/leo/slim/ui/settings/Navigation.kt`

Spec §3.2: "After purchase, entitlement refreshes and gated features unlock immediately." The refresh call is flavor-safe: fdroid's `NoProEntitlement.refresh()` is a no-op, and the fdroid launcher returns `External`, never `Success`.

- [ ] **Step 1: Add the parameter and refresh call**

In `app/src/main/java/it/rignanese/leo/slim/ui/settings/DonateScreen.kt`:

Add import `it.rignanese.leo.slim.platform.ProEntitlement`. Extend the signature:

```kotlin
@Composable
fun DonateScreen(
    donationLauncher: DonationLauncher,
    proEntitlement: ProEntitlement,
    onBack: () -> Unit,
) {
```

In the button's `scope.launch` block, refresh before showing the result message:

```kotlin
                    scope.launch {
                        isLoading = true
                        val result = donationLauncher.launch(activity, tier.productId)
                        if (result is DonationResult.Success) {
                            // Unlock gated features immediately (spec §3.2). Fail-soft:
                            // the background verification will retry on next app start.
                            runCatching { proEntitlement.refresh() }
                        }
                        isLoading = false
                        val message = when (result) {
                            ...
```

(`when (result)` stays as is; only the `refresh` block is inserted after `launch(...)`.)

- [ ] **Step 2: Pass the entitlement in `Navigation.kt`**

```kotlin
        composable("donate") {
            DonateScreen(
                donationLauncher = container.platform.donationLauncher,
                proEntitlement = container.platform.proEntitlement,
                onBack = { navController.popBackStack() },
            )
        }
```

- [ ] **Step 3: Build + test both flavors**

Run: `./gradlew testFullDebugUnitTest testFdroidDebugUnitTest 2>&1 | tail -5`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add app/src/main/java/it/rignanese/leo/slim/ui/settings/DonateScreen.kt \
        app/src/main/java/it/rignanese/leo/slim/ui/settings/Navigation.kt
git commit -m "feat(pro): refresh entitlement immediately after successful purchase"
```

---

### Task 11: TESTING.md manual matrix + final verification

**Files:**
- Modify: `TESTING.md`

- [ ] **Step 1: Run the full verification gate and capture the new test count**

Run:

```bash
./gradlew testFullDebugUnitTest testFdroidDebugUnitTest lintFullDebug lintFdroidDebug 2>&1 | tail -10
```

Expected: BUILD SUCCESSFUL, lint 0 errors. Then extract the test count:

```bash
grep -rh "tests=" app/build/test-results/testFullDebugUnitTest/*.xml | sed 's/.*tests="\([0-9]*\)".*/\1/' | paste -sd+ | bc
```

- [ ] **Step 2: Verify the fdroid dex-grep precondition locally**

The release CI greps the fdroid dex for proprietary classes. Approximate locally by confirming no fdroid/main source references billing:

```bash
grep -rn "billingclient\|io\.sentry\|play\.review" app/src/main app/src/fdroid --include="*.kt" ; echo "exit=$?"
```

Expected: no matches (`exit=1`).

- [ ] **Step 3: Update TESTING.md**

1. In the CI table, update the row `| 213 unit/Robolectric tests pass on each flavor |` — replace `213` with the new total from Step 1.

2. After the **Sentry verification** section, insert:

```markdown
### PRO purchase / restore (full flavor only, requires a Play license-tester account)

Play Billing cannot run on the JVM; the entitlement mapping/cache logic is unit-tested
with fakes (`PlayBillingProEntitlementTest`), but the end-to-end purchase path needs a
real device with Play services and a license-tester Google account.

- [ ] Fresh install (non-PRO): Settings → Style shows a **Themes** row with a lock icon
- [ ] Themes picker: all 5 themes show a lock; tapping one opens the **Get PRO** screen
- [ ] Get PRO screen shows the reframed copy ("Get PRO — support the project and unlock extras")
- [ ] Purchase tier 1 with a license tester → snackbar thank-you → back in Settings the
      **Themes** row now shows the **PRO** badge (no app restart required)
- [ ] Select **AMOLED black** → open Facebook → page background is true black
- [ ] Enable the free **Dark theme** toggle simultaneously → AMOLED still wins on
      conflicting selectors (background stays #000)
- [ ] Select an accent theme → top bar re-tints; select **Default** → theme cleared
- [ ] Restore: uninstall + reinstall with the same Google account → first launch
      re-verifies in background → PRO badge returns without a new purchase
- [ ] Offline grace: with PRO active, enable airplane mode, force-stop, relaunch →
      still PRO (cache honored; 30-day expiry not manually testable — covered by unit tests)
- [ ] Cancel the subscription in Play → after the subscription period lapses, relaunch
      online → PRO badge and themes revert to locked
- [ ] Each tier (`support_yearly_1..4`) individually unlocks PRO (spot-check at least two)

### PRO absence (fdroid flavor)

- [ ] Settings → Style has **no Themes row**, no PRO badge, no lock icons anywhere
- [ ] The support screen keeps the donation copy ("Support SlimSocial") and opens PayPal
- [ ] `release.yml` dex string check still reports `0` proprietary matches
```

- [ ] **Step 4: Commit**

```bash
git add TESTING.md
git commit -m "docs(testing): manual purchase/restore matrix for PRO; update test count"
```

- [ ] **Step 5: Final gate — the workstream contract**

```bash
./gradlew testFullDebugUnitTest testFdroidDebugUnitTest lintFullDebug lintFdroidDebug
```

Expected: BUILD SUCCESSFUL, all four tasks green.

---

## Self-review notes

- **Spec coverage:** §3.1 entitlement (Tasks 1–2), grace window (Task 1), §3.2 reframe + badge + instant unlock (Tasks 8, 10), §3.3 themes + composition order + picker + deep-link (Tasks 4–9), testing strategy §9-WS1 (fake billing ✓, pure cssFor ✓, gating ✓, TESTING.md ✓ Task 11). Free tier untouched: no existing rule or toggle changes; `RuleRegistry` default params keep old call sites' behavior identical.
- **fdroid compile-out:** entitlement (`NoProEntitlement`), theme catalog (`NoThemeRuleSource` via fdroid provider), settings row (empty `ProSettingsSection`), nav route (empty `proDestinations`) — no PRO UI or theme code in the fdroid APK; no new proprietary imports outside `src/full/`.
- **Type consistency check:** `ProEntitlement.isPro/refresh` used identically in Tasks 1, 2, 7, 8, 9, 10; `ThemeRuleSource.availableThemes/ruleFor` in Tasks 4, 6, 7, 9; `activeRules(s, isPro)` in Tasks 7 and Navigation debug; `providePlatform(context, dataStore, scope)` in Task 2 both flavors + AppContainer.
