package it.rignanese.leo.slim.platform

import android.app.Application
import io.sentry.Sentry
import io.sentry.SentryEvent
import io.sentry.android.core.SentryAndroid
import it.rignanese.leo.slim.BuildConfig
import it.rignanese.leo.slim.data.ScrubInput
import it.rignanese.leo.slim.data.SentryEventScrubber

/**
 * Sentry-backed [CrashReporter] for the `full` flavor.
 *
 * Skips initialisation gracefully when:
 *   - the user has opted out (`sentryEnabled = false`)
 *   - the build was produced without a DSN (dev / local builds — CI injects
 *     `SENTRY_DSN` for shipped builds)
 *
 * Auto-init is disabled in `src/full/AndroidManifest.xml` so we control the
 * lifecycle precisely from [SlimApplication].
 */
class SentryCrashReporter : CrashReporter {

    @Volatile
    private var initialised: Boolean = false

    override fun init(app: Application, sentryEnabled: Boolean) {
        if (!sentryEnabled) return
        if (BuildConfig.SENTRY_DSN.isBlank()) return

        SentryAndroid.init(app) { options ->
            options.dsn = BuildConfig.SENTRY_DSN
            options.release =
                "${BuildConfig.APPLICATION_ID}@${BuildConfig.VERSION_NAME}+${BuildConfig.VERSION_CODE}"
            options.dist = BuildConfig.VERSION_CODE.toString()
            options.isSendDefaultPii = false
            options.tracesSampleRate = 0.05
            options.sampleRate = 1.0
            options.setBeforeSend { event, _ ->
                applyScrub(event)
                event
            }
        }
        initialised = true
    }

    override fun reportNonFatal(throwable: Throwable, tags: Map<String, String>) {
        if (!initialised) return
        Sentry.captureException(throwable) { scope ->
            tags.forEach { (k, v) -> scope.setTag(k, v) }
        }
    }

    override fun setEnabled(enabled: Boolean) {
        if (!enabled && initialised) {
            Sentry.close()
            initialised = false
        }
    }

    /**
     * Apply [SentryEventScrubber] to a Sentry [SentryEvent] before it leaves
     * the device. We bridge the event's bag-of-strings to [ScrubInput] for the
     * pure scrub logic, then write the cleaned values back. The `request` body
     * gets its sensitive fields nulled regardless to avoid leaking session
     * cookies / query strings.
     */
    private fun applyScrub(event: SentryEvent) {
        // Drop the highest-risk request fields outright.
        event.request?.let { request ->
            request.cookies = null
            request.queryString = null
        }

        val input = ScrubInput(
            cookies = event.request?.cookies,
            queryString = event.request?.queryString,
            headers = event.request?.headers?.toMap().orEmpty(),
            extras = event.extras?.mapValues { it.value?.toString().orEmpty() }.orEmpty(),
            tags = event.tags.orEmpty(),
        )
        val scrubbed = SentryEventScrubber.scrub(input)

        // Write scrubbed tags back.
        scrubbed.tags.forEach { (k, v) -> event.setTag(k, v) }
        // Drop any tag key that was filtered out (key suggested a credential).
        event.tags?.keys?.toList()?.forEach { key ->
            if (!scrubbed.tags.containsKey(key)) event.removeTag(key)
        }
        // Write scrubbed extras back. Sentry stores extras as Map<String, Any?>;
        // we only carry strings through ScrubInput so this round-trips cleanly.
        scrubbed.extras.forEach { (k, v) -> event.setExtra(k, v) }
        event.extras?.keys?.toList()?.forEach { key ->
            if (!scrubbed.extras.containsKey(key)) event.removeExtra(key)
        }
    }
}
