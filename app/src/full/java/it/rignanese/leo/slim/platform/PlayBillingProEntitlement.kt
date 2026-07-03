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
