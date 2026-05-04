package it.rignanese.leo.slim.platform

import android.content.Context

/**
 * Full (Play Store) flavor entry point. The same top-level function is
 * declared in the `fdroid` source set; Kotlin resolves the correct definition
 * at flavor build time.
 */
fun providePlatform(context: Context): Platform = FullPlatform(context.applicationContext)

internal class FullPlatform(private val context: Context) : Platform {
    override val crashReporter: CrashReporter = SentryCrashReporter()
    override val donationLauncher: DonationLauncher = PlayBillingDonationLauncher(context)
    override val reviewLauncher: ReviewLauncher = PlayReviewLauncher()
}
