package it.rignanese.leo.slim.webview

import android.net.Uri
import android.webkit.GeolocationPermissions
import android.webkit.PermissionRequest
import android.webkit.ValueCallback
import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import io.mockk.verify
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class AppWebChromeClientTest {

    private fun makeClient(gate: PermissionGate) = AppWebChromeClient(
        gate = gate,
        onConsoleMessage = {},
        onShowFileChooser = { _, _ -> true },
        onShowCustomView = { _, _ -> },
        onHideCustomView = {},
    )

    @Test
    fun `grants only camera when camera-grant gate sees camera+mic request`() {
        val gate = FakePermissionGate(
            decisions = mapOf(
                WebPermission.Camera to GateDecision.Grant,
                WebPermission.Mic to GateDecision.Deny,
            ),
        )
        val client = makeClient(gate)
        val request = mockk<PermissionRequest>(relaxed = true)
        every { request.resources } returns arrayOf(
            PermissionRequest.RESOURCE_VIDEO_CAPTURE,
            PermissionRequest.RESOURCE_AUDIO_CAPTURE,
        )
        val grantedSlot = slot<Array<String>>()

        client.onPermissionRequest(request)

        verify(exactly = 0) { request.deny() }
        verify { request.grant(capture(grantedSlot)) }
        assert(grantedSlot.captured.toList() == listOf(PermissionRequest.RESOURCE_VIDEO_CAPTURE))
    }

    @Test
    fun `denies all when gate denies everything`() {
        val client = makeClient(FakePermissionGate.denyAll())
        val request = mockk<PermissionRequest>(relaxed = true)
        every { request.resources } returns arrayOf(
            PermissionRequest.RESOURCE_VIDEO_CAPTURE,
            PermissionRequest.RESOURCE_AUDIO_CAPTURE,
        )

        client.onPermissionRequest(request)

        verify { request.deny() }
        verify(exactly = 0) { request.grant(any()) }
    }

    @Test
    fun `geolocation off invokes callback with retain false and grant false`() {
        val client = makeClient(FakePermissionGate.denyAll())
        val callback = mockk<GeolocationPermissions.Callback>(relaxed = true)

        client.onGeolocationPermissionsShowPrompt("https://m.facebook.com", callback)

        verify { callback.invoke("https://m.facebook.com", false, false) }
    }

    @Test
    fun `file chooser denied feeds empty array back to callback`() {
        val client = makeClient(FakePermissionGate.denyAll())
        val pathCallback = mockk<ValueCallback<Array<Uri>>>(relaxed = true)
        val webView = mockk<android.webkit.WebView>(relaxed = true)
        val params = mockk<android.webkit.WebChromeClient.FileChooserParams>(relaxed = true)
        val capture = slot<Array<Uri>>()

        val handled = client.onShowFileChooser(webView, pathCallback, params)

        assert(handled)
        verify { pathCallback.onReceiveValue(capture(capture)) }
        assert(capture.captured.isEmpty())
    }
}
