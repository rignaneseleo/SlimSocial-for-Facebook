package it.rignanese.leo.slim.webview

import android.content.Context
import android.net.Uri
import android.webkit.RenderProcessGoneDetail
import android.webkit.WebResourceRequest
import android.webkit.WebView
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import it.rignanese.leo.slim.data.LogBuffer
import it.rignanese.leo.slim.data.LogCategory
import it.rignanese.leo.slim.domain.UrlRouter
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class AppWebViewClientTest {

    private val urlRouter = UrlRouter()

    @Test
    fun `shouldOverrideUrlLoading returns false for in-app facebook URL`() {
        val opener = mockk<UrlOpener>(relaxed = true)
        val client = AppWebViewClient(
            urlRouter = urlRouter,
            urlOpener = opener,
            onPageReady = {},
            onRenderGone = {},
            logBuffer = LogBuffer(),
        )
        val view = mockk<WebView>(relaxed = true)
        val request = mockk<WebResourceRequest>(relaxed = true)
        every { request.url } returns Uri.parse("https://m.facebook.com/foo")

        val handled = client.shouldOverrideUrlLoading(view, request)

        assert(!handled)
        verify(exactly = 0) { opener.open(any(), any()) }
    }

    @Test
    fun `shouldOverrideUrlLoading returns true for external URL and calls opener`() {
        val opener = mockk<UrlOpener>(relaxed = true)
        val client = AppWebViewClient(
            urlRouter = urlRouter,
            urlOpener = opener,
            onPageReady = {},
            onRenderGone = {},
            logBuffer = LogBuffer(),
        )
        val context = mockk<Context>(relaxed = true)
        val view = mockk<WebView>(relaxed = true)
        every { view.context } returns context
        val request = mockk<WebResourceRequest>(relaxed = true)
        every { request.url } returns Uri.parse("https://example.com/")

        val handled = client.shouldOverrideUrlLoading(view, request)

        assert(handled)
        verify { opener.open(context, "https://example.com/") }
    }

    @Test
    fun `onRenderProcessGone records log emits callback and returns true`() {
        val log = LogBuffer()
        var seenDidCrash: Boolean? = null
        val client = AppWebViewClient(
            urlRouter = urlRouter,
            urlOpener = mockk(relaxed = true),
            onPageReady = {},
            onRenderGone = { seenDidCrash = it },
            logBuffer = log,
        )
        val detail = mockk<RenderProcessGoneDetail>(relaxed = true)
        every { detail.didCrash() } returns false
        val view = mockk<WebView>(relaxed = true)

        val handled = client.onRenderProcessGone(view, detail)

        assert(handled)
        assert(seenDidCrash == false)
        val snapshot = log.snapshot()
        assert(snapshot.size == 1)
        assert(snapshot[0].category == LogCategory.RENDER_GONE)
        assert(snapshot[0].message == "didCrash=false")
    }
}
