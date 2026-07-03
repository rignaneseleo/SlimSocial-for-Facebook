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
