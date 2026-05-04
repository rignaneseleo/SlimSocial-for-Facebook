package it.rignanese.leo.slim.platform

import android.app.Activity
import com.google.android.play.core.review.ReviewManagerFactory

/**
 * Play In-App Review launcher for the `full` flavor. Whether the prompt is
 * actually shown to the user is opaque (Google decides based on quotas and
 * eligibility) — we just request the flow and ignore the outcome.
 */
class PlayReviewLauncher : ReviewLauncher {

    override fun maybeRequest(activity: Activity) {
        val manager = ReviewManagerFactory.create(activity)
        manager.requestReviewFlow().addOnCompleteListener { task ->
            if (!task.isSuccessful) return@addOnCompleteListener
            manager.launchReviewFlow(activity, task.result).addOnCompleteListener {
                // Outcome is opaque per Play guidelines; ignore.
            }
        }
    }
}
