package it.rignanese.leo.slim.permissions

import android.Manifest
import android.webkit.PermissionRequest
import io.kotest.matchers.shouldBe
import it.rignanese.leo.slim.webview.WebPermission
import org.junit.jupiter.api.Test

class PermissionMappingTest {

    @Test
    fun `Camera Mic and Location each map to Android runtime permission strings`() {
        PermissionMapping.WEB_PERMISSION_TO_ANDROID[WebPermission.Camera] shouldBe Manifest.permission.CAMERA
        PermissionMapping.WEB_PERMISSION_TO_ANDROID[WebPermission.Mic] shouldBe Manifest.permission.RECORD_AUDIO
        PermissionMapping.WEB_PERMISSION_TO_ANDROID[WebPermission.Location] shouldBe Manifest.permission.ACCESS_FINE_LOCATION
    }

    @Test
    fun `Photos has no entry because SAF replaces the runtime permission`() {
        PermissionMapping.WEB_PERMISSION_TO_ANDROID.containsKey(WebPermission.Photos) shouldBe false
    }

    @Test
    fun `WEB_PERMISSION_TO_ANDROID covers every WebPermission except Photos`() {
        val keys = PermissionMapping.WEB_PERMISSION_TO_ANDROID.keys
        keys shouldBe setOf(WebPermission.Camera, WebPermission.Mic, WebPermission.Location)
    }

    @Test
    fun `WEB_PERMISSION_RESOURCE maps WebView resource constants both ways`() {
        PermissionMapping.WEB_PERMISSION_RESOURCE[PermissionRequest.RESOURCE_VIDEO_CAPTURE] shouldBe WebPermission.Camera
        PermissionMapping.WEB_PERMISSION_RESOURCE[PermissionRequest.RESOURCE_AUDIO_CAPTURE] shouldBe WebPermission.Mic
    }
}
