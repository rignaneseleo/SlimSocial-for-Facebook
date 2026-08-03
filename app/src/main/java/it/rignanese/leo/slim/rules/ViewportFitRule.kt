package it.rignanese.leo.slim.rules

import it.rignanese.leo.slim.domain.InjectionRule

/**
 * Makes Facebook's desktop layout fit a phone screen.
 *
 * Since the switch to a desktop-class UA (see [it.rignanese.leo.slim.domain.UserAgentResolver])
 * Facebook serves the `www` desktop page. Measured 2026-08-01 against the live
 * site: that page ships **no `<meta name="viewport">` at all**. A WebView with
 * `useWideViewPort = true` and no meta falls back to its 980px default layout
 * width, so the page is laid out for a 980px screen and everything past the
 * device width is simply off-screen — which is what the app showed on a Pixel:
 * the composer row, story tray and post cards clipped at the right edge.
 *
 * **JS only.** Installing the meta is the whole fix: the WebView then lays out
 * against the real screen instead of 980px. It runs on every injection pass,
 * so it re-asserts if Facebook's SPA swaps the head out.
 *
 * An earlier revision also injected
 * `html, body { max-width: 100vw; overflow-x: hidden }` to kill a residual
 * 69px overflow. **Do not bring that back.** Verified on-device 2026-08-01: a
 * clipping container on the document stops the feed scrolling vertically and
 * swallows Facebook's flyouts (notifications, account menu), which are
 * absolutely positioned and get clipped away. A few pixels of horizontal slack
 * are far cheaper than an unscrollable feed with dead buttons.
 *
 * Always on — this is a "render correctly at all" fix, not a preference.
 * FB hosts only; messenger has its own responsive layout.
 */
class ViewportFitRule : InjectionRule {
    override val id: String = "viewport_fit"

    override fun jsFor(url: String): String? {
        if (!RuleGates.isFbHost(url)) return null
        return JS
    }

    private companion object {
        const val JS = """
(function () {
  var m = document.querySelector('meta[name=viewport]');
  if (!m) {
    m = document.createElement('meta');
    m.setAttribute('name', 'viewport');
    (document.head || document.documentElement).appendChild(m);
  }
  m.setAttribute('content', 'width=device-width, initial-scale=1, viewport-fit=cover');
})()
"""
    }
}
