package it.rignanese.leo.slim.webview

import android.content.Context
import android.net.Uri
import androidx.browser.customtabs.CustomTabsIntent

/**
 * Strategy for opening external (non-Facebook) URLs out of the WebView.
 * Default implementation hops to a Chrome Custom Tab so the user keeps the host
 * app's chrome (back-stack, theme) without the WebView taking over.
 */
interface UrlOpener {
    fun open(context: Context, url: String)
}

/**
 * Custom Tabs implementation. Wrapped in `runCatching` because:
 *  - on devices without any browser supporting Custom Tabs the launch falls back
 *    to a regular intent which may also fail (e.g. headless emulators);
 *  - we never want a malformed URL to crash the host app.
 */
class CustomTabsUrlOpener : UrlOpener {
    override fun open(context: Context, url: String) {
        runCatching {
            CustomTabsIntent.Builder()
                .setShowTitle(true)
                .build()
                .launchUrl(context, Uri.parse(url))
        }
    }
}
