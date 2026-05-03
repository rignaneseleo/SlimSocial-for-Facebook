# SlimSocial for Facebook — Native Kotlin Rewrite (2026)

**Status:** Design approved, pending implementation plan
**Date:** 2026-05-03
**Author:** Leonardo Rignanese, with Claude

## 1. Goal

Rewrite SlimSocial for Facebook from Flutter to native Android Kotlin, holding the original 2015 SlimSocial promise (lightweight, privacy-respecting, minimal permissions) while modernizing the architecture so the project is easy to maintain, debug, and extend in 2026.

## 2. Constraints (verbatim from product owner)

1. Should work on dated devices with old OS and low RAM
2. Should be lightweight
3. Should have **total** control over permissions
4. Should work globally
5. Should have clean code
6. Should be easy to debug and fix errors users hit
7. Should be customizable in-app from advanced users

## 3. Platform Decisions

| Decision | Choice | Reason |
|---|---|---|
| Language | **Kotlin** | Native control of `WebView` (Flutter's `webview_flutter` is a thin wrapper that loses key APIs); ~10× smaller APK; lower RAM; matches original "1MB, 0 permissions" spirit |
| Platforms | **Android only** | Owner's user base is Android; iOS not maintained today |
| `minSdk` | **24 (Android 7.0)** | API 24+ guarantees WebView is auto-updated as a separate Chrome component → users on a 2016 device get a 2026 WebView. ~96% device coverage. Going lower means stuck-old WebViews that break modern Facebook |
| `targetSdk` | **Latest stable at release time** | |
| UI framework | **Jetpack Compose (Material 3)** | The 2026 standard for native Android UI; clean, declarative, testable; ~2 MB overhead is acceptable given the user wants "pleasant to use and see" |
| Architecture | Single-Activity, MVVM, unidirectional data flow | |
| DI | **Manual constructor injection** (no Hilt) | App is small (~3–5k LOC); Hilt adds APK size and indirection without benefit at this scale |
| Async | Coroutines + Flow | No RxJava, no LiveData |
| Storage | DataStore Preferences | Async, type-safe, reactive |
| WebView | `androidx.webkit` + system `WebView` | Newer APIs available even on old OS |
| Module layout | Single Gradle module with strict package boundaries (`ui/`, `domain/`, `data/`, `webview/`) | |

## 4. Architecture

```
┌──────────────────────────────────────────────┐
│  UI (Compose screens + WebView host)         │  MainActivity, SettingsScreen, EditorScreen, LogScreen
├──────────────────────────────────────────────┤
│  ViewModels (state holders, no Android deps) │  Plain Kotlin, JVM-testable
├──────────────────────────────────────────────┤
│  Domain (use-cases, injection pipeline)      │  Pure logic: ad-blocking rules, CSS/JS composition
├──────────────────────────────────────────────┤
│  Data (settings store, log buffer, Sentry)   │  DataStore, in-memory ring buffer, Sentry SDK
└──────────────────────────────────────────────┘
```

### 4.1 Activity / WebView host

- One `MainActivity` hosts a classic `android.webkit.WebView` directly (not wrapped in Compose's `AndroidView`). Compose drives only Settings, Editor, Log Viewer, and dialogs.
- A `WebViewHost` class wraps the `WebView` with a clean Kotlin API: `load(url)`, `injectCss(rules)`, `injectJs(script)`, `setUserAgent(ua)`, `back()`, `reload()`, etc.
- Configuration is centralized in `WebViewHost.configure()`:
  - JavaScript and DOM storage enabled
  - Persistent cookie manager; third-party cookies allowed only for the FB origin
  - `LOAD_DEFAULT` cache mode with disk cache
  - Hardware acceleration on
  - Mixed content disabled
  - `setAllowFileAccess(false)` and `setAllowContentAccess(false)` (defense in depth)
  - Safe Browsing on
  - `WebViewClient.onRenderProcessGone` handled → log + show inline reload UI without crashing the host process

### 4.2 Injection pipeline

```kotlin
interface InjectionRule {
    val id: String                           // "hide_ads", "dark_theme", "user_custom_css_1"
    val enabled: Flow<Boolean>               // reactive to settings changes
    fun cssFor(url: String): String?         // null = doesn't apply to this URL
    fun jsFor(url: String): String?
}
```

- Built-in rules (`HideAdsRule`, `DarkThemeRule`, `RecentFirstRule`, `FixedBarRule`, `HideStoriesRule`, `CenterTextPostsRule`, etc.) and user custom snippets are all `InjectionRule`s. Same code path; no special-case branching.
- A `WebViewClient.onPageCommitVisible` and `onPageFinished` collect all enabled rules, compose **one** `<style>` block + **one** JS function, inject once per navigation.
- Each rule unit-testable in isolation: assert `cssFor("https://m.facebook.com/...")` returns the expected string; no real WebView required.

### 4.3 URL routing

A `UrlRouter` decides per-URL: load in-app, hand off to Custom Tabs (external links), open Messenger (separate WebView or external app per setting), or block. Centralized so "why did this link open weirdly?" has one place to look.

## 5. Settings & Customization

### 5.1 Storage

- DataStore Preferences (single `Preferences` instance) is the only persistence layer.
- All reads/writes go through `SettingsRepository` exposing `Flow<Settings>` and `suspend fun update(...)`. Nothing else reads DataStore directly.

### 5.2 Data model

```kotlin
data class Settings(
    val webView: WebViewSettings,        // userAgent, useMbasic, customProxy
    val features: FeatureToggles,        // hideAds, recentFirst, enableMessenger
    val style: StyleToggles,             // darkTheme, fixedBar, hideStories,
                                         //   centerTextPosts, addSpaceBetweenPosts
    val permissions: PermissionGrants,   // gps, camera, photo, mic, notifications
    val customization: CustomCode,
    val privacy: PrivacySettings,        // sentryEnabled, debugMode
)

data class CustomCode(
    val cssEntries: List<NamedSnippet>,
    val jsEntries: List<NamedSnippet>,
    val activeCssIds: Set<String>,
    val activeJsIds: Set<String>,
)

data class NamedSnippet(
    val id: String,
    val name: String,
    val code: String,
    val updatedAt: Long,
)
```

This shape pre-positions the deferred sharable-presets feature: a `.slim` export is `Json.encodeToString(snippets)`. No data-model rework when feature B ships.

### 5.3 Reactivity

Toggling a setting → DataStore flow emits → ViewModel emits new state → `WebViewHost` re-injects automatically. No manual reload required.

### 5.4 Migration from Flutter

On first launch of the rewrite, check for the legacy Flutter `SharedPreferences` XML at `/data/data/it.rignanese.leo.slimfacebook/shared_prefs/FlutterSharedPreferences.xml`. If present:

1. Parse it once
2. Map known keys to the new `Settings` shape (custom CSS, custom JS, hideAds, recentFirst, useMbasic, all `style/*` toggles, custom UA, custom proxy, donation flag)
3. Write into DataStore
4. Rename the legacy file with a `.migrated` suffix so it isn't re-read

Same `applicationId` (`it.rignanese.leo.slimfacebook`) → users keep their stuff on update.

### 5.5 Customization scope (v1 = "A")

- Multiple **named CSS snippets** and **named JS snippets** with enable/disable per snippet
- In-app editor with: monospace font, line numbers, basic syntax-error highlight (regex-based for `{` `}` balance, no full parser), undo/redo, "test" button that injects to the live WebView temporarily before save
- "Reset to defaults" per snippet; export single snippet as plain text
- **Deferred (feature B, separate spec):** `.slim` import/export bundles, public preset library

### 5.6 Safety — custom JS warnings

- First time a user enables any custom JS snippet: blocking dialog requiring explicit "I understand" tap.
- Editor screen for JS snippets shows a persistent yellow header strip explaining that JS runs with full Facebook-session DOM access.
- CSS snippets show a milder note about `url(http://...)` referer leakage.
- For the future preset import flow (feature B): the warning dialog must show on **every** import, not once.

## 6. Permissions ("total control")

### 6.1 Default state

Every Android runtime permission is **off** at first launch. Manifest declares the permissions the WebView might request (`CAMERA`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `RECORD_AUDIO`, `POST_NOTIFICATIONS`) but nothing is auto-requested.

### 6.2 Two-layer gate

1. **App-level toggle** in Settings → Permissions, off by default.
2. **OS-level prompt**, triggered only when the user enables the app-level toggle. If the OS prompt is denied, the app-level toggle reverts to off automatically — no orphan "enabled in app, denied by OS" state.

### 6.3 WebView delegation

- `WebChromeClient.onPermissionRequest(req)` consults the gate. If the matching app-toggle is off, deny **without** showing any system prompt. Facebook cannot pop a dialog the user did not ask for.
- `WebChromeClient.onGeolocationPermissionsShowPrompt(...)` likewise checks the GPS app-toggle.
- `WebChromeClient.onShowFileChooser(...)` routes through the storage permission gate; uses Storage Access Framework (no broad storage permission needed on API 24+).

### 6.4 Settings UI

Each permission row shows three explicit states:
- **Off**
- **On (granted)**
- **On (denied by OS — tap to fix)** → opens system settings deep-link

Each row has an inline "?" expandable explainer of what FB does with the permission.

### 6.5 Notifications

`POST_NOTIFICATIONS` is off by default on API 33+. The app itself sends zero notifications; this permission only exists to forward FB's web push notifications when the user wants them.

## 7. Logging & Debugging

Three concentric layers, each opt-in deeper than the last.

### 7.1 Layer 1 — In-memory ring buffer (always on)

`LogBuffer` retains the last ~500 events:
- App lifecycle transitions
- Navigations (URL with query string stripped)
- Injection events (which rules applied, byte sizes)
- WebView console messages (via `WebChromeClient.onConsoleMessage`)
- Permission requests (granted/denied)
- Render process gone events
- Sentry events that were sent (in `full` flavor)

PII redaction is on by default: query strings dropped from URLs; cookies never recorded; FB session identifiers (`c_user`, `xs`, `fr`, etc.) redacted from any structured field they might appear in.

### 7.2 Layer 2 — In-app debug screen (Settings → Debug)

A Compose screen with:
- Live tail of `LogBuffer` (auto-scroll, pause, filter by category)
- State snapshot: WebView Chrome major version, current user-agent, current URL, active CSS rule IDs, active JS rule IDs, proxy state, permission grants
- **Export log** → shares a redacted `.txt` via the system share sheet
- **Send to dev** → uses the existing channel, attaches the log
- **Reproduce mode** toggle → bumps verbosity for the session, captures network failures and JS errors with stack traces

The debug screen is always visible in Settings (no tap-7-times). Verbose "reproduce mode" is the only opt-in switch.

### 7.3 Layer 3 — Sentry (`full` flavor only, opt-out)

- **Stripped from `fdroid` flavor at build time** via source-set + `BuildConfig` flags. The F-Droid build does not contain Sentry classes or any URL pointing to Sentry's servers.
- `beforeSend` hook scrubs:
  - All cookie names and values
  - FB session identifiers (`c_user`, `xs`, `fr`, `presence`, `wd`, `dpr`, `sb`, `datr`) anywhere in the event
  - Request bodies
  - Auto-screenshots are disabled entirely
- Sample rates: errors **100%**, transactions **0%**, sessions **0%** — to stay within the Sentry free plan (5,000 errors/month). Aggressive ignore-list for known-noisy WebView 4xx and recoverable network errors.
- Settings UI: "Send anonymous crash reports" toggle on by default (opt-out), with a link to a plain-language description of what is and isn't sent.
- `release` and `dist` set from `versionName`/`versionCode` so reports correlate to commits.

### 7.4 Crash recovery (user-facing payoff)

When the WebView render process is killed (common on low-RAM devices), the app:
1. Catches it via `WebViewClient.onRenderProcessGone`
2. Logs the event to `LogBuffer` and Sentry (full flavor)
3. **Does not crash the host process**
4. Shows an inline "Facebook stopped responding — Reload?" UI with one-tap recovery

This alone should eliminate a large fraction of "the app crashes on my old phone" reports.

## 8. Build Flavors

```kotlin
flavorDimensions += "store"
productFlavors {
    create("full")   { dimension = "store" }   // Play Store
    create("fdroid") { dimension = "store" }   // F-Droid
}
```

Same `applicationId` (`it.rignanese.leo.slimfacebook`).

### 8.1 Source-set differences

- `src/full/`
  - Sentry SDK
  - Google Play Billing for in-app donations
  - Google Play In-App Review API
- `src/fdroid/`
  - **No-op stubs** of the same interfaces (`CrashReporter`, `BillingClient`, `ReviewLauncher`)
  - Donation screen replaced with PayPal / GitHub Sponsors links
- `src/main/` only references the interfaces. The flavor decides the implementation.

### 8.2 CI (GitHub Actions)

- **PR:** Lint + unit tests + Robolectric tests + build both flavors (debug)
- **Tag `v*`:**
  - Build signed `full` AAB → upload to Play Internal track
  - Build signed `fdroid` APK → attach to GitHub Release; F-Droid build server picks it up from the tag
- Reproducible builds enabled (matters for F-Droid auto-build verification)

## 9. Internationalization & Network

### 9.1 i18n

- Standard Android `res/values/strings.xml`, `res/values-it/`, `res/values-de/`, etc.
- `easy_localization` (Flutter-only) is dropped.
- Translations live in version control, contributable via PR.
- A migration to Weblate or Crowdin is a possible follow-up if community translations grow; not in v1.

### 9.2 Custom proxy ("work globally" — network)

- HTTP and SOCKS5 proxy configurable per-app via AndroidX `ProxyController.setProxyOverride(...)`.
- DNS-over-HTTPS is **not** in v1 (rabbit hole; revisit if real-world demand surfaces).
- Geo-blocking by Facebook itself is out of scope.

## 10. Testing strategy

The product owner explicitly asked for "lots of tests." Targets:

### 10.1 Unit tests (JVM, fast — must run in <10s on CI)

| Component | Coverage target | Notes |
|---|---|---|
| `domain/` (rules, router, composer) | **≥90%** | Every `InjectionRule` gets a test; `UrlRouter` gets tests per URL pattern |
| `data/` (`SettingsRepository`, `LogBuffer`, Sentry scrubber) | **≥90%** | Every redaction rule asserted with concrete inputs |
| ViewModels | **≥85%** | State-transition tests: action in → state out |
| `webview/` host (interface boundary only) | smoke + interface tests | Real `WebView` not testable on JVM |

### 10.2 Robolectric tests

- Permission gate logic (every state transition: off → on-granted → on-denied)
- `WebChromeClient` callback delegation (camera, geolocation, file chooser, console message)
- Render-process-gone recovery flow

### 10.3 Instrumented tests (Android emulator, ≤10 tests)

- App launches and reaches Facebook home
- Settings persist across process death
- Flutter → Kotlin migration on a fixture XML produces correct `Settings`
- Custom CSS toggle round-trip (enable → restart → still enabled)

### 10.4 Manual test matrix per release

Documented in `TESTING.md`. Required before tagging:
- API 24, 28, 33, 35 emulators
- Real low-RAM device (~2 GB RAM, owner-supplied)
- Both `full` and `fdroid` debug builds smoke-tested
- Migration tested by side-loading over the current Flutter build

### 10.5 Test infrastructure

- JUnit 5 + Kotest assertions
- Turbine for Flow testing
- MockK (lighter than Mockito for Kotlin)
- Robolectric for `Activity`-less Android
- AndroidX Test for instrumented

No Espresso UI tests for the WebView contents — those are Facebook's HTML, not ours, and would be brittle.

## 11. Out of Scope (deferred)

- Sharable `.slim` preset bundles (feature B from brainstorming)
- DNS-over-HTTPS
- iOS port
- Weblate/Crowdin community translations
- Self-hosted Sentry alternative
- Per-element "tap to hide" content blocker

## 12. Migration & Release Plan

1. Rewrite is developed in a parallel branch; the existing Flutter codebase keeps shipping bugfix releases until the Kotlin rewrite hits parity.
2. First Kotlin release goes to a Play Store internal track for owner-only testing.
3. Beta channel for ~2 weeks with explicit upgrade-from-Flutter testing on the owner's real devices.
4. Stable release. Existing users are upgraded via Play Store update; settings migrate transparently on first launch.
5. F-Droid release follows the same tag.

## 13. Success Criteria

- APK size ≤ 5 MB (`fdroid` flavor) and ≤ 7 MB (`full` flavor)
- Cold start to interactive WebView ≤ 1.5 s on a 2 GB RAM device on API 24
- Idle RAM ≤ 80 MB
- Zero permissions granted at first launch
- Existing Flutter user upgrades without losing custom CSS, custom JS, or any toggle
- F-Droid build contains no Google Play, Sentry, or other proprietary classes (verified by APK inspection)
- Unit + Robolectric tests run green in CI in under 60 s total
