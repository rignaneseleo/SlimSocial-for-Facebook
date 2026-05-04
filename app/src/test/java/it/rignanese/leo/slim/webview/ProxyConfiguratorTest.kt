package it.rignanese.leo.slim.webview

import androidx.webkit.ProxyController
import androidx.webkit.WebViewFeature
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
class ProxyConfiguratorTest {

    private val controller: ProxyController = mockk(relaxed = true)

    @Before
    fun setUp() {
        mockkStatic(WebViewFeature::class)
        mockkStatic(ProxyController::class)
        every { ProxyController.getInstance() } returns controller
    }

    @After
    fun tearDown() {
        unmockkStatic(WebViewFeature::class)
        unmockkStatic(ProxyController::class)
    }

    @Test
    fun `apply is a no-op when feature unsupported`() {
        every { WebViewFeature.isFeatureSupported(WebViewFeature.PROXY_OVERRIDE) } returns false

        ProxyConfigurator().apply("proxy.example", "8080") {}

        verify(exactly = 0) { controller.setProxyOverride(any(), any(), any()) }
    }

    @Test
    fun `apply early-returns on blank host`() {
        every { WebViewFeature.isFeatureSupported(WebViewFeature.PROXY_OVERRIDE) } returns true

        ProxyConfigurator().apply("", "8080") {}

        verify(exactly = 0) { controller.setProxyOverride(any(), any(), any()) }
    }

    @Test
    fun `apply early-returns on non-numeric port`() {
        every { WebViewFeature.isFeatureSupported(WebViewFeature.PROXY_OVERRIDE) } returns true

        ProxyConfigurator().apply("proxy.example", "abc") {}

        verify(exactly = 0) { controller.setProxyOverride(any(), any(), any()) }
    }

    @Test
    fun `apply forwards to controller when supported and inputs are valid`() {
        every { WebViewFeature.isFeatureSupported(WebViewFeature.PROXY_OVERRIDE) } returns true

        ProxyConfigurator().apply("proxy.example", "8080") {}

        verify { controller.setProxyOverride(any(), any(), any()) }
    }

    @Test
    fun `clear is a no-op when feature unsupported`() {
        every { WebViewFeature.isFeatureSupported(WebViewFeature.PROXY_OVERRIDE) } returns false

        ProxyConfigurator().clear {}

        verify(exactly = 0) { controller.clearProxyOverride(any(), any()) }
    }
}
