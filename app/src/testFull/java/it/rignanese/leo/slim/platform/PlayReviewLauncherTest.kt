package it.rignanese.leo.slim.platform

import android.app.Activity
import com.google.android.play.core.review.ReviewManager
import com.google.android.play.core.review.ReviewManagerFactory
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkStatic
import io.mockk.verify
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Verifies that [PlayReviewLauncher.maybeRequest] reaches the Play
 * `ReviewManagerFactory`. The actual flow outcome is opaque per Play
 * guidelines (Google decides whether to show the prompt), so we don't
 * assert on it — only that we asked for one.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class PlayReviewLauncherTest {

    private lateinit var activity: Activity
    private val manager: ReviewManager = mockk(relaxed = true)

    @Before
    fun setUp() {
        activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        mockkStatic(ReviewManagerFactory::class)
        every { ReviewManagerFactory.create(any()) } returns manager
    }

    @After
    fun tearDown() {
        unmockkStatic(ReviewManagerFactory::class)
    }

    @Test
    fun `maybeRequest goes through ReviewManagerFactory`() {
        PlayReviewLauncher().maybeRequest(activity)
        verify { ReviewManagerFactory.create(activity) }
    }
}
