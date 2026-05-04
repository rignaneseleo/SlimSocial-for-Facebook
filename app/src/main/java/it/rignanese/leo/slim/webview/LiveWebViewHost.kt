package it.rignanese.leo.slim.webview

/**
 * Process-scoped holder for the currently-active [WebViewHost].
 *
 * The Editor screen ("Test" button) needs to inject CSS/JS through the live
 * production WebView, but the [WebViewHost] is created deep inside Compose's
 * `AndroidView` factory and is not naturally reachable from a sibling
 * navigation destination. Rather than thread a callback through every
 * `NavHost.composable { ... }` site, we capture the live host into this
 * container.
 *
 * `BrowserScreen` writes [current] when the factory runs; if the host is ever
 * disposed (e.g. process recreation), the writer should clear the field.
 *
 * The field is intentionally _not_ wrapped in a `StateFlow` — Compose code that
 * needs reactivity should still drive UI from settings or VM-level state. This
 * holder is a one-shot pointer, not a stream.
 */
class LiveWebViewHost {
    @Volatile
    var current: WebViewHost? = null
}
