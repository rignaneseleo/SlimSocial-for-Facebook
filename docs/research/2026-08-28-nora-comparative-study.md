# Nora comparative study — techniques worth adopting

**Date:** 2026-08-28
**Subject:** [nonbili/Nora](https://github.com/nonbili/Nora) @ `777009e` (v0.8.8 Android, 2026-08-23) — a React Native / Expo browser for ten social networks, AGPL-3.0, ~1.1k stars, actively maintained.
**Purpose:** identify techniques Nora has solved that SlimSocial has not, record how each one works, and cost it against this codebase.

Nora solves the same problem as SlimSocial — wrap a social network in a WebView, inject code, remove the advertising — for ten sites instead of one. That overlap makes it the most useful reference implementation available. This document is the distilled result of reading its source: content scripts, blocklist engine, Android module (~1,900 lines of Kotlin), notification pollers, and state layer.

---

## 0. Licence policy — read before using anything here

**Nora is AGPL-3.0. SlimSocial is GPL-2.0.** Code cannot move from the former into the latter: GPL-2.0 and AGPL-3.0 are incompatible, and the compatibility that does exist for AGPL-3.0 code requires the GPL-3.0 level (AGPLv3 §13 / GPLv3 §13).

Therefore this document is a **specification, not a source of code**. Everything below describes *behaviour* — which attribute holds the video URL, which query parameters are tracking, which API endpoint carries the badge counts, how a scroll offset must be corrected. Facts and interfaces are not copyrightable; expression is. Every adoption must be written from scratch in Dart, in this codebase's own idiom.

If verbatim reuse ever becomes desirable, the prerequisite is relicensing SlimSocial to GPL-3.0-or-later, which needs sign-off from prior code contributors. That is a deliberate decision to take separately, not a side effect of a feature.

> The reading above is engineering judgement recorded for planning purposes, not legal advice.

---

## 1. Architectural difference that explains everything else

| Layer | Nora | SlimSocial |
|---|---|---|
| Shell | React Native / Expo 56, TypeScript; Android + iOS + Electron desktop from one tree | Flutter, Android-first |
| WebView | **Own native module** (`NoraView`): full `WebViewClient` / `WebChromeClient` ownership | `webview_flutter` 4.10 — the plugin owns the client, the app sees only exposed callbacks |
| Injection | One esbuild IIFE bundle per page, plus true document-start scripts via `WebViewCompat.addDocumentStartJavaScript` for guards that must beat page scripts | Dart-assembled JS at `onPageStarted` / `onPageFinished`, idempotent by element id, each step isolated with health telemetry |
| Scope | 10 networks, multi-tab, tab groups, desktop deck view | Facebook + Messenger |
| Accounts | Multi-profile via androidx `ProfileStore` (real cookie-jar isolation) | Single session |
| State | legend-state + MMKV, versioned JSON backup, optional server sync | `shared_preferences` with a disciplined key registry |

The single fact that matters: **Nora owns its `WebViewClient`.** That is what unlocks request interception, document-start scripts, popup windows, renderer-crash recovery, cookie reads, profiles and proxy control. SlimSocial rents its WebView from `webview_flutter`, which exposes none of those. Every item in §4 is tagged by whether it clears that wall.

---

## 2. Ad-blocking is three independent layers

Nora runs all three. SlimSocial runs one — and runs it better than Nora does.

### Layer 1 — Network (host blocking)

`shouldInterceptRequest` returns an empty `WebResourceResponse` for any **non-main-frame** request whose host matches a blocklist compiled from EasyList, EasyPrivacy and two Brave first-party lists. Matching walks the host's labels from most to least specific; `@@` exception rules win only if they match at a *more specific* level than the block rule.

Relevance to Facebook: **partial.** Facebook serves its feed advertising first-party, so this layer removes third-party *tracking* rather than feed ads. It is a privacy feature, not an ad-blocking one.

### Layer 2 — Response rewriting

Patch `XMLHttpRequest` and `fetch` on the prototype, then filter advertising out of the JSON before the page ever parses it: Instagram GraphQL (`edges.filter(!node.ad)`), Twitter timeline instructions (drop entries whose `entryId` contains `promoted`), YouTube `/youtubei/v1/*` plus a setter trap on `ytInitialPlayerResponse` for the inlined first video.

Relevance to Facebook: **none.** Nora does not response-filter Facebook, because Facebook's mobile feed arrives server-rendered. Both apps fight Facebook in the DOM. This layer only pays off on sites SlimSocial does not wrap.

### Layer 3 — DOM

Nora hooks the same container SlimSocial does — `[data-tracking-duration-id]` on `m.facebook.com` — and tests it with a plain `textContent.includes()` against ~30 localised labels.

**SlimSocial's matcher is materially stricter:** a three-tier cascade (attribute → marker selector → text), a per-label length window, private-use and bidi character stripping, and a separate exact-match path so two-character CJK labels can be matched safely. Nora's bare `includes()` over a label as short as `"Ad"` is the false-positive mode SlimSocial's length gates exist to prevent. SlimSocial's label list is a superset of Nora's.

Four DOM techniques are nonetheless worth taking:

1. **Collapse without moving the feed.** Hiding a post above the viewport slides everything below it upward, and the feed jumps under the reader's thumb. Measure the scroller's height *and its offset* before hiding; if the post was entirely above the viewport, write the offset back as `offsetBefore - heightLost` in the same synchronous turn. Write it absolutely, not as a delta applied to the current offset: Android WebView has Chromium's scroll anchoring on by default (`overflow-anchor: auto`), so the engine may have already corrected the offset by the time the forced layout completes, and subtracting again moves the feed by a whole post in the wrong direction. Inside a scroll-snap container (Reels) the same bug additionally causes Chromium to re-snap to the *previous* clip.
2. **Verdict caching with mutation invalidation.** Scan a post once, stamp the result. Any DOM change inside the post drops the cached verdict, because Facebook inserts the "Sponsored" label *after* the post is inserted. SlimSocial's `slim-ad-checked` plus `isSettled` already approximates this; Nora's version is invalidation-driven rather than stability-driven.
3. **One sweep per frame.** Mutation records only *schedule* a `requestAnimationFrame`-coalesced sweep; nothing is scanned inline. This was Nora's fix for "Facebook hangs" (commit `d5ebc57`) — a batch holds hundreds of records touching the same handful of posts. SlimSocial's 250 ms debounce is close in effect.
4. **"Open in app" banner by structure, not text.** The banner is: exactly one `.native-text`, exactly one focusable button, a gradient container — and *no* form control, article or feed descendant. Locale-proof. SlimSocial's `hideAppUpsellCss` already uses the negative form-control guard; the positive structural test is the part not yet borrowed.

---

## 3. Where SlimSocial is ahead

Recorded so these are not accidentally traded away while porting.

- **Hostile-input discipline.** SlimSocial's JS channels validate everything: allowlisted diagnostic kinds, fields and values; integer bounds; describe-don't-quote logging so the page cannot exfiltrate through Sentry breadcrumbs. Nora's `onMessage` switch trusts payload shapes and logs freely.
- **Sponsored-label matching.** See §2, layer 3.
- **Selector health telemetry.** `no_posts_matched` / `filter_missing` mean SlimSocial *learns* when Facebook rewrites its markup. Nora finds out from GitHub issues. This is the instrument that de-risks every experiment below — particularly the user-agent one.
- **Load-retry policy.** Escalating delays tuned to observed wake-from-sleep failure sequences, including the iOS no-committed-navigation case. Nora reloads on renderer crash but has no equivalent for transient load failure.
- **Dark theme.** Luminance-based palette extraction from the page's own stylesheet, because Facebook renumbers its `bg-sN` surface classes per render. Nora's Facebook dark mode is whatever the site serves.

---

## 4. Adoption dossiers

Ordered by value ÷ cost.

### A. Video download — pure DOM scraping ✅ works with `webview_flutter`

**Corrects an assumption in [`2026-08-04-media-viewer-and-downloads.md`](../superpowers/plans/2026-08-04-media-viewer-and-downloads.md)**, which excludes video download on the grounds that MSE video exposes only a `blob:` URL and that supporting it would require intercepting network requests. It does not: the real HTTPS URLs are in the page.

Pipeline:

1. Normalise the URL first. Any `facebook.com/watch?v=<id>`, `/…/videos/…/<id>`, `/reel/<id>`, or `fb://fullscreen_video/<id>` collapses to one canonical page shape — the reel page — so there is a single DOM to scrape.
2. Collect candidates and score them:
   - `[data-video-url]` attributes — usually muxed with audio, moderate quality (score ~400).
   - `data-extra` JSON on the same nodes, walked recursively for `browser_native_hd_url` (520), `playable_url_quality_hd` (500), `browser_native_sd_url` (380), `playable_url` (360).
   - The raw document HTML and every `<script>.textContent`, regexed for the same keys — including the `"`-escaped variants, which is how they appear inside inlined JSON.
   - DASH `<BaseURL>` entries (also `<BaseURL>` escaped), scored by representation height, skipping `audio/*` mime types.
3. Decode escapes: `\/`→`/`, `&`→`&`, `/`→`/`, `&amp;`→`&`.
4. If the best DASH candidate (video-only) and the best progressive candidate (muxed) differ, **offer the choice**: "HD, no audio" vs "Standard quality, with audio". This is honest about Facebook's DASH split instead of silently saving a video with no sound.
5. Genuine `blob:` fallback: `fetch(blobUrl)` → `FileReader.readAsDataURL` → base64 over a JS channel → write to Downloads. Nora additionally keeps a small `Map` of recent `URL.createObjectURL` arguments so a revoked blob URL can still be saved without `fetch` — which also sidesteps strict `connect-src` policies that reject `blob:`.

**Cost:** 1–2 days, no new dependencies. All of it runs through `runJavaScript` plus one JS channel.

### B. Quality-of-life pack ✅ works with `webview_flutter`

- **Pinch-to-zoom.** Facebook ships `maximum-scale=1, user-scalable=no`. Rewrite the viewport meta, dropping those clauses. Text zoom cannot enlarge a posted screenshot; this can.
- **Text selection and image long-press.** Two CSS rules. The touch layout sets `user-select: none` on post text and `pointer-events: none` on feed images, which is why a photo cannot be long-pressed and a posted phone number cannot be copied.
- **Tracking-parameter stripping.** ~30 parameters (`fbclid`, `mibextid`, `referral_source`, `surface_type`, `utm_*`, `share_id`, `gclid`, `ref_src`, …) removed before sharing a URL, and again inside the page by wrapping `navigator.clipboard.writeText` so Facebook's own "Copy link" button also yields a clean URL.
- **`fb://` link rescue.** `fb://fullscreen_video/<id>` currently reaches the Custom Tab handler, which either hands the user to the official Facebook app or fails. Map it back to a web URL inside the webview.

**Cost:** ~½ day total.

*Nora also runs a system-wide Android clipboard listener that rewrites any copied social URL. Deliberately not adopted: a background clipboard reader is a large privacy surface for a small gain, and on modern Android it raises a visible paste notification.*

### C. Notifications without FCM ⚠️ needs one small platform channel

Nora's design needs no Facebook API, no push service and no separate login:

1. Read the session from the WebView cookie jar — `CookieManager.getCookie("https://m.facebook.com")` returns the header string. `webview_flutter`'s cookie manager is set-only, but this is a **five-line `MethodChannel`**; the full engine migration in dossier E is *not* a prerequisite.
2. Proceed only if `c_user` and `xs` are present, i.e. actually signed in.
3. `GET m.facebook.com/menu/bookmarks/` with those cookies and a mobile Chrome user agent. Parse the anchors: hrefs containing `/friends/center/requests`, `/messages`, `/groups`, `/notifications.php`; take the badge count from `aria-label`, `title` or the link text (`\b(\d+)\+?\b` after stripping commas).
4. Store last-seen counts per category; notify only when a count **rises**. Tapping opens the matching URL in the webview.
5. Schedule: foreground timer every ~5 minutes, background task at the OS floor of 15 minutes. Flutter equivalent: `workmanager` + `flutter_local_notifications`.

**Cost:** 2–3 days. **Ship behind an off-by-default toggle** — see the risk register.

### D. EasyList, in two stages

Nora's parser is deliberately limited, and that restraint is the insight — it keeps only what is cheap and safe to evaluate:

- **Host rules:** `||host^` anchored rules and hosts-file lines only. Any rule carrying `$domain=` scoping or `badfilter` is skipped, because a site-scoped rule must never become a global host block. No path matching, no regex rules — which is what keeps a match O(labels) per request.
- **Cosmetic rules:** `##selector` and `#@#exception` lines, skipping extended syntax (`:has-text(`, `+js(`, `:-abp-`, `:style(`, `:upward(`, `:xpath(`). These become one injected stylesheet.
- **Freshness:** honour each list's `! Expires:` header (default 4 days), revalidate with ETag / Last-Modified, background refresh at 7 days. Persist the merged parsed result stamped with a **parser version**, so changing the parser rebuilds from the cached raw lists rather than shipping a stale snapshot.
- **Never block the main thread:** Nora yields every 4,000 lines. Flutter's better answer is `compute()`.

**Stage 1 (available now, ~1 day):** fetch, parse and inject the *cosmetic* filters for facebook.com through the existing `injectCssFunc` pipeline.
**Stage 2 (after E, ~1 day):** feed the host set to `shouldInterceptRequest`.

Sources: `https://easylist.to/easylist/easylist.txt`, `https://easylist.to/easylist/easyprivacy.txt`.

### E. Engine migration: `webview_flutter` → `flutter_inappwebview` ⚠️ the wall itself

| Capability | Android API Nora uses | `flutter_inappwebview` equivalent |
|---|---|---|
| Host-level request blocking | `shouldInterceptRequest` → empty response | `shouldInterceptRequest` (Android) |
| Guards that beat page scripts | `WebViewCompat.addDocumentStartJavaScript` | `UserScript(injectionTime: AT_DOCUMENT_START)` — genuine document-start where `WebViewFeature.DOCUMENT_START_SCRIPT` exists, best-effort otherwise; real `WKUserScript` on iOS |
| Renderer crash → reload | `onRenderProcessGone` | `onRenderProcessGone` |
| Cookie read | `CookieManager.getCookie` | `CookieManager.getCookies()` |
| `window.open` popups | `setSupportMultipleWindows` + `onCreateWindow` | `onCreateWindow` |
| Package-name leak | `setRequestedWithHeaderOriginAllowList(∅)` | exposed as a setting |
| iOS blocking | — | `contentBlockers` → `WKContentRuleList` |

**Costs, honestly:** a larger dependency with its own bug tail, and re-verification of behaviour this codebase paid for once already — the load-retry hooks, fullscreen video via `setCustomWidgetCallbacks`, the file selector, geolocation prompts, text zoom. Doing D-stage-2, F or the `X-Requested-With` fix *without* it means hand-rolling platform channels against a WebView instance `webview_flutter` will not hand over — effectively a fork.

**Cost:** 3–5 days plus a device regression pass.

### F. WebRTC IP-leak guard ⚠️ needs document-start (E)

SlimSocial ships a proxy setting; WebRTC walks around it, because STUN discovers the real public address outside the page's HTTP stack. The guard:

- Patch `RTCPeerConnection` **on the prototype**, not via a subclass — a subclass hands the untouched constructor back to the page through its own prototype chain, and connections built from that gather everything.
- Force `iceTransportPolicy: 'relay'` in the constructor config and in `setConfiguration`.
- Filter `icecandidate` events to relay candidates only, wrapping listeners through a `WeakMap` so `removeEventListener` still works.
- Scrub non-relay `a=candidate:` lines from SDP in `createOffer` / `createAnswer` and in descriptions.

Must run at document start: once page scripts hold a reference to the original constructor, overriding the global is pointless.

*Also worth noting:* Nora drives its proxy through androidx `ProxyController`, which scopes the override to the WebView. That is cleaner than `native_flutter_proxy`, which sets a process-wide proxy.

### G. User-agent modernisation — a dated string is a standing risk

SlimSocial's feed agent claims Firefox 70 (2019). The codebase already carries the scar tissue: `removeBrowserNotSupportedCss` exists because Facebook serves a "browser not supported" notice to agents it considers dead.

Nora never fights that battle. It pins a **current Chrome agent** (142 at time of reading), updates it every release, and controls the served layout by **host** instead: every `www.facebook.com` navigation is rewritten to `m.facebook.com` while in mobile mode, and Messenger paths get a desktop Linux agent.

The existing comment in `consts.dart` is right that the agent decides which markup every injected selector must match — so this is an experiment, not an edit:

1. Add a "modern user agent" toggle, paired with the `www` → mobile-host rewrite in `onNavigationRequest`.
2. Watch the `no_posts_matched` diagnostic. **This is precisely what that signal was built for.**
3. Promote to default only if it stays quiet in the field.

Also available from the same file: a Google-OAuth shim (masks `navigator.webdriver`, stubs `window.chrome`) for the `disallowed_useragent` class of sign-in failure on third-party pages reached from Facebook links.

### H. Screen-time limits ✅ pure Dart

Per-service daily budgets with a PIN-gated lockout. A one-minute tick increments today's usage while the app is foregrounded; at the budget a full-screen overlay replaces the feed showing "used X of Y today"; the PIN allows a bypass for the rest of the day; usage prunes after seven days.

For an app called *Slim*Social, "use Facebook less" is on-thesis, cheap, and a listing feature. **Cost:** ~2 days.

### I. Settings export / import ✅ pure Dart

A versioned JSON envelope (`kind`, `version`, `appVersion`, `exportedAt`), with every section normalised field-by-field on import so a hand-edited or older file cannot leave holes in the store, and a newer-version file rejected with its own message. Users of the custom CSS / JS / user-agent fields stop losing their setups on reinstall. `share_plus` and `file_picker` are already dependencies. **Cost:** ~½ day.

### J. Long-term shelf — known, not scheduled

- **Multi-account.** androidx `ProfileStore` gives real cookie-jar isolation (WebView ≥ 114). Neither `webview_flutter` nor `flutter_inappwebview` exposes it — custom native either way. Nora goes further and reads Chromium's cookie SQLite directly, using a probe cookie to map a profile name to its on-disk directory, in order to export `cookies.txt`.
- **On-device translation.** Double-tap a post for an ML Kit translation card. The transferable part is the **build split**: a `full` / `foss` source-set pair isolating the GMS dependency so the F-Droid variant compiles it out. That is the pattern to copy if SlimSocial ever adds a GMS-touching feature while keeping an F-Droid build.
- **File-chooser accept types.** `params.acceptTypes` can carry extensions (`.jpg`), bare MIME types, or comma-separated lists in a single entry; Android's own `createIntent()` honours only the first and passes it to `setType()` verbatim, so an extension-based list leaves the picker with an invalid filter and no visible photos. SlimSocial currently ignores `acceptTypes` entirely and single-selects — a pure-Dart improvement is available since `FileSelectorParams` carries them.

---

## 5. Risk register

| Risk | Severity | Mitigation |
|---|---|---|
| AGPL contamination while porting | **Blocker** | §0. This document is the specification; write original Dart. |
| Notification poller looks like automated access to Facebook | Medium | Off by default; reuse the webview's own user agent; ≥15 min cadence; one lightweight page per poll; kill switch. |
| 2019 user agent stops being served the touch layout | Medium, rising | Dossier G now, while there is time to gather field data. |
| Engine-migration regressions | Medium | Branch; the existing test suite; a device checklist mirroring the existing plans. |
| EasyList rules matching Facebook's own hosts | Low | Never block main-frame requests; implement the `@@` specificity precedence; keep the toggle separate from the DOM filter. |

---

## 6. Suggested sequence

1. **QoL pack** (~½ day, no new deps) — dossier B.
2. **Video download** (~1–2 days, no new deps) — dossier A; supersedes the "not in scope" note in the media-viewer plan.
3. **Notifications** (~2–3 days, five-line cookie channel) — dossier C.
4. **Identity features** (~3 days, pure Dart) — screen-time limits (H), settings backup (I), user-agent experiment behind a toggle (G).
5. **Engine swap, then the locked doors** (~1–2 weeks) — dossier E, then EasyList host blocking (D2), WebRTC guard (F), `X-Requested-With` suppression, renderer-crash reload, `window.open` popups.

Cosmetic EasyList filtering (D, stage 1) can be slotted anywhere from step 2 onward, since it needs nothing from the engine swap.

---

## 7. Attribution

Nora is the work of [nonbili](https://github.com/nonbili) and its contributors, published under the AGPL-3.0. It is a well-engineered project and its source comments — which explain measured browser behaviour rather than restating code — were as useful as the code itself.

Code adopted from the techniques described here is written independently, per §0. That rule needs enforcing rather than asserting: on the first adoption (the collapse fix in `lib/utils/ad_filter.dart`) a review caught two comment blocks that had drifted into close paraphrases of Nora's own wording — same argument order, same coined phrase — even though the surrounding algorithm was independently written. They were rewritten before the change landed. **Treat prose as carefully as code when working from this document**: a comment explaining a technique is the easiest place for the upstream author's expression to survive, and it is the hardest place to notice it.
