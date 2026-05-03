package it.rignanese.leo.slim.webview

/**
 * Categories of WebView-originated permissions the app gates on user settings.
 *
 * Phase 4 only declares this contract. Phase 6 supplies a concrete implementation
 * that consults `Settings.permissions` plus the runtime permission state.
 */
sealed class WebPermission {
    object Camera : WebPermission()
    object Mic : WebPermission()
    object Location : WebPermission()
    object Photos : WebPermission()
}

sealed class GateDecision {
    object Grant : GateDecision()
    object Deny : GateDecision()
}

/**
 * Single-method contract used by [AppWebChromeClient] to decide whether to honor
 * a JS-originated permission request.
 *
 * Implementations MUST be safe to call on the main thread and MUST be synchronous
 * (the WebChromeClient callback is fire-and-forget — there is no continuation).
 */
interface PermissionGate {
    fun decide(perm: WebPermission): GateDecision
}
