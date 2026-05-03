# SlimSocial for Facebook — Kotlin Rewrite Implementation Plan

**Companion to:** [`2026-05-03-kotlin-rewrite-design.md`](./2026-05-03-kotlin-rewrite-design.md)
**Style:** Each phase is self-contained, executable in a fresh session. Phases must be done in order unless marked parallelizable. Every phase ends with a verification checklist that must pass before moving on.

---

## Spec corrections (from Phase 0 research)

The following supersede the spec where they conflict:

| Spec said | Corrected | Reason |
|---|---|---|
| Proxy supports HTTP and SOCKS5 | Proxy supports **HTTP and HTTPS only** (`ProxyController`); SOCKS5 deferred to a future VPNService implementation | `androidx.webkit ProxyController` does not document SOCKS5 |
| WebView hosted as a real `View`, not `AndroidView` | WebView hosted via Compose `AndroidView { factory = { WebView(it) } }` | Google's 2026 strategy doc: do not mix `setContentView(xml)` with `setContent { }`; `AndroidView` is the supported interop |
| Dark theme via `setForceDark` | `WebSettingsCompat.setAlgorithmicDarkeningAllowed(settings, true)` gated by `WebViewFeature.ALGORITHMIC_DARKENING` | `setForceDark` deprecated since API 33 / webkit 1.6 |

---

## Phase 0 — Documentation Discovery (consolidated findings)

**This phase is COMPLETE.** Findings below are the canonical reference for all later phases. Re-fetch only if a phase fails because of a doc mismatch.

### 0.1 Allowed Android WebView APIs

**WebView settings (Kotlin properties, all stable since API 21–24):**
- `webView.settings.javaScriptEnabled = true`
- `webView.settings.domStorageEnabled = true`
- `webView.settings.cacheMode = WebSettings.LOAD_DEFAULT`
- `webView.settings.allowFileAccess = false`
- `webView.settings.allowContentAccess = false`
- `webView.settings.mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW`
- `webView.settings.builtInZoomControls = true; displayZoomControls = false`

**DEPRECATED — DO NOT USE:** `setAppCacheEnabled` (no-op since API 33), `setSaveFormData`, `setDatabaseEnabled`, `setForceDark`.

**WebChromeClient callbacks (verified signatures):**
```kotlin
override fun onPermissionRequest(request: PermissionRequest)
override fun onGeolocationPermissionsShowPrompt(origin: String, callback: GeolocationPermissions.Callback)
override fun onShowFileChooser(
    webView: WebView,
    filePathCallback: ValueCallback<Array<Uri>>,
    fileChooserParams: FileChooserParams
): Boolean
override fun onConsoleMessage(message: ConsoleMessage): Boolean
override fun onShowCustomView(view: View, callback: CustomViewCallback)
override fun onHideCustomView()
```

**`PermissionRequest` resource constants (use as exact strings):**
```
PermissionRequest.RESOURCE_AUDIO_CAPTURE       = "android.webkit.resource.AUDIO_CAPTURE"
PermissionRequest.RESOURCE_VIDEO_CAPTURE       = "android.webkit.resource.VIDEO_CAPTURE"
PermissionRequest.RESOURCE_MIDI_SYSEX          = "android.webkit.resource.MIDI_SYSEX"
PermissionRequest.RESOURCE_PROTECTED_MEDIA_ID  = "android.webkit.resource.PROTECTED_MEDIA_ID"
```

**WebViewClient render-process-gone (API 26+):**
```kotlin
override fun onRenderProcessGone(view: WebView, detail: RenderProcessGoneDetail): Boolean {
    // Return true to handle; return false to let host crash.
    // detail.didCrash() == false → reaped by system (recoverable)
    // detail.didCrash() == true  → renderer internal crash
}
```

**androidx.webkit 1.15.0+ features (gated via `WebViewFeature.isFeatureSupported(...)`):**
- `PROXY_OVERRIDE` — HTTP/HTTPS proxy only (no SOCKS5)
- `ALGORITHMIC_DARKENING` — replaces `setForceDark`
- `SAFE_BROWSING_ENABLE`, `START_SAFE_BROWSING`
- `DOCUMENT_START_SCRIPT` — inject JS before page parses
- `WEB_MESSAGE_LISTENER`, `POST_WEB_MESSAGE`
- `VISUAL_STATE_CALLBACK`

**ProxyController API:**
```kotlin
ProxyController.getInstance().setProxyOverride(
    ProxyConfig.Builder()
        .addProxyRule("http://proxy.host:port")
        .addBypassRule("*.fb.local")
        .removeImplicitRules()
        .build(),
    Executor { it.run() },
    Runnable { /* applied */ }
)
```

**CookieManager:**
```kotlin
CookieManager.getInstance().setAcceptCookie(true)
CookieManager.getInstance().setAcceptThirdPartyCookies(webView, true) // single global toggle
CookieManager.getInstance().flush() // call from onPause
```
Per-origin third-party cookie allowlisting is **not available**. The Facebook origin gets third-party cookies enabled globally (acceptable; the WebView only ever loads FB content).

### 0.2 Allowed Compose / DataStore APIs

**Compose hosting:** Single Activity, `setContent { ... }`, WebView via `AndroidView`. Reference: developer.android.com/develop/ui/compose/migrate/interoperability-apis/views-in-compose

**DataStore Preferences:**
```kotlin
val Context.dataStore by preferencesDataStore(name = "settings")
val NIGHT_MODE = booleanPreferencesKey("night_mode")
context.dataStore.data.map { it[NIGHT_MODE] ?: false }       // Flow<Boolean>
context.dataStore.edit { it[NIGHT_MODE] = true }              // suspend
```

**Permissions runtime:**
```kotlin
private val launcher = registerForActivityResult(
    ActivityResultContracts.RequestPermission()
) { granted -> ... }
launcher.launch(Manifest.permission.CAMERA)

// "permanently denied" detection:
// shouldShowRequestPermissionRationale() == false AND not first-time-asked
```

**Compose permissions:** `com.google.accompanist:accompanist-permissions:0.34.0+` provides `rememberPermissionState(...)`, `rememberMultiplePermissionsState(...)`. Annotated `@OptIn(ExperimentalPermissionsApi::class)`.

### 0.3 Allowed Sentry / Billing / Play APIs

**Sentry init (programmatic, opt-out in fdroid via build flavor):**
```kotlin
SentryAndroid.init(this) { options ->
    options.dsn = BuildConfig.SENTRY_DSN
    options.release = "${BuildConfig.APPLICATION_ID}@${BuildConfig.VERSION_NAME}+${BuildConfig.VERSION_CODE}"
    options.dist = BuildConfig.VERSION_CODE.toString()
    options.isSendDefaultPii = false
    options.tracesSampleRate = 0.05
    options.sampleRate = 1.0          // errors 100% (default)
    options.setBeforeSend { event, _ -> scrub(event) }
}
```
Manifest must contain `<meta-data android:name="io.sentry.auto-init" android:value="false" />` so `init()` runs on our terms.

**Free tier limits (Sentry Developer 2026):** 5,000 errors/mo, 5M spans/mo, 50 replays/mo, 30-day retention.

**Play Billing v8 (Kotlin):**
- Dependency: `com.android.billingclient:billing-ktx:8.3.0`
- `BillingClient.newBuilder(context).enableAutoServiceReconnection().enablePendingPurchases(...).setListener(...).build()`
- Non-consumable purchase: `acknowledgePurchase()` — DO NOT consume.

**Play In-App Review:** `com.google.android.play:review-ktx:2.0.2`. `ReviewManagerFactory.create(ctx).requestReviewFlow().addOnCompleteListener { ... }`. Quota is opaque.

### 0.4 F-Droid metadata format

Path: `metadata/it.rignanese.leo.slimfacebook.yml` (in repo root, separate PR to fdroiddata).
```yaml
Categories: [Internet]
License: GPL-2.0-only
SourceCode: https://github.com/rignaneseleo/SlimSocial-for-Facebook
IssueTracker: https://github.com/rignaneseleo/SlimSocial-for-Facebook/issues
Changelog: https://github.com/rignaneseleo/SlimSocial-for-Facebook/blob/master/Changelog.txt
RepoType: git
Repo: https://github.com/rignaneseleo/SlimSocial-for-Facebook
Builds:
  - versionName: '2026.1.0'
    versionCode: 200
    commit: v2026.1.0
    subdir: app
    gradle: [fdroid]
AutoUpdateMode: Version
UpdateCheckMode: Tags
```

### 0.5 Existing Flutter behavior to preserve verbatim

**Settings keys (22) and defaults — migration target:**

| Legacy key | Type | Default | Notes |
|---|---|---|---|
| `enable_messenger` | bool | **true** | |
| `hide_ads` | bool | **true** | |
| `recent_first` | bool | false | Adds `?sk=h_chr` URL suffix |
| `use_mbasic` | bool | false | Switches host to `mbasic.facebook.com` |
| `gps_permission` | bool | false | Maps to runtime location perm |
| `camera_permission` | bool | false | |
| `photo_permission` | bool | false | (singular) |
| `photos_permission` | bool | false | (plural — different key, used by file picker) |
| `dark_theme` | bool | false | CSS toggle |
| `fixed_bar` | bool | **true** | CSS toggle |
| `hide_stories` | bool | false | CSS toggle |
| `center_text` | bool | false | CSS toggle |
| `add_space` | bool | false | CSS toggle |
| `hide_messenger_sidebar` | bool | **true** | CSS toggle (no UI in current Flutter app — implicit) |
| `custom_useragent_enabled` | bool | false | |
| `custom_useragent` | string | "" | |
| `custom_js_enabled` | bool | false | |
| `custom_js` | string | "" | |
| `custom_css_enabled` | bool | false | |
| `custom_css` | string | "" | |
| `custom_proxy_enabled` | bool | false | |
| `custom_proxy_ip` | string | "" | |
| `custom_proxy_port` | string | "" | |

Legacy XML lives at: `/data/data/it.rignanese.leo.slimfacebook/shared_prefs/FlutterSharedPreferences.xml`. Each `<boolean>`/`<string>` element has `name="flutter.<key>"` (note the `flutter.` prefix that `shared_preferences` adds).

**URLs (verbatim from `lib/consts.dart`):**
```kotlin
const val URL_TOUCH = "https://touch.facebook.com/home.php"
const val URL_MBASIC = "https://mbasic.facebook.com/home.php"
const val SUFFIX_RECENT = "?sk=h_chr"
const val SUFFIX_DEFAULT = "?sk=h_nor"

// User agents
const val UA_FIREFOX = "Mozilla/5.0 (Android 13; Mobile; rv:109.0) Gecko/119.0 Firefox/119.0"
const val UA_OPERA_MINI = "Opera/9.80 (Android; Opera Mini/12.0.0/37.6817; U; en) Presto/2.12.423 Version/12.16"
// (Verify exact strings against SlimSocial_for_Facebook/lib/consts.dart:22-27 at port time)
```

**Permitted hostnames:**
- FB: `facebook.com`, `fb.com`, `fb.me`
- Messenger: `messenger.com`, `m.me`

**CSS injection rules to port (from `lib/utils/css.dart`):**

| Rule key | Default | Source lines |
|---|---|---|
| `center_text` | false | css.dart:14-18 |
| `hide_messenger_sidebar` | **true** | css.dart:20-26 |
| `add_space` | false | css.dart:28-32 |
| `hide_stories` | false | css.dart:34-38 |
| `fixed_bar` | **true** | css.dart:40-46 |
| `removeMessengerDownload` | false | css.dart:48-53 |
| `removeBrowserNotSupported` | false | css.dart:55-59 |
| `hideAdsAndPeopleYouMayKnow` | false | css.dart:61-66 |
| `fabBtn` | false | css.dart:68-73 |
| `adaptMessenger` | false | css.dart:75-172 |
| `dark_theme` (FB) | false | css.dart:218-511 |
| `dark_theme_messenger` | false | css.dart:181-216 |

**JS rules to port (from `lib/utils/js.dart`):**

| Function | Source lines | Purpose |
|---|---|---|
| `injectCssFunc` | 4-13 | Wraps CSS in `<style>` and appends to `<head>` |
| `removeAdsFunc` | 21-92 | Filters `<span>` by 23-language sponsor keyword list, replaces parent `<article>` HTML |
| `removeAdsObserver` | 94-118 | `MutationObserver` to re-run ad removal on dynamically inserted posts |
| `createFabFunc` | 121-135 | Floating scroll-to-top button |

**Sponsor keywords (full list — port to a Kotlin `const val` array, no translations):**
French `Sponsorisé`, English `Sponsored`, Spanish `Patrocinado` `Publicidad`, German `Gesponsert`, Italian `Sponsorizzato`, Swedish `Sponsrad`, Vietnamese `Được tài trợ`, Chinese (Trad) `贊助內容`, Chinese (Simp) `赞助内容`, Japanese `スポンサーされた投稿`, Polish `Sponsorowane`, Russian `Реклама`, Croatian `Sponzorirano`, Hindi `प्रायोजित`, Bengali `স্পনসরড`, Tamil `பராமரிக்கப்பட்ட`, Telugu `ప్రచారం చేసిన`, Kannada `ಪ್ರಾಯೋಜಿತ`, Malayalam `സ്പോൺസർ ചെയ്യപ്പെട്ട`, Punjabi `ਸਰਪ੍ਰਸਤ`, Marathi `प्रायोजित`, Gujarati `સ્પોન્સર્ડ`, Urdu `سپانسرڈ`, Thai `โพสต์ที่ได้รับการสนับสนุน`.

**Donation product IDs (Play Console managed; full flavor only):**
`donation_1`, `donation_2`, `donation_3`, `donation_4` — non-consumable.

**i18n:** 47 locales under `assets/lang/<locale>.json`, ~70 keys per locale. All keys flat (no nesting). English reference: `assets/lang/en-US.json`.

**AndroidManifest intent filters to replicate:** see `SlimSocial_for_Facebook/android/app/src/main/AndroidManifest.xml:30-81` — 22 wildcard hosts + 22 exact hosts under `http`/`https` schemes, `android:autoVerify="true"`.

---

## Phase 1 — Project bootstrap

**Goal:** New Kotlin Android module compiles, both flavors, empty MainActivity displays "Hello SlimSocial."

**What to implement:**

1. Create new Gradle module at `app/` (sibling of existing `SlimSocial_for_Facebook/`). Do NOT delete or modify the Flutter project — it keeps shipping bugfixes until parity.
2. `app/build.gradle.kts` (Kotlin DSL):
   - `compileSdk = 36`, `minSdk = 24`, `targetSdk = 36` (or latest stable at execution time)
   - `applicationId = "it.rignanese.leo.slimfacebook"` (same as Flutter app for seamless upgrade)
   - `versionCode` from `../SlimSocial_for_Facebook/pubspec.yaml` `version` field +1; `versionName` matches
   - Kotlin `2.x`, `compose = true`, `composeOptions.kotlinCompilerExtensionVersion` matching latest stable
   - `flavorDimensions += "store"`, `productFlavors { create("full") { dimension = "store" }; create("fdroid") { dimension = "store" } }`
   - Java/Kotlin target 17
3. `settings.gradle.kts` at root: include `:app`, leave Flutter app untouched
4. Top-level `build.gradle.kts` with AGP, Kotlin, Compose plugin versions in `plugins { ... apply false }`
5. Dependencies (in `app/build.gradle.kts`):
   ```kotlin
   implementation("androidx.core:core-ktx:1.13.+")
   implementation("androidx.activity:activity-compose:1.9.+")
   implementation("androidx.compose:compose-bom:2024.10.+")
   implementation("androidx.compose.material3:material3")
   implementation("androidx.compose.ui:ui")
   implementation("androidx.compose.ui:ui-tooling-preview")
   debugImplementation("androidx.compose.ui:ui-tooling")
   implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.+")
   implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.+")
   implementation("androidx.datastore:datastore-preferences:1.1.+")
   implementation("androidx.webkit:webkit:1.15.+")
   implementation("com.google.accompanist:accompanist-permissions:0.34.+")
   implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.+")

   testImplementation("org.junit.jupiter:junit-jupiter:5.11.+")
   testImplementation("io.kotest:kotest-assertions-core:5.9.+")
   testImplementation("app.cash.turbine:turbine:1.1.+")
   testImplementation("io.mockk:mockk:1.13.+")
   testImplementation("org.robolectric:robolectric:4.13")
   testImplementation("androidx.test:core-ktx:1.6.+")
   testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.8.+")
   ```
6. Skeleton `MainActivity.kt`:
   ```kotlin
   class MainActivity : ComponentActivity() {
       override fun onCreate(savedInstanceState: Bundle?) {
           super.onCreate(savedInstanceState)
           setContent { Material3HelloScreen() }
       }
   }
   ```
7. Empty `AndroidManifest.xml` declaring `MainActivity` as launcher; **do NOT** copy intent filters yet (Phase 12)
8. Empty `src/full/AndroidManifest.xml` and `src/fdroid/AndroidManifest.xml` (will be filled later)
9. JUnit5 platform: `test { useJUnitPlatform() }`

**Documentation references:**
- AGP variants: developer.android.com/build/build-variants
- Compose BOM versions: developer.android.com/jetpack/compose/bom

**Verification checklist:**
- [ ] `./gradlew :app:assembleFullDebug` succeeds
- [ ] `./gradlew :app:assembleFdroidDebug` succeeds
- [ ] `./gradlew :app:testFullDebugUnitTest` runs (zero tests is OK)
- [ ] APK installs and launches on API 24 emulator showing "Hello SlimSocial"
- [ ] Both flavor APKs have applicationId `it.rignanese.leo.slimfacebook`
- [ ] `grep -r "io.sentry\|com.android.billingclient\|com.google.android.play" app/build.gradle.kts` returns 0 hits (those land in Phase 10)

**Anti-pattern guards:**
- DO NOT add Hilt — manual DI per spec §3
- DO NOT add Sentry, Billing, or Play Review dependencies yet — they go in Phase 10's flavor source sets only
- DO NOT touch the Flutter project
- DO NOT use `setContentView(xml)` — Compose only via `setContent { }`

---

## Phase 2 — Domain core (pure Kotlin, no Android imports)

**Goal:** All pure-logic types exist and are 90%+ unit-tested. Zero Android dependencies in this package.

**What to implement (under `app/src/main/java/it/rignanese/leo/slim/domain/`):**

1. `Settings.kt` — data classes mirroring spec §5.2:
   ```kotlin
   data class Settings(
       val webView: WebViewSettings,
       val features: FeatureToggles,
       val style: StyleToggles,
       val permissions: PermissionGrants,
       val customization: CustomCode,
       val privacy: PrivacySettings,
   ) {
       companion object { val DEFAULT = Settings(...) }  // matches Phase 0.5 default-true keys
   }

   data class FeatureToggles(
       val enableMessenger: Boolean = true,   // legacy default TRUE
       val hideAds: Boolean = true,           // legacy default TRUE
       val recentFirst: Boolean = false,
       val useMbasic: Boolean = false,
   )

   data class StyleToggles(
       val darkTheme: Boolean = false,
       val fixedBar: Boolean = true,                  // legacy TRUE
       val hideStories: Boolean = false,
       val centerText: Boolean = false,
       val addSpace: Boolean = false,
       val hideMessengerSidebar: Boolean = true,      // legacy TRUE
       val darkThemeMessenger: Boolean = false,
       val removeMessengerDownload: Boolean = false,
       val removeBrowserNotSupported: Boolean = false,
       val hideAdsAndPeopleYouMayKnow: Boolean = false,
       val fabBtn: Boolean = false,
       val adaptMessenger: Boolean = false,
   )

   data class PermissionGrants(
       val gps: Boolean = false,
       val camera: Boolean = false,
       val photo: Boolean = false,
       val photos: Boolean = false,    // separate from `photo`, see legacy keys
       val mic: Boolean = false,
       val notifications: Boolean = false,
   )

   data class CustomCode(
       val cssEntries: List<NamedSnippet> = emptyList(),
       val jsEntries: List<NamedSnippet> = emptyList(),
       val activeCssIds: Set<String> = emptySet(),
       val activeJsIds: Set<String> = emptySet(),
   )
   data class NamedSnippet(
       val id: String,
       val name: String,
       val code: String,
       val updatedAt: Long,
   )

   data class WebViewSettings(
       val customUserAgent: String? = null,           // null = use default per useMbasic
       val customProxyEnabled: Boolean = false,
       val customProxyHost: String = "",
       val customProxyPort: String = "",
   )

   data class PrivacySettings(
       val sentryEnabled: Boolean = true,             // opt-out, only honored in full flavor
       val debugMode: Boolean = false,                // verbose log capture
       val customJsAcknowledged: Boolean = false,     // one-time JS warning flag
   )
   ```

2. `InjectionRule.kt`:
   ```kotlin
   interface InjectionRule {
       val id: String
       fun cssFor(url: String): String? = null
       fun jsFor(url: String): String? = null
   }
   ```
   Pure interface — no `Flow` here (reactivity is composed externally; rules are immutable functions of URL and config).

3. `InjectionComposer.kt` — composes a list of rules into one `<style>` block + one JS function:
   ```kotlin
   class InjectionComposer {
       fun compose(rules: List<InjectionRule>, url: String): InjectionPayload {
           val css = rules.mapNotNull { it.cssFor(url) }.joinToString("\n")
           val js = rules.mapNotNull { it.jsFor(url) }.joinToString(";\n")
           return InjectionPayload(css, js)
       }
   }
   data class InjectionPayload(val css: String, val js: String)
   ```

4. `UrlRouter.kt` — see Phase 0.5 hostnames:
   ```kotlin
   sealed class Route {
       data class InApp(val url: String) : Route()
       data class Messenger(val url: String) : Route()
       data class External(val url: String) : Route()
   }
   class UrlRouter(
       private val fbHosts: Set<String> = setOf("facebook.com", "fb.com", "fb.me"),
       private val messengerHosts: Set<String> = setOf("messenger.com", "m.me"),
   ) {
       fun route(url: String): Route { /* host suffix match */ }
   }
   ```

5. `HomeUrlBuilder.kt`:
   ```kotlin
   class HomeUrlBuilder {
       fun build(useMbasic: Boolean, recentFirst: Boolean): String {
           val base = if (useMbasic) URL_MBASIC else URL_TOUCH
           val suffix = if (recentFirst) SUFFIX_RECENT else SUFFIX_DEFAULT
           return base + suffix
       }
   }
   ```

6. `UserAgentResolver.kt` — encodes `getUserAgent()` logic from Flutter `fb_controller.dart:19-32`.

**Tests (under `app/src/test/java/.../domain/`):**

- `InjectionComposerTest` — empty list, single rule, multiple rules, URL-conditional rules
- `UrlRouterTest` — every hostname pattern, empty URL, malformed URL, deep paths
- `HomeUrlBuilderTest` — all 4 (useMbasic × recentFirst) combinations
- `UserAgentResolverTest` — custom enabled+empty, custom enabled+filled, mbasic, default
- `SettingsTest` — DEFAULT matches Phase 0.5 defaults

**Documentation references:**
- This plan §0.5 (legacy defaults table) — settings tests must lock these in
- Existing Flutter source: `lib/consts.dart`, `lib/controllers/fb_controller.dart:19-32`

**Verification checklist:**
- [ ] `./gradlew :app:testFullDebugUnitTest` runs in <10s
- [ ] All domain tests pass
- [ ] Coverage report (`./gradlew :app:jacocoTestReport` if added) shows ≥90% on `domain/` package
- [ ] `grep -r "android\." app/src/main/java/.../domain/` returns 0 hits (no Android imports)

**Anti-pattern guards:**
- DO NOT use `Flow<>` inside domain types — keep them pure data + functions
- DO NOT import `android.*` or `androidx.*` from `domain/` — JVM-only
- DO NOT hardcode hosts in `UrlRouter` body — pass them in (testability)
- DO NOT inline the sponsor keyword list yet — that goes in Phase 5's `RemoveAdsRule`

---

## Phase 3 — Data layer (DataStore, LogBuffer, Flutter migrator)

**Goal:** Settings round-trip through DataStore. LogBuffer captures and exports. Migration from Flutter SharedPreferences XML works on a fixture.

**What to implement (under `app/src/main/java/.../data/`):**

1. `SettingsKeys.kt` — every legacy key from Phase 0.5 as `Preferences.Key`. **Must use the legacy names verbatim** (e.g., `booleanPreferencesKey("hide_ads")`, NOT `"hideAds"`) so a writer-side migration is symmetric and fxxx readable.
2. `SettingsRepository.kt`:
   ```kotlin
   class SettingsRepository(private val ds: DataStore<Preferences>) {
       val settings: Flow<Settings> = ds.data.map { it.toSettings() }
       suspend fun update(transform: (Settings) -> Settings) {
           ds.edit { prefs -> transform(prefs.toSettings()).writeInto(prefs) }
       }
   }
   ```
3. `LogBuffer.kt` — fixed-size ring of 500 events. Categories: `LIFECYCLE`, `NAV`, `INJECT`, `CONSOLE`, `PERMISSION`, `RENDER_GONE`, `SENTRY`, `OTHER`. Methods: `record(event)`, `snapshot(): List<LogEvent>`, `exportRedacted(): String`. Strip query strings and known-cookie names server-side per spec §7.1.
4. `FlutterMigrator.kt`:
   - Reads `/data/data/<pkg>/shared_prefs/FlutterSharedPreferences.xml` as XML
   - Parses elements with names matching `flutter\.<key>` for every key in Phase 0.5 table
   - Maps to `Settings` (custom CSS/JS strings → single `NamedSnippet` with id="legacy" name="Imported")
   - Renames the file to `FlutterSharedPreferences.xml.migrated`
   - Returns a `MigrationReport(keysFound: Int, keysMissing: List<String>, error: Throwable?)`
   - Idempotent: if `.migrated` file exists OR original file absent, no-op.
5. `LogEvent.kt`, `LogCategory.kt` — small data classes.
6. `SentryEventScrubber.kt` (pure function, even though Sentry is full-flavor — the scrubber is testable and reusable):
   ```kotlin
   object SentryEventScrubber {
       private val SENSITIVE_KEY = Regex("(?i)(token|password|secret|auth|cookie)")
       private val FB_SESSION_COOKIE_NAMES = setOf("c_user", "xs", "fr", "presence", "wd", "dpr", "sb", "datr")
       fun scrub(input: ScrubInput): ScrubInput { /* drop cookies, query strings, FB session names */ }
   }
   ```
   `ScrubInput` is a small pure-Kotlin DTO mirroring Sentry's `Request`/`extras`/`tags`. Phase 10 wires the actual Sentry `beforeSend` hook to call this.

**Tests (`app/src/test/java/.../data/`):**

- `SettingsRepositoryTest` (Robolectric, uses in-memory `PreferenceDataStoreFactory`):
  - Round-trip every field
  - Default values match `Settings.DEFAULT`
  - Concurrent updates (`update { }` chained twice) don't lose data
- `LogBufferTest`:
  - Ring overwrites at capacity
  - Redaction removes query strings, cookie values, FB session IDs
  - Export format is plain text suitable for clipboard
- `FlutterMigratorTest`:
  - Fixture file at `app/src/test/resources/migration/FlutterSharedPreferences.xml` containing all 22 keys with mixed values; assert `Settings` after migration matches expected
  - Missing-file case → returns `MigrationReport` with no error
  - File without `flutter.` prefix → keysMissing reports them
  - Idempotency: running twice produces same result, file renamed once
- `SentryEventScrubberTest`:
  - Cookie field cleared
  - `c_user` removed from arbitrary string fields
  - Query string stripped from URLs
  - Tokens in keys (e.g., `auth_token`) removed

**Documentation references:**
- DataStore: developer.android.com/topic/libraries/architecture/datastore
- This plan §0.5 (legacy keys table)
- Flutter `shared_preferences` plugin XML format: keys are stored as `flutter.<originalKey>`

**Verification checklist:**
- [ ] All data tests pass under Robolectric
- [ ] `./gradlew :app:testFullDebugUnitTest` still <30s total
- [ ] FlutterMigrator round-trips a fixture XML 1:1 (boolean defaults preserved including the four `true`-default keys)
- [ ] `grep -rn "shared_prefs" app/src/main/` shows only the migrator references the legacy path

**Anti-pattern guards:**
- DO NOT change legacy key names — migration depends on byte-for-byte match
- DO NOT make `Settings` mutable — always copy through `update { it.copy(...) }`
- DO NOT use `runBlocking` outside tests
- DO NOT use Sentry classes here — `ScrubInput` is a pure-Kotlin DTO so this file works in `fdroid` too

---

## Phase 4 — WebView host

**Goal:** A real WebView is constructed, configured, and exposed via a clean Kotlin API. Compose hosts it via `AndroidView`. Render-process-gone is handled.

**What to implement (under `app/src/main/java/.../webview/`):**

1. `WebViewHost.kt` — owns the `WebView`, has methods `load(url)`, `injectCss(payload)`, `injectJs(payload)`, `setUserAgent(ua)`, `clearAll()`, `back()`, `reload()`, plus `view: WebView` getter for hosting in Compose.
2. `WebViewFactory.kt` — single entry point that constructs and configures a fresh WebView per Phase 0.1.
3. `AppWebViewClient.kt`:
   - `shouldOverrideUrlLoading(view, request): Boolean` — delegates to `UrlRouter`; returns true to consume external URLs (host opens Custom Tab via callback)
   - `onPageCommitVisible(view, url)` — first injection point (early paint)
   - `onPageFinished(view, url)` — second injection point (catches late-loading content)
   - `onRenderProcessGone(view, detail): Boolean` — emit a `RenderGoneEvent` to a SharedFlow; return `true`
4. `AppWebChromeClient.kt`:
   - `onPermissionRequest(req)` — checks the `PermissionGate` for each requested resource; grants only the subset the user has enabled, denies the rest
   - `onGeolocationPermissionsShowPrompt(origin, cb)` — checks `gps` toggle; if off, `cb.invoke(origin, false, false)`
   - `onShowFileChooser(...)` — checks `photos` toggle; if off, calls back with empty array; if on, launches Storage Access Framework picker via callback
   - `onConsoleMessage(msg)` — emits to LogBuffer
5. `ProxyConfigurator.kt` — wraps `ProxyController.setProxyOverride(...)` and `clearProxyOverride(...)`. HTTP/HTTPS only (per spec correction). If `WebViewFeature.isFeatureSupported(WebViewFeature.PROXY_OVERRIDE)` returns false, log + no-op.
6. `CookieConfigurator.kt` — calls `setAcceptCookie(true)` and `setAcceptThirdPartyCookies(webView, true)`. Provides `flushOnPause()` for Activity to call.
7. `DarkModeConfigurator.kt` — calls `WebSettingsCompat.setAlgorithmicDarkeningAllowed(settings, allowed)` if feature supported.
8. `UrlOpener.kt` — interface with one impl using `CustomTabsIntent.Builder().build().launchUrl(...)`. The `webview/` package owns the launch path so external URLs route consistently.

**Tests:**

- `AppWebChromeClientTest` (Robolectric):
  - Camera-only request with camera grant → grants only camera, denies mic
  - All resources requested with all-off → denies all
  - Geolocation off → `cb.invoke(origin, false, false)` exactly once
- `AppWebViewClientTest` (Robolectric):
  - `shouldOverrideUrlLoading` returns true for external URLs, false for FB hosts
  - `onRenderProcessGone(didCrash=false)` emits an event and returns true
- `ProxyConfiguratorTest`:
  - Feature-supported path
  - Feature-unsupported path → no exception, log entry only

**Documentation references:**
- This plan §0.1 (allowed APIs)
- developer.android.com/develop/ui/views/layout/webapps/managing-webview (configuration + render-process-gone sample)
- developer.android.com/jetpack/androidx/releases/webkit (1.15.0 API surface)

**Verification checklist:**
- [ ] All webview tests pass
- [ ] `WebViewHost` exposes no Android types in its method *parameters* except `WebView` getter (so it can be called from ViewModels via interface)
- [ ] `grep -rn "setForceDark\|setAppCacheEnabled\|setSaveFormData" app/src/main/` returns 0 hits
- [ ] `grep -rn "PROXY_OVERRIDE\|ALGORITHMIC_DARKENING" app/src/main/` shows the feature gates ARE checked before use

**Anti-pattern guards:**
- DO NOT use deprecated `setForceDark` (use `setAlgorithmicDarkeningAllowed` per Phase 0.1)
- DO NOT call `evaluateJavascript` from anywhere except `WebViewHost`
- DO NOT pass `Context` into domain or data layers from here
- DO NOT add SOCKS5 to `ProxyConfigurator` — `ProxyController` does not support it; document as deferred

---

## Phase 5 — Built-in injection rules (port from Flutter)

**Goal:** Every CSS rule and JS function from the Flutter app exists as a Kotlin `InjectionRule` with a unit test asserting the exact emitted string.

**What to implement (under `app/src/main/java/.../rules/`):**

One file per rule. Each rule is a class with:
- `id` matching the legacy SharedPreferences key
- `cssFor(url)` returning the verbatim CSS string from the Flutter source (or null if URL-conditional and doesn't match)
- `jsFor(url)` for the JS-bearing rules

**Rules to port (12 CSS + 4 JS):**

| File | Source location | Notes |
|---|---|---|
| `CenterTextRule.kt` | `lib/utils/css.dart:14-18` | URL-conditional: only on FB hosts, not Messenger |
| `HideMessengerSidebarRule.kt` | `css.dart:20-26` | default TRUE; URL-conditional on Messenger only |
| `AddSpaceRule.kt` | `css.dart:28-32` | |
| `HideStoriesRule.kt` | `css.dart:34-38` | |
| `FixedBarRule.kt` | `css.dart:40-46` | default TRUE |
| `RemoveMessengerDownloadRule.kt` | `css.dart:48-53` | Messenger only |
| `RemoveBrowserNotSupportedRule.kt` | `css.dart:55-59` | |
| `HideAdsAndPYMKRule.kt` | `css.dart:61-66` | |
| `FabButtonRule.kt` | `css.dart:68-73` + `js.dart:121-135` | Has both CSS and JS parts |
| `AdaptMessengerRule.kt` | `css.dart:75-172` | Multi-rule CSS |
| `DarkThemeRule.kt` | `css.dart:218-511` | ~293 lines — port verbatim |
| `DarkThemeMessengerRule.kt` | `css.dart:181-216` | |
| `RemoveAdsRule.kt` | `js.dart:21-92` + `js.dart:94-118` | Sponsor-keyword JS + MutationObserver. Hard-code the 23-language keyword list from Phase 0.5 |
| `UserCustomCssRule.kt` | n/a | Reads from `Settings.customization.cssEntries` filtered by `activeCssIds` |
| `UserCustomJsRule.kt` | n/a | Reads from `Settings.customization.jsEntries` filtered by `activeJsIds` |

**Rule registry:**
```kotlin
class RuleRegistry(settings: Settings) {
    fun activeRules(): List<InjectionRule> = listOf(
        if (settings.style.centerText) CenterTextRule() else null,
        if (settings.features.hideAds) RemoveAdsRule() else null,
        // ... etc
    ).filterNotNull() + userCustomRules(settings.customization)
}
```

**Tests:** One per rule, asserting:
- `id` matches the legacy key string
- `cssFor("https://m.facebook.com/...")` returns the expected non-null string
- `cssFor("https://example.com/")` returns null (not an FB host)
- For URL-conditional rules: returns the right value per host
- `RemoveAdsRule.jsFor(...)` contains every one of the 23 sponsor keywords (assert each as substring)

**Documentation references:**
- Existing Flutter source: `SlimSocial_for_Facebook/lib/utils/css.dart` and `lib/utils/js.dart`
- Phase 0.5 (sponsor keywords full list)

**Verification checklist:**
- [ ] All 12 + 4 rule tests pass
- [ ] `grep -c "Sponsorisé\|Sponsored\|Patrocinado\|Gesponsert\|Sponsorizzato\|Sponsrad\|Được tài trợ\|贊助內容\|赞助内容\|スポンサーされた投稿\|Sponsorowane\|Реклама" app/src/main/java/.../rules/RemoveAdsRule.kt` shows non-zero hits
- [ ] `DarkThemeRule.kt`'s CSS string length within ±5% of the Flutter original (`wc -c` comparison)
- [ ] No rule imports `android.webkit` (rules are pure data/strings keyed by URL)

**Anti-pattern guards:**
- DO NOT translate or "improve" the CSS — port it byte-for-byte
- DO NOT decode the unicode sponsor keywords manually — use Kotlin string literals (UTF-8)
- DO NOT add new rules in this phase — only port what exists

---

## Phase 6 — Permission gate

**Goal:** Two-layer permission gate per spec §6 fully wired. WebView permission requests cannot bypass user toggles.

**What to implement (under `app/src/main/java/.../permissions/`):**

1. `PermissionGate.kt` — pure logic, takes `Settings.permissions` and `OsPermissionState`, returns `GateDecision.Grant | Deny`.
   ```kotlin
   sealed class WebPermission {
       object Camera : WebPermission()
       object Mic : WebPermission()
       object Location : WebPermission()
       object Photos : WebPermission()
   }
   class PermissionGate {
       fun decide(perm: WebPermission, app: PermissionGrants, os: OsPermissionState): GateDecision { ... }
   }
   ```
2. `PermissionToggleController.kt` — Android-side: handles user toggling an app-level permission switch.
   - User flips ON → check OS state → if not granted, launch system prompt → on result, if granted set app-toggle ON, else set OFF (no orphan state)
   - User flips OFF → set app-toggle OFF (do NOT revoke OS permission; user can do that in system settings)
3. `OsPermissionState.kt` — wraps `ContextCompat.checkSelfPermission` + `shouldShowRequestPermissionRationale`. Three returned states: `Granted`, `Deniable`, `PermanentlyDenied`.
4. `PermissionMapping.kt`:
   ```kotlin
   val WEB_PERMISSION_TO_ANDROID = mapOf(
       WebPermission.Camera   to Manifest.permission.CAMERA,
       WebPermission.Mic      to Manifest.permission.RECORD_AUDIO,
       WebPermission.Location to Manifest.permission.ACCESS_FINE_LOCATION,
       // Photos uses SAF, no runtime permission on API 24+
   )
   val WEB_PERMISSION_RESOURCE = mapOf(
       PermissionRequest.RESOURCE_VIDEO_CAPTURE to WebPermission.Camera,
       PermissionRequest.RESOURCE_AUDIO_CAPTURE to WebPermission.Mic,
   )
   ```

**Tests:**
- `PermissionGateTest` — every (WebPermission × app-toggle × os-state) combination → assert decision
- `PermissionToggleControllerTest` (Robolectric):
  - Toggle on, OS grants → final state ON
  - Toggle on, OS denies → final state OFF, no orphan
  - Toggle off → no OS interaction
- `PermissionMappingTest` — every constant pair maps both ways

**Documentation references:**
- This plan §0.1 (`PermissionRequest` constants)
- developer.android.com/training/permissions/requesting

**Verification checklist:**
- [ ] All permission tests pass
- [ ] No app-level toggle can be ON if OS denied (asserted by test)
- [ ] WebView's `onPermissionRequest` (Phase 4 file `AppWebChromeClient`) is updated to consult `PermissionGate.decide(...)`

**Anti-pattern guards:**
- DO NOT auto-request any permission at app start — every prompt is user-initiated
- DO NOT show system dialogs for resources the app-toggle has disabled
- DO NOT treat `ACCESS_COARSE_LOCATION` and `ACCESS_FINE_LOCATION` as the same (declare both in Manifest, request fine; coarse is auto-granted with fine)

---

## Phase 7 — MainActivity, app links, crash recovery UI

**Goal:** Activity hosts the WebView via `AndroidView`, deep links from Phase 0.5 work, render-process-gone shows an inline reload UI without crashing.

**What to implement:**

1. `MainActivity.kt`:
   ```kotlin
   class MainActivity : ComponentActivity() {
       private val viewModel: MainViewModel by viewModels { MainViewModelFactory(applicationContext) }
       override fun onCreate(savedInstanceState: Bundle?) {
           super.onCreate(savedInstanceState)
           handleIntentUrl(intent)
           setContent { App(viewModel) }
       }
       override fun onNewIntent(intent: Intent) { super.onNewIntent(intent); handleIntentUrl(intent) }
       override fun onPause() { super.onPause(); viewModel.flushCookies() }
   }
   ```
2. `App.kt` (Compose root) — Material 3 theme, NavHost with routes: `home`, `settings`, `editor`, `log`, `messenger`. Home hosts the WebView via `AndroidView`.
3. `MainViewModel.kt` — connects Settings flow → injection rules → `WebViewHost`. Exposes:
   - `homeUrl: StateFlow<String>` (from `HomeUrlBuilder` + Settings)
   - `userAgent: StateFlow<String>` (from `UserAgentResolver`)
   - `injectionTrigger: SharedFlow<InjectionPayload>` (recomposes when settings change)
   - `renderGone: SharedFlow<Unit>` (from WebView)
4. `RenderGoneScreen.kt` — Compose composable shown on top of WebView when `renderGone` fires; shows "Facebook stopped responding" + Reload button.
5. App-link handler: parse `intent.data: Uri?`, if matches FB or Messenger host pass to `viewModel.handleDeeplink(uri)`.
6. Back button handling: WebView's `canGoBack()` first, else default Activity back.

**Tests:**
- `MainViewModelTest` — Settings updates → `homeUrl` changes; render-gone SharedFlow emits
- Instrumented test (1): app launches, `MainActivity` shows WebView, deeplink intent navigates correctly

**Documentation references:**
- developer.android.com/develop/ui/compose/migrate/interoperability-apis/views-in-compose (AndroidView pattern)
- This plan §0.5 (existing app-link host list)

**Verification checklist:**
- [ ] `setContentView` is NOT called anywhere
- [ ] Render-gone test passes (force the renderer to die in instrumented test)
- [ ] App-link from `https://m.facebook.com/foo` opens in-app
- [ ] App-link from `https://other.com` opens via Custom Tab

**Anti-pattern guards:**
- DO NOT keep the WebView in a `remember { }` outside the `factory` lambda
- DO NOT call `AndroidView` inside a `LazyColumn` (one-shot full-screen only)
- DO NOT share `WebView` instance between Activity recreations without `saveState`/`restoreState`

---

## Phase 8 — Compose Settings screens

**Goal:** Replicate the existing settings surface in Material 3 Compose, with the three-state permission UI from spec §6.4.

**What to implement (under `app/src/main/java/.../ui/settings/`):**

- `SettingsScreen.kt` — top-level navigable screen, sections: Facebook, Style, Permissions, Advanced, Privacy, About
- `SettingsRow.kt`, `ToggleRow.kt`, `PermissionRow.kt` — reusable Compose components
- `PermissionRow` displays:
  - Off state: simple switch
  - On (granted): switch ON, subtle "OS-allowed" tag
  - On (denied by OS): switch ON visually but warning chip + tap-to-fix → opens `Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)`
- `AdvancedSettingsScreen.kt` — links to: User-agent override, Custom CSS Editor, Custom JS Editor, Custom Proxy, Send to dev, Custom URL test
- `ProxySettingsScreen.kt` — host + port inputs, validation (port 1-65535, host non-empty), Apply button calls `ProxyConfigurator.apply(...)`
- `AboutScreen.kt` — version, Changelog link, License link, donation entry point
- `SettingsViewModel.kt` — reads `SettingsRepository`, exposes `StateFlow<Settings>`, `update {}` actions

**i18n:** All visible strings must come from `R.string.<key>`. The keys are populated in Phase 11.

**Tests:**
- `SettingsViewModelTest` — every `update {}` writes the expected `Settings` mutation
- `PermissionRowTest` (Compose UI test) — three visual states render correctly

**Documentation references:**
- Material 3 components: developer.android.com/jetpack/compose/components/material3
- Spec §6.4 (three-state permission UI)

**Verification checklist:**
- [ ] Every legacy SharedPreferences key has a UI representation OR a comment in `SettingsScreen.kt` explaining why it's surface-hidden (e.g., `hide_messenger_sidebar` was hidden in Flutter app — keep it that way for parity, exposed only in Advanced if at all)
- [ ] Permission rows reflect OS state changes (toggle Camera in system settings → return to app → row updates)
- [ ] No hardcoded English strings — all from `R.string`

**Anti-pattern guards:**
- DO NOT use `LiveData` — use Flow + `collectAsStateWithLifecycle()`
- DO NOT recreate the ViewModel on theme change — use `viewModels()` correctly
- DO NOT inline business logic in composables — push it down to ViewModel

---

## Phase 9 — Editor + Log Viewer screens

**Goal:** Named CSS/JS snippet editor with the spec §5.6 safety dialogs. Log viewer with redacted export.

**What to implement (under `app/src/main/java/.../ui/editor/` and `.../ui/log/`):**

1. `SnippetListScreen.kt` — list of named snippets (CSS or JS, separately routed) with enabled/disabled switch, edit, delete
2. `SnippetEditorScreen.kt`:
   - `BasicTextField` with monospace font, line-number gutter via custom `Modifier`
   - "Test" button → temporarily injects via `WebViewHost.injectCss/Js`, reverts on back
   - Save → updates `Settings.customization`
3. `JsWarningDialog.kt`:
   - Shown FIRST time user enables ANY JS snippet (gated by `Settings.privacy.customJsAcknowledged`)
   - Title: "JavaScript runs in your Facebook session"
   - Body: explains DOM access, session cookie risk
   - Buttons: "Cancel" / "I understand"
   - On accept: sets `customJsAcknowledged = true`
4. `JsEditorHeader.kt` — persistent yellow strip in JS editor (NOT CSS)
5. `LogViewerScreen.kt`:
   - Auto-scrolling list of `LogEvent`s from `LogBuffer`
   - Filter chips per `LogCategory`
   - "Pause" button (stop tail), "Clear" (clears buffer)
   - "Export" → share intent with `LogBuffer.exportRedacted()`
   - "Send to dev" → opens email intent with prefilled subject + log attachment
6. `DebugScreen.kt` — state snapshot panel: Chrome WebView major version (`WebViewCompat.getCurrentWebViewPackage(ctx)?.versionName`), current UA, current URL, active CSS/JS rule IDs (from `RuleRegistry`), proxy state, permission grants

**Tests:**
- `SnippetListViewModelTest` — add, edit, delete snippet round-trips through `SettingsRepository`
- `JsWarningGateTest` — first enable triggers dialog flag, subsequent enables don't
- `LogBufferExportTest` — covered in Phase 3 but add an integration test asserting the share intent payload contains no cookie names

**Documentation references:**
- `WebViewCompat.getCurrentWebViewPackage`: developer.android.com/jetpack/androidx/releases/webkit
- Spec §5.6 (custom JS warnings)

**Verification checklist:**
- [ ] Enabling a JS snippet for the first time shows the dialog; "I understand" persists across app restarts
- [ ] Log export redacts FB session cookie values (manually inspect a sample export)
- [ ] Debug screen shows non-blank Chrome WebView version on a test device

**Anti-pattern guards:**
- DO NOT use `WebView.evaluateJavascript` directly from UI — go through `WebViewHost.injectJs`
- DO NOT skip the warning dialog for "trusted" snippets — always require acknowledgement before first JS enable
- DO NOT log raw URLs with query strings — strip them via the redactor (Phase 3 `LogBuffer`)

---

## Phase 10 — Flavor splits (Sentry, Play Billing, Play Review)

**Goal:** `full` flavor includes Sentry + Billing + Review. `fdroid` flavor compiles without ANY proprietary class. Same codebase, same `applicationId`.

**What to implement:**

1. **Interfaces in `src/main/java/.../platform/` (both flavors see these):**
   ```kotlin
   interface CrashReporter {
       fun init(app: Application)
       fun reportNonFatal(throwable: Throwable, tags: Map<String, String> = emptyMap())
       fun setEnabled(enabled: Boolean)
   }
   interface DonationLauncher {
       fun launch(activity: Activity, productId: String): Flow<DonationResult>
   }
   interface ReviewLauncher {
       fun maybeRequest(activity: Activity)
   }
   ```

2. **`src/full/java/.../platform/SentryCrashReporter.kt`:**
   - `SentryAndroid.init(app) { options -> ... beforeSend = SentryEventScrubber.toBeforeSend() ... }`
   - `BuildConfig.SENTRY_DSN` from `productFlavors { full { buildConfigField("String", "SENTRY_DSN", "\"...\"") } }`. DSN comes from secret env var in CI; local builds get `""` and Sentry init skips
   - Sample rates per Phase 0.3
   - `setEnabled(false)` calls `Sentry.close()`

3. **`src/full/java/.../platform/PlayBillingDonationLauncher.kt`:**
   - `BillingClient.newBuilder(...).enableAutoServiceReconnection().enablePendingPurchases(...).build()`
   - `queryProductDetails`, `launchBillingFlow`, acknowledge non-consumable
   - Product IDs: `donation_1`, `donation_2`, `donation_3`, `donation_4`

4. **`src/full/java/.../platform/PlayReviewLauncher.kt`:**
   - `ReviewManagerFactory.create(activity).requestReviewFlow()`

5. **`src/fdroid/java/.../platform/CrashReporter.kt`:** no-op:
   ```kotlin
   class CrashReporter : it.rignanese.leo.slim.platform.CrashReporter {
       override fun init(app: Application) {}
       override fun reportNonFatal(t: Throwable, tags: Map<String, String>) {}
       override fun setEnabled(enabled: Boolean) {}
   }
   ```

6. **`src/fdroid/java/.../platform/ExternalDonationLauncher.kt`:** opens browser to PayPal / GitHub Sponsors via `Intent.ACTION_VIEW`. Returns `flowOf(DonationResult.External)`.

7. **`src/fdroid/java/.../platform/ReviewLauncher.kt`:** no-op.

8. **`AppContainer` in `src/main/`:** the manual-DI factory binds `CrashReporter`/`DonationLauncher`/`ReviewLauncher` from a single source-set-provided factory function `createPlatform(): Platform`. Each flavor provides its own `Platform.kt` returning the right impls.

9. **`build.gradle.kts` flavor deps:**
   ```kotlin
   "fullImplementation"("io.sentry:sentry-android:8.+")
   "fullImplementation"("com.android.billingclient:billing-ktx:8.3.+")
   "fullImplementation"("com.google.android.play:review-ktx:2.0.+")
   ```

10. **Manifest meta-data in `src/full/AndroidManifest.xml`:** disable Sentry auto-init.

**Tests:**
- `SentryCrashReporterTest` (full only) — Robolectric, assert init called and beforeSend wired (use a fake Sentry hub)
- `NoOpCrashReporterTest` (fdroid only)
- `PlayBillingDonationLauncherTest` (full only) — Robolectric with stubbed BillingClient
- `ExternalDonationLauncherTest` (fdroid only) — assert intent action and URL

**Documentation references:**
- Phase 0.3 (Sentry, Billing, Review APIs)
- Phase 0.4 (F-Droid metadata format)
- Spec §8

**Verification checklist:**
- [ ] `./gradlew :app:assembleFdroidRelease` succeeds and the resulting APK contains zero Sentry/Billing/Play classes — verify with `unzip -l app/build/outputs/apk/fdroid/release/app-fdroid-release.apk | grep -E "sentry|billing|play"` returning empty
- [ ] `./gradlew :app:assembleFullRelease` succeeds and contains those classes
- [ ] `grep -r "io.sentry\|billingclient\|play:review" app/src/main/` returns 0 hits
- [ ] Sentry `beforeSend` test confirms FB session cookie stripped

**Anti-pattern guards:**
- DO NOT reference `BuildConfig.SENTRY_DSN` from `src/main/` — only from `src/full/`
- DO NOT name the Impl classes the same in `src/main/` AND a flavor source set (duplicate-class compile error)
- DO NOT enable Sentry auto-init via manifest in `src/full/` — programmatic only (so init order respects Settings opt-out)
- DO NOT include any proprietary lib's transitive dep in `fdroid` flavor — verify with the unzip check

---

## Phase 11 — i18n port

**Goal:** All 47 locales from Flutter `assets/lang/*.json` ported to `app/src/main/res/values-<locale>/strings.xml`.

**What to implement:**

1. Write a one-time conversion script `scripts/convert_lang.py` that:
   - Reads each `assets/lang/<locale>.json` file
   - Maps locale codes: `en-US` → `values-en-rUS`, `it-IT` → `values-it-rIT`, `pt-BR` → `values-pt-rBR`, etc.
   - Writes Android `strings.xml` with proper escaping (`'` → `\'`, `"` → `\"`, ampersand → `&amp;`, `%s`/`%d` formatting preserved if any)
   - Skips keys with empty string values
2. Run the script. Hand-verify English output for parity.
3. Replace the `easy_localization` dynamic key references in plan-Phase-8 UI (`'settings'.tr()`) with `stringResource(R.string.settings)`.
4. Keep `R.string` keys identical to the Flutter JSON keys for grep-ability across the migration.
5. Languages with locale-region pairs not natively supported by Android (e.g., Persian `fa-IR`) fall back to language-only resource folder.
6. Default fallback: `values/strings.xml` = English content.

**Tests:**
- `LocaleResourceTest` — load every supported locale config, assert `R.string.settings` resolves to a non-blank string
- Manual smoke: switch device language to Italian, German, Arabic; verify Settings screen displays translated text

**Documentation references:**
- developer.android.com/guide/topics/resources/multilingual-support
- Phase 0.5 (47 language list)

**Verification checklist:**
- [ ] `find app/src/main/res -name strings.xml | wc -l` ≥ 48 (default + 47 locales)
- [ ] No `.tr()` calls remain in any Compose source file
- [ ] CI lint passes (`./gradlew :app:lintFullDebug` reports no missing translations beyond the default-empty ones)

**Anti-pattern guards:**
- DO NOT manually retype translations — script-convert them
- DO NOT change key names — keep Flutter JSON keys verbatim for cross-reference
- DO NOT forget XML escaping — script handles it; don't bypass

---

## Phase 12 — AndroidManifest, signing, F-Droid metadata

**Goal:** Replicate every intent filter and permission from the Flutter Manifest. Both flavors signed and reproducible.

**What to implement:**

1. **`app/src/main/AndroidManifest.xml`:**
   - Permissions: `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `CAMERA`, `RECORD_AUDIO`, `READ_MEDIA_IMAGES` (API 33+), `POST_NOTIFICATIONS` (API 33+), `DOWNLOAD_WITHOUT_NOTIFICATION`. Drop legacy `WRITE_EXTERNAL_STORAGE` (no longer needed on minSdk 24+ with SAF).
   - `<application android:name=".SlimApplication" android:hardwareAccelerated="true" ...>`
   - `MainActivity` `android:launchMode="singleTask"`, `android:configChanges` matching the Flutter manifest line list
   - Intent filters: copy verbatim from `SlimSocial_for_Facebook/android/app/src/main/AndroidManifest.xml:30-81` (22 wildcard hosts + 22 exact hosts, both `http` and `https`, `android:autoVerify="true"`).

2. **Signing config in `app/build.gradle.kts`:**
   ```kotlin
   signingConfigs {
       create("release") {
           storeFile = file(System.getenv("SIGNING_KEYSTORE_PATH") ?: "release.keystore")
           storePassword = System.getenv("SIGNING_KEYSTORE_PASSWORD")
           keyAlias = System.getenv("SIGNING_KEY_ALIAS")
           keyPassword = System.getenv("SIGNING_KEY_PASSWORD")
       }
   }
   buildTypes { release { signingConfig = signingConfigs.getByName("release"); isMinifyEnabled = true; ... } }
   ```
   Pin `apksigner` build-tools to a reproducibility-friendly version per Phase 0.4.

3. **`metadata/it.rignanese.leo.slimfacebook.yml`** at repo root, exactly as Phase 0.4 template; commit before first F-Droid submission. Send a separate PR to fdroiddata adding/updating this file there too (F-Droid stores metadata in their repo, not the app's).

4. **`SlimApplication.kt`:**
   ```kotlin
   class SlimApplication : Application() {
       lateinit var container: AppContainer
       override fun onCreate() {
           super.onCreate()
           container = AppContainer(this)
           container.crashReporter.init(this)        // no-op in fdroid
           // Apply persisted Sentry opt-out / debug mode after init
       }
   }
   ```

5. **ProGuard/R8 `proguard-rules.pro`:** keep `Settings`, `NamedSnippet`, and any other DataStore-serialized class fields unobfuscated; full Sentry rules consumed transitively.

**Tests:**
- Instrumented: launch app via `adb shell am start -W -a android.intent.action.VIEW -d "https://m.facebook.com/foo" "it.rignanese.leo.slimfacebook"` — verify it lands on home screen with the URL loaded

**Documentation references:**
- Existing Flutter manifest: `SlimSocial_for_Facebook/android/app/src/main/AndroidManifest.xml`
- Phase 0.4 (F-Droid yml format)

**Verification checklist:**
- [ ] App-link verification passes: `adb shell pm get-app-links it.rignanese.leo.slimfacebook` shows `legacy_failure: false` for FB hosts
- [ ] Both signed release APKs install over the existing Flutter app without uninstall
- [ ] `aapt dump badging app-fdroid-release.apk | grep package:` shows the same package name as Flutter app
- [ ] `unzip -l app-fdroid-release.apk | grep -E "io/sentry|billingclient|play/review"` returns empty

**Anti-pattern guards:**
- DO NOT add new intent filter hosts beyond what Flutter manifest had (avoid hijacking unrelated FB subdomains)
- DO NOT set `applicationIdSuffix` — same applicationId across flavors per spec
- DO NOT leave default debug signing in release builds

---

## Phase 13 — CI (GitHub Actions)

**Goal:** Reproducible builds on every push, signed release on tag.

**What to implement (`.github/workflows/`):**

1. **`build.yml`** (push/PR):
   - Setup JDK 17, Gradle cache
   - `./gradlew :app:lintFullDebug :app:lintFdroidDebug`
   - `./gradlew :app:testFullDebugUnitTest :app:testFdroidDebugUnitTest`
   - `./gradlew :app:assembleFullDebug :app:assembleFdroidDebug`
   - Upload APK artifacts
   - Total runtime target: <5 min on hosted runners

2. **`release.yml`** (tag `v*`):
   - All of build.yml plus
   - `./gradlew :app:bundleFullRelease` → upload AAB to Play Console internal track via `r0adkll/upload-google-play@v1`
   - `./gradlew :app:assembleFdroidRelease` → attach to GitHub Release
   - Trigger F-Droid auto-update by tag — no extra step (their build server polls)
   - Verify reproducibility: build twice, `diff` the unsigned APK manifests; fail on diff

3. **Secrets needed:** `SIGNING_KEYSTORE_BASE64`, `SIGNING_KEYSTORE_PASSWORD`, `SIGNING_KEY_ALIAS`, `SIGNING_KEY_PASSWORD`, `SENTRY_DSN`, `PLAY_SERVICE_ACCOUNT_JSON`

4. Existing Codemagic config: keep running for now (Flutter app builds), retire once Kotlin app is stable.

**Verification checklist:**
- [ ] PR opened against this plan-implementation branch passes both flavors' lint + tests + assembleDebug
- [ ] Tag push produces a signed AAB and signed APK as artifacts
- [ ] Reproducibility check produces identical unsigned manifests across two consecutive runs

**Anti-pattern guards:**
- DO NOT commit signing keys; use base64-encoded GitHub secrets
- DO NOT skip lint in CI — `lintRelease` catches missing translations and resource issues
- DO NOT let CI test job exceed 10 minutes

---

## Phase 14 — Verification, migration test, manual matrix

**Goal:** Prove the rewrite hits every spec §13 success criterion.

**What to verify:**

1. **APK size targets:**
   - `du -h app-fdroid-release.apk` ≤ 5 MB
   - `du -h app-full-release.apk` ≤ 7 MB
   - If over, run `./gradlew :app:bundleFullRelease --scan` and analyze
2. **Cold start:** Use `am start -W` on API 24 emulator (2 GB RAM) → "WaitTime" ≤ 1500 ms
3. **Idle RAM:** `adb shell dumpsys meminfo it.rignanese.leo.slimfacebook` ≤ 80 MB after 1 min idle
4. **Permission default-off:** Fresh install → `dumpsys package it.rignanese.leo.slimfacebook | grep "granted=true"` returns no runtime permissions
5. **Migration:** Side-load Kotlin debug APK over installed Flutter app; verify these survive:
   - Custom CSS string preserved
   - Custom JS string preserved
   - All 22 SharedPreferences key values preserved (test with one of each toggled to non-default)
6. **F-Droid build cleanliness:** `unzip -l app-fdroid-release.apk` confirms no `io/sentry/`, `com/android/billingclient/`, `com/google/android/play/`
7. **Manual test matrix per spec §10.4:**
   - Emulator API 24, 28, 33, 35: app launches, navigates FB home, opens Messenger tab, toggles dark theme, custom CSS works
   - Real low-RAM device (owner-supplied): same flow + render-process-gone recovery (force-stop renderer with `adb shell am crash com.android.webview:webview_service`)
   - Both flavors smoke-tested

**Final acceptance gate:**
- [ ] Every spec §13 success criterion met
- [ ] Test suite (unit + Robolectric) under 60s
- [ ] At least one user from owner's existing user base side-loads and confirms upgrade preserves their setup
- [ ] Sentry receives a deliberately triggered test error with all FB-session fields scrubbed (verified in Sentry web UI)

**Anti-pattern guards:**
- DO NOT ship until APK size targets are met OR the spec is amended to relax them with rationale
- DO NOT skip the side-load migration test — losing user data here is the worst possible outcome
- DO NOT trust "tests pass" as proof of behavior; do the manual matrix

---

## Done state

When Phase 14 passes:
1. Tag `v2026.1.0` (versionCode 200), push.
2. Release.yml uploads `full` AAB to Play Internal track.
3. Manually promote to closed beta after a week of internal testing.
4. F-Droid metadata PR merged; their build server picks up the tag.
5. Flutter app branch (`master` of legacy) frozen; new development happens on `kotlin` branch which becomes new `master` after stable release.
