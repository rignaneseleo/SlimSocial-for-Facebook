package it.rignanese.leo.slim.webview

import android.net.Uri
import android.view.View
import android.webkit.ConsoleMessage
import android.webkit.GeolocationPermissions
import android.webkit.PermissionRequest
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebView

/**
 * WebChromeClient that funnels JS-originated UI / capability requests through a
 * [PermissionGate]. The gate is purely a decision boundary — it never asks the
 * user. Runtime permission prompts are the host activity's responsibility (Phase 6).
 */
class AppWebChromeClient(
    private val gate: PermissionGate,
    // Lambda parameters intentionally NOT named after the WebChromeClient
    // overrides they back. Same name + same arity = Kotlin resolves the call
    // inside the override to the member function itself, producing an infinite
    // recursion that detonates as a StackOverflowError on the first console
    // log. Disambiguated by renaming the lambdas.
    private val onConsole: (ConsoleMessage) -> Unit,
    private val onShowFileChooser: (ValueCallback<Array<Uri>>, FileChooserParams) -> Boolean,
    private val onShowCustom: (View, CustomViewCallback) -> Unit,
    private val onHideCustom: () -> Unit,
) : WebChromeClient() {

    override fun onPermissionRequest(request: PermissionRequest) {
        val granted = mutableListOf<String>()
        for (resource in request.resources) {
            val webPerm = when (resource) {
                PermissionRequest.RESOURCE_VIDEO_CAPTURE -> WebPermission.Camera
                PermissionRequest.RESOURCE_AUDIO_CAPTURE -> WebPermission.Mic
                else -> null
            } ?: continue
            if (gate.decide(webPerm) == GateDecision.Grant) granted += resource
        }
        if (granted.isEmpty()) request.deny() else request.grant(granted.toTypedArray())
    }

    override fun onGeolocationPermissionsShowPrompt(
        origin: String,
        callback: GeolocationPermissions.Callback,
    ) {
        val grant = gate.decide(WebPermission.Location) == GateDecision.Grant
        // retain=false: ask each session, do not persist a per-origin allow.
        callback.invoke(origin, grant, false)
    }

    override fun onShowFileChooser(
        webView: WebView,
        filePathCallback: ValueCallback<Array<Uri>>,
        fileChooserParams: FileChooserParams,
    ): Boolean {
        return if (gate.decide(WebPermission.Photos) == GateDecision.Grant) {
            onShowFileChooser(filePathCallback, fileChooserParams)
        } else {
            filePathCallback.onReceiveValue(emptyArray())
            true
        }
    }

    override fun onConsoleMessage(message: ConsoleMessage): Boolean {
        onConsole(message)
        return true
    }

    override fun onShowCustomView(view: View, callback: CustomViewCallback) {
        onShowCustom(view, callback)
    }

    override fun onHideCustomView() {
        onHideCustom()
    }
}
