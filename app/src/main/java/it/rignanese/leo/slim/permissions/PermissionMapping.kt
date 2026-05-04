package it.rignanese.leo.slim.permissions

import android.Manifest
import android.webkit.PermissionRequest
import it.rignanese.leo.slim.webview.WebPermission

/**
 * Static maps connecting our [WebPermission] domain to:
 *  - the Android runtime permission string (used by [OsPermissionStateReader]
 *    and the request launcher);
 *  - the WebView [PermissionRequest] resource constants (so AppWebChromeClient
 *    can translate JS resource strings to a [WebPermission]).
 *
 * Photos has no entry in [WEB_PERMISSION_TO_ANDROID]: we use the Storage Access
 * Framework (file chooser) on API 24+ which handles consent inline, so there is
 * no runtime permission to request.
 *
 * For Location we request [Manifest.permission.ACCESS_FINE_LOCATION]; granting
 * fine implicitly grants coarse, so no separate coarse fallback is wired.
 */
object PermissionMapping {
    val WEB_PERMISSION_TO_ANDROID: Map<WebPermission, String> = mapOf(
        WebPermission.Camera to Manifest.permission.CAMERA,
        WebPermission.Mic to Manifest.permission.RECORD_AUDIO,
        WebPermission.Location to Manifest.permission.ACCESS_FINE_LOCATION,
    )

    val WEB_PERMISSION_RESOURCE: Map<String, WebPermission> = mapOf(
        PermissionRequest.RESOURCE_VIDEO_CAPTURE to WebPermission.Camera,
        PermissionRequest.RESOURCE_AUDIO_CAPTURE to WebPermission.Mic,
    )
}
