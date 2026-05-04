package it.rignanese.leo.slim.platform

import android.app.Activity
import android.app.Application

/**
 * Crash / non-fatal reporter abstraction.
 *
 * `full` flavor backs this with Sentry; `fdroid` flavor uses a no-op so the
 * F-Droid build links zero proprietary classes.
 */
interface CrashReporter {
    fun init(app: Application, sentryEnabled: Boolean)
    fun reportNonFatal(throwable: Throwable, tags: Map<String, String> = emptyMap())
    fun setEnabled(enabled: Boolean)
}

/**
 * Outcome of a donation attempt.
 *
 * `External` is used by the F-Droid flavor when it opens an external link
 * (e.g. PayPal) instead of running a real billing flow.
 */
sealed class DonationResult {
    object Success : DonationResult()
    data class Cancelled(val reason: String) : DonationResult()
    data class Error(val message: String) : DonationResult()
    object External : DonationResult()
}

/**
 * Donation flow abstraction. `full` flavor uses Play Billing; `fdroid` opens
 * an external donation URL.
 */
interface DonationLauncher {
    suspend fun launch(activity: Activity, productId: String): DonationResult
}

/**
 * In-app review prompt abstraction. `full` flavor uses Play In-App Review;
 * `fdroid` is a no-op (no equivalent on F-Droid).
 */
interface ReviewLauncher {
    fun maybeRequest(activity: Activity)
}

/**
 * Aggregator of platform-flavored services. Constructed via the
 * `providePlatform(Context)` top-level factory function provided by each
 * flavor source set (`src/full` and `src/fdroid`).
 */
interface Platform {
    val crashReporter: CrashReporter
    val donationLauncher: DonationLauncher
    val reviewLauncher: ReviewLauncher
}
