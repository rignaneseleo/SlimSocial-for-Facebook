package it.rignanese.leo.slim.platform

import android.app.Activity
import android.content.Intent
import androidx.test.core.app.ApplicationProvider
import io.kotest.matchers.shouldBe
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/**
 * Verifies the F-Droid donation flow:
 *   - returns [DonationResult.External] regardless of productId
 *   - kicks off an `ACTION_VIEW` intent for the configured PayPal URL
 *
 * Uses Robolectric so we can inspect the next-started intent on the activity
 * via the shadow API without standing up a real device.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class ExternalDonationLauncherTest {

    private lateinit var activity: Activity
    private val launcher = ExternalDonationLauncher()

    @Before
    fun setUp() {
        // Make sure we read context off the application — the launcher itself
        // doesn't depend on it but Robolectric needs an initialised context.
        ApplicationProvider.getApplicationContext<android.content.Context>()
        activity = Robolectric.buildActivity(Activity::class.java).setup().get()
    }

    @After
    fun tearDown() {
        // No global state to clean.
    }

    @Test
    fun `launch returns External and starts ACTION_VIEW for paypal url`() {
        runBlocking {
            val result = launcher.launch(activity, productId = "donation_1")

            result shouldBe DonationResult.External

            val started = shadowOf(activity).nextStartedActivity
            started.action shouldBe Intent.ACTION_VIEW
            started.data?.toString() shouldBe ExternalDonationLauncher.DONATION_URL
        }
    }

    @Test
    fun `launch returns External even with unrecognised productId`() {
        runBlocking {
            val result = launcher.launch(activity, productId = "totally-fake")
            result shouldBe DonationResult.External
        }
    }
}
