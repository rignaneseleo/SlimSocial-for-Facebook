package it.rignanese.leo.slim.webview

import android.webkit.CookieManager
import android.webkit.WebView
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkStatic
import io.mockk.verify
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class CookieConfiguratorTest {

    private val mgr: CookieManager = mockk(relaxed = true)

    @Before
    fun setUp() {
        mockkStatic(CookieManager::class)
        every { CookieManager.getInstance() } returns mgr
    }

    @After
    fun tearDown() {
        unmockkStatic(CookieManager::class)
    }

    @Test
    fun `configure sets accept cookie and accept third-party cookies`() {
        val webView = mockk<WebView>(relaxed = true)
        CookieConfigurator().configure(webView)

        verify { mgr.setAcceptCookie(true) }
        verify { mgr.setAcceptThirdPartyCookies(webView, true) }
    }

    @Test
    fun `flush forwards to CookieManager`() {
        CookieConfigurator().flush()
        verify { mgr.flush() }
    }
}
