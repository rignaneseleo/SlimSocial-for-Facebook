package it.rignanese.leo.slim.webview

import android.webkit.WebSettings
import androidx.webkit.WebSettingsCompat
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
class DarkModeConfiguratorTest {

    @Before
    fun setUp() {
        mockkStatic(WebViewFeature::class)
        mockkStatic(WebSettingsCompat::class)
    }

    @After
    fun tearDown() {
        unmockkStatic(WebViewFeature::class)
        unmockkStatic(WebSettingsCompat::class)
    }

    @Test
    fun `apply forwards to WebSettingsCompat when feature supported`() {
        every { WebViewFeature.isFeatureSupported(WebViewFeature.ALGORITHMIC_DARKENING) } returns true
        every { WebSettingsCompat.setAlgorithmicDarkeningAllowed(any(), any()) } returns Unit
        val settings = mockk<WebSettings>(relaxed = true)

        DarkModeConfigurator().apply(settings, true)

        verify { WebSettingsCompat.setAlgorithmicDarkeningAllowed(settings, true) }
    }

    @Test
    fun `apply is a no-op when feature unsupported`() {
        every { WebViewFeature.isFeatureSupported(WebViewFeature.ALGORITHMIC_DARKENING) } returns false
        val settings = mockk<WebSettings>(relaxed = true)

        DarkModeConfigurator().apply(settings, true)

        verify(exactly = 0) { WebSettingsCompat.setAlgorithmicDarkeningAllowed(any(), any()) }
    }
}
