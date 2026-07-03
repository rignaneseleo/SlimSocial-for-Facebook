# Testing — Kotlin rewrite

This document tracks acceptance criteria from the [design spec §13](docs/superpowers/specs/2026-05-03-kotlin-rewrite-design.md) and the manual verification matrix from §10.4. The CI handles the automatable parts on every push and tag; this doc is for the device-side checks that need a human plus an emulator or real phone.

## Automatically verified in CI (no human action)

| Criterion | Where | Pass condition |
|---|---|---|
| 246 (full) / 221 (fdroid) unit/Robolectric tests pass | `:app:testFullDebugUnitTest`, `:app:testFdroidDebugUnitTest` | exit 0 |
| Both flavors build a debug APK | `:app:assembleFullDebug`, `:app:assembleFdroidDebug` | exit 0 |
| Lint reports zero errors | `:app:lintFullDebug` | "0 errors" in report |
| F-Droid APK contains zero proprietary classes | release.yml's dex string check | exit 0; `0` matches |
| Test suite runtime < 60s | `time ./gradlew testFullDebugUnitTest` | < 60 s |
| `fdroid` release APK ≤ 5 MB | size check on artifact | `1.6 MB` (well under) |
| `full` release APK ≤ 7 MB | size check on artifact | `6.5 MB` (under) |

## Pre-tag manual matrix

Run before tagging a `v*` release, on each device/emulator below. Both **full** and **fdroid** flavors must be smoke-tested.

### Devices

- [ ] Emulator API 24 (Android 7.0)
- [ ] Emulator API 28 (Android 9)
- [ ] Emulator API 33 (Android 13)
- [ ] Emulator API 35 (Android 15)
- [ ] Real low-RAM device (~2 GB RAM, owner-supplied)

### Smoke flow per device

```bash
# Install over the existing Flutter app to verify migration
adb install -r app/build/outputs/apk/full/debug/app-full-debug.apk

# Cold start timing (target ≤ 1500 ms WaitTime on the 2 GB API 24 device)
adb shell am force-stop it.rignanese.leo.slimfacebook
adb shell am start -W -n it.rignanese.leo.slimfacebook/.MainActivity | grep WaitTime

# Idle RAM after 60 s on home screen (target ≤ 80 MB)
adb shell sleep 60 && adb shell dumpsys meminfo it.rignanese.leo.slimfacebook | grep "TOTAL "

# Confirm no permissions granted on fresh install
adb shell pm reset-permissions it.rignanese.leo.slimfacebook
adb shell dumpsys package it.rignanese.leo.slimfacebook | grep "granted=true"
# → expected: empty (no runtime perms granted at first launch)
```

### UI flow

- [ ] App launches and reaches Facebook home page
- [ ] Settings opens via top-right gear icon
- [ ] Toggle **Hide ads** off → reload → ads appear; toggle back on → ads gone
- [ ] Toggle **Dark theme** → background turns dark
- [ ] Toggle **Use mbasic** → URL changes to `mbasic.facebook.com`
- [ ] Long-press one Permission row → tap toggle → OS prompt shown
- [ ] Decline OS prompt → app-level toggle reverts to off (no orphan state)
- [ ] Open the **Custom CSS Editor** → add a snippet → enable → reload → CSS applies
- [ ] Open the **Custom JS Editor** → enable a JS snippet for the first time → "I understand" dialog appears → accept → snippet applies
- [ ] Open the **Log viewer** → events scroll, filter chips work, Export shares a redacted text
- [ ] Open Messenger via a `messenger.com` link → in-app navigation works
- [ ] Open an external link (e.g. a third-party blog) → opens in Custom Tabs
- [ ] Tap an `https://m.facebook.com/...` link in another app → SlimSocial opens it in-app

### Render-process-gone recovery

Force a renderer crash:

```bash
adb shell am crash com.android.webview:webview_service
```

- [ ] App does NOT die — Material 3 overlay shows "Facebook stopped responding — Reload"
- [ ] Tapping Reload restores the WebView to the same URL

### Migration from Flutter app

- [ ] Install the existing Flutter app from Play Store on a clean device
- [ ] Set custom CSS, custom JS, custom user-agent, recent_first=on, hide_ads=off (non-defaults)
- [ ] Side-load this Kotlin debug APK over the top — same `applicationId`, no uninstall needed
- [ ] First launch: open Settings — every customisation should be present, including the custom CSS / custom JS strings
- [ ] Verify legacy `FlutterSharedPreferences.xml` was renamed to `.migrated` (visible via `adb shell run-as it.rignanese.leo.slimfacebook ls -la shared_prefs/`)

### Sentry verification (full flavor only, requires Sentry account)

- [ ] In Settings → Privacy, confirm "Send anonymous crash reports" is on by default
- [ ] Toggle Debug mode on
- [ ] Trigger a test error: long-press the version label in About 5 times (or via test-only "throw" hook in debug builds)
- [ ] Open the Sentry dashboard for the project — event arrives within 30 s
- [ ] Inspect the event JSON — confirm:
  - [ ] `request.cookies` is null
  - [ ] `request.queryString` is null
  - [ ] No occurrence of `c_user`, `xs`, `fr`, `presence`, `wd`, `dpr`, `sb`, or `datr` in any field
  - [ ] `release` matches `it.rignanese.leo.slimfacebook@<versionName>+<versionCode>`

### PRO purchase / restore (full flavor only, requires a Play license-tester account)

Play Billing cannot run on the JVM; the entitlement mapping/cache logic is unit-tested
with fakes (`PlayBillingProEntitlementTest`), but the end-to-end purchase path needs a
real device with Play services and a license-tester Google account.

- [ ] Fresh install (non-PRO): Settings → Style shows a **Themes** row with a lock icon
- [ ] Themes picker: all 5 themes show a lock; tapping one opens the **Get PRO** screen
- [ ] Get PRO screen shows the reframed copy ("Get PRO — support the project and unlock extras")
- [ ] Purchase tier 1 with a license tester → snackbar thank-you → back in Settings the
      **Themes** row now shows the **PRO** badge (no app restart required)
- [ ] Select **AMOLED black** → open Facebook → page background is true black
- [ ] Enable the free **Dark theme** toggle simultaneously → AMOLED still wins on
      conflicting selectors (background stays #000)
- [ ] Select an accent theme → top bar re-tints; select **Default** → theme cleared
- [ ] Restore: uninstall + reinstall with the same Google account → first launch
      re-verifies in background → PRO badge returns without a new purchase
- [ ] Offline grace: with PRO active, enable airplane mode, force-stop, relaunch →
      still PRO (cache honored; 30-day expiry not manually testable — covered by unit tests)
- [ ] Cancel the subscription in Play → after the subscription period lapses, relaunch
      online → PRO badge and themes revert to locked
- [ ] Each tier (`support_yearly_1..4`) individually unlocks PRO (spot-check at least two)

### PRO absence (fdroid flavor)

- [ ] Settings → Style has **no Themes row**, no PRO badge, no lock icons anywhere
- [ ] The support screen keeps the donation copy ("Support SlimSocial") and opens PayPal
- [ ] `release.yml` dex string check still reports `0` proprietary matches

## Sign-off before tagging

A release is sign-off-ready when:

- [ ] CI is green on the tag commit
- [ ] All checkboxes above are checked on at least the API 24 + API 33 emulators and the owner's real device
- [ ] At least one external user has tested the side-load migration over the Flutter app and reports no data loss
- [ ] The F-Droid `metadata/it.rignanese.leo.slimfacebook.yml` is up-to-date for the new versionCode/versionName

Then tag `v<versionName>` (e.g. `v26.05.03+117`) and push — `release.yml` does the rest.
