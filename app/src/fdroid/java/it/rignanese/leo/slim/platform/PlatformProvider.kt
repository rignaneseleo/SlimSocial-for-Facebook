package it.rignanese.leo.slim.platform

import android.app.Activity
import android.app.Application
import android.content.Context
import android.content.Intent
import android.net.Uri

/**
 * F-Droid flavor entry point. The same top-level function is declared in the
 * `full` source set; Kotlin resolves the correct definition at flavor build
 * time. Keeping this as a top-level function (rather than KMP `expect/actual`)
 * means we don't need the multiplatform plugin.
 */
fun providePlatform(context: Context): Platform = FdroidPlatform()

internal class FdroidPlatform : Platform {
    override val crashReporter: CrashReporter = NoOpCrashReporter()
    override val donationLauncher: DonationLauncher = ExternalDonationLauncher()
    override val reviewLauncher: ReviewLauncher = NoOpReviewLauncher()
}

/** No-op crash reporter: the F-Droid build links zero proprietary crash deps. */
internal class NoOpCrashReporter : CrashReporter {
    override fun init(app: Application, sentryEnabled: Boolean) {}
    override fun reportNonFatal(throwable: Throwable, tags: Map<String, String>) {}
    override fun setEnabled(enabled: Boolean) {}
}

/**
 * F-Droid donation launcher: opens an external donation URL (PayPal). We
 * always return [DonationResult.External] so callers can show a flavor-aware
 * acknowledgement without pretending an in-app purchase succeeded.
 */
internal class ExternalDonationLauncher : DonationLauncher {
    override suspend fun launch(activity: Activity, productId: String): DonationResult {
        runCatching {
            activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(DONATION_URL)))
        }
        return DonationResult.External
    }

    companion object {
        const val DONATION_URL = "https://www.paypal.me/LeonardoRignanese"
    }
}

/** No-op review launcher: there is no F-Droid equivalent to Play In-App Review. */
internal class NoOpReviewLauncher : ReviewLauncher {
    override fun maybeRequest(activity: Activity) {}
}
