# Permissions and custom user agent repair

Three defects that field reports and store reviews keep surfacing, all confirmed
against the current code:

1. **The photos toggle cannot stay on, and gates something that was never
   restricted.** `Permission.photos` resolves to `READ_MEDIA_IMAGES`, which only
   exists on API 33+, so on Android 12 and below the grant is unobtainable and
   the screen's existing OS→preference sync rewrites the stored boolean to
   `false` on every entry. Meanwhile the operation it guards — the system
   document picker — needs no runtime permission at all, so photo posting works
   regardless. Users see a dead switch next to a feature that works.
2. **A custom user agent does nothing until the app is force-quit.** The agent is
   bound to the `WebViewController` when it is constructed. The settings dialog
   only writes the preference and pops; nothing rebuilds the controller or
   restarts the app, so the change never takes effect in the running session —
   unlike custom CSS/JS, which are re-injected on reload, and unlike the proxy
   dialog, which already calls `Restart.restartApp()`.
3. **Messenger voice/video calls cannot get the microphone.** The webview
   permission handler supports the camera only and denies the microphone
   outright, and the manifest declares no `RECORD_AUDIO`.

None of this touches the injection/ad work in the other two plans; it is a
self-contained pass over settings, the webview permission handler, and the
Android manifest.

---

## Current State

Verified in the tree at planning time:

- `SpKeys` (`lib/consts.dart`) defines `gpsPermission`, `cameraPermission`,
  `photosPermission` — no microphone key. The historical
  `photo_permission` / `photos_permission` mismatch is already repaired; both the
  settings screen and both webviews read `photos_permission`.
- `lib/screens/settings_page.dart`
  - each permission `SettingsTile.switchTile` sets `initialValue` from
    `sp.getBool(<key>)`, with a `//fixme … .isgranted` comment (lines ~157, 177,
    197);
  - the turn-*off* branch of `handlePermission` calls `openAppSettings()` even
    though SlimSocial's own gate is the stored boolean;
  - `showTextInputDialog` (used for custom UA/CSS/JS) writes `spKey` and the
    `<spKey>_enabled` switch, then pops. The `custom_useragent` tile does **not**
    restart afterwards; the `custom_proxy` tile *does* (`Restart.restartApp()`).
- `lib/controllers/fb_controller.dart` — `getUserAgent()` returns the custom
  agent through `_getOverride`, which requires both `<key>_enabled` **and** a
  non-blank value. It is correct; the problem is purely that its result is only
  read when the controller is built.
- `lib/utils/webview_permissions.dart` — `isWebViewPermissionSupported` accepts
  a set only when every entry is `camera`; the microphone is deliberately denied.
  `handleWebViewPermissionRequest` is wired to both webviews'
  `onPermissionRequest`.
- `android/app/src/main/AndroidManifest.xml` — declares `CAMERA` plus two
  `android.hardware.camera*` `uses-feature required="false"` entries. No
  `RECORD_AUDIO`, no microphone feature.
- `pubspec.yaml` already depends on `permission_handler`; `Permission.microphone`
  is available without a new dependency.

| # | Problem | Task |
|---|---|---|
| 1 | File upload is gated on `Permission.photos`, unobtainable below API 33 and unnecessary for the system picker | 3 |
| 2 | Turn-off bounces the user to system settings unnecessarily; the sync `setState`s without a `mounted` check | 3 |
| 3 | Custom user agent never re-applies without a manual force-quit | 4 |
| 4 | Messenger cannot obtain the microphone; no `RECORD_AUDIO` | 2 |

---

## Task 1: Preflight — establish the baseline

No code changes. Confirm the workspace is green before touching it, so a later
red result is unambiguously this plan's doing.

- [ ] **Step 1: Confirm the SDK**

```bash
cd SlimSocial_for_Facebook && fvm flutter --version
```

Expected: Flutter 3.44.8. If `fvm` reports a different pin, stop and reconcile
`.fvmrc` before continuing — every command below assumes it.

- [ ] **Step 2: Analyzer and tests are clean**

```bash
fvm flutter analyze lib/ test/ && fvm flutter test
```

Expected: `No issues found!` then the whole suite green. Record the test count.

- [ ] **Step 3: Clean tree**

```bash
git status --porcelain
```

Expected: empty.

---

## Task 2: Give Messenger the microphone

The webview permission handler answers camera requests and denies everything
else, so a Messenger voice or video call can never get the mic. This task adds
first-class microphone support: manifest permission, a settings toggle, and the
handler branch.

`isWebViewPermissionSupported` is a pure function, so it drives the TDD here.

**Files:**
- Modify: `SlimSocial_for_Facebook/lib/consts.dart`
- Modify: `SlimSocial_for_Facebook/lib/utils/webview_permissions.dart`
- Modify: `SlimSocial_for_Facebook/lib/screens/settings_page.dart`
- Modify: `SlimSocial_for_Facebook/android/app/src/main/AndroidManifest.xml`
- Modify: `SlimSocial_for_Facebook/assets/lang/en-US.json`
- Modify: `SlimSocial_for_Facebook/assets/lang/_.json`
- Modify: `SlimSocial_for_Facebook/test/consts_test.dart`
- Create: `SlimSocial_for_Facebook/test/utils/webview_permissions_test.dart`

- [ ] **Step 1: Write the failing tests**

Add to `test/consts_test.dart`, inside the `SpKeys` group's disk-keys test:

```dart
      expect(SpKeys.micPermission, 'mic_permission');
```

Create `test/utils/webview_permissions_test.dart`:

`WebViewPermissionResourceType` is a **class with static consts, not an enum**, and it defines only `camera` and `microphone`. Anything else is contributed by a platform package — `webview_flutter_android` adds `midiSysex` and `protectedMediaId`. That package is already a direct dependency, so the test can import it to build a genuinely unsupported request.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:slimsocial_for_facebook/utils/webview_permissions.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

void main() {
  group('isWebViewPermissionSupported', () {
    test('rejects an empty request', () {
      expect(isWebViewPermissionSupported(const {}), isFalse);
    });

    test('supports a camera-only request', () {
      expect(
        isWebViewPermissionSupported(
          const {WebViewPermissionResourceType.camera},
        ),
        isTrue,
      );
    });

    test('supports a microphone-only request', () {
      expect(
        isWebViewPermissionSupported(
          const {WebViewPermissionResourceType.microphone},
        ),
        isTrue,
      );
    });

    test('supports a combined camera + microphone request (video call)', () {
      expect(
        isWebViewPermissionSupported(
          const {
            WebViewPermissionResourceType.camera,
            WebViewPermissionResourceType.microphone,
          },
        ),
        isTrue,
      );
    });

    test('still rejects an unknown resource type', () {
      // A request that mixes in anything we cannot satisfy must be refused
      // whole, not partially granted. `midiSysex` is a real Android-only type
      // the webview can ask for, so this is the actual mixed request we must
      // refuse — not a hypothetical one.
      expect(
        isWebViewPermissionSupported(
          const {
            WebViewPermissionResourceType.camera,
            AndroidWebViewPermissionResourceType.midiSysex,
          },
        ),
        isFalse,
      );
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
fvm flutter test test/consts_test.dart test/utils/webview_permissions_test.dart
```

Expected: `mic_permission` undefined, and the microphone cases fail.

- [ ] **Step 3: Add the preference key**

In `lib/consts.dart`, add to `SpKeys` beside the other permission keys:

```dart
  static const String micPermission = "mic_permission";
```

- [ ] **Step 4: Support the microphone in the handler**

Rewrite `lib/utils/webview_permissions.dart` so both resource types are
accepted, and each is gated on its own settings toggle plus the matching OS
grant:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:slimsocial_for_facebook/consts.dart';
import 'package:slimsocial_for_facebook/main.dart';
import 'package:slimsocial_for_facebook/utils/utils.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// The webview resource types SlimSocial can answer.
const Set<WebViewPermissionResourceType> _supported = {
  WebViewPermissionResourceType.camera,
  WebViewPermissionResourceType.microphone,
};

/// Whether SlimSocial knows how to answer a request for [types].
///
/// A request is only supported when it is non-empty and every entry is
/// something we can satisfy — a request that mixes in an unknown type is
/// refused whole rather than partially granted.
bool isWebViewPermissionSupported(Set<WebViewPermissionResourceType> types) {
  return types.isNotEmpty && types.every(_supported.contains);
}

/// The settings toggle and OS permission backing each resource type.
const Map<WebViewPermissionResourceType, String> _settingKey = {
  WebViewPermissionResourceType.camera: SpKeys.cameraPermission,
  WebViewPermissionResourceType.microphone: SpKeys.micPermission,
};

const Map<WebViewPermissionResourceType, Permission> _osPermission = {
  WebViewPermissionResourceType.camera: Permission.camera,
  WebViewPermissionResourceType.microphone: Permission.microphone,
};

/// Answers a permission request coming from the web content.
///
/// Every requested type must clear two gates: the user opted in from settings,
/// and Android granted the OS-level permission. A video call asks for camera
/// and microphone together, so both must pass or the whole request is denied.
Future<void> handleWebViewPermissionRequest(
  WebViewPermissionRequest request,
) async {
  if (!isWebViewPermissionSupported(request.types)) {
    return request.deny();
  }

  for (final type in request.types) {
    final settingKey = _settingKey[type]!;
    if (!(sp.getBool(settingKey) ?? false)) {
      showToast("check_permission".tr());
      return request.deny();
    }

    final status = await _osPermission[type]!.request();
    if (!status.isGranted) {
      showToast("check_permission".tr());
      return request.deny();
    }
  }

  return request.grant();
}
```

- [ ] **Step 5: Declare the microphone in the manifest**

In `android/app/src/main/AndroidManifest.xml`, next to the `CAMERA` block, add —
mirroring the existing `required="false"` pattern so the Play Store does not
treat a microphone as a hard device requirement:

```xml
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <!-- declaring RECORD_AUDIO makes the Play Store treat a microphone as
         required unless we opt out, and a Facebook wrapper must install on
         devices without one. -->
    <uses-feature
        android:name="android.hardware.microphone"
        android:required="false" />
```

- [ ] **Step 6: Add the settings toggle and register it for syncing**

Two edits in `lib/screens/settings_page.dart`.

First, add the microphone to the `permissions` map (around line 34). Without
this, `_updatePermissionsToggle()` never syncs the mic and its stored boolean
drifts from the real grant:

```dart
  final Map<String, Permission> permissions = const {
    SpKeys.gpsPermission: Permission.locationWhenInUse,
    SpKeys.cameraPermission: Permission.camera,
    SpKeys.photosPermission: Permission.photos,
    SpKeys.micPermission: Permission.microphone,
  };
```

Second, in the permissions `SettingsSection`, add a tile after the camera tile
matching the camera tile's structure but using `Permission.microphone`,
`SpKeys.micPermission`, `Icons.mic`, and title `'mic_permission'.tr()`.

- [ ] **Step 7: Add the strings**

Add `"mic_permission"` to `assets/lang/en-US.json` and `assets/lang/_.json`
(value e.g. `"Microphone (calls)"`). If `test/lang_test.dart` exists (added by
the webview-injection plan), append `'mic_permission'` to its fallback key list.

- [ ] **Step 8: Verify the whole project**

```bash
fvm flutter analyze lib/ test/ && fvm flutter test
```

Expected: `No issues found!` then all tests pass.

- [ ] **Step 9: Commit**

```bash
git add SlimSocial_for_Facebook/lib/consts.dart SlimSocial_for_Facebook/lib/utils/webview_permissions.dart SlimSocial_for_Facebook/lib/screens/settings_page.dart SlimSocial_for_Facebook/android/app/src/main/AndroidManifest.xml SlimSocial_for_Facebook/assets/lang/en-US.json SlimSocial_for_Facebook/assets/lang/_.json SlimSocial_for_Facebook/test/consts_test.dart SlimSocial_for_Facebook/test/utils/webview_permissions_test.dart
git commit -m "feat: support the microphone for webview voice and video calls"
```

---

## Task 3: Stop gating file upload on a permission it never needed

The reported symptom is a photos toggle that will not stay on while photo posting
works anyway. The cause is not a missing OS→preference sync — that sync already
exists and runs on every entry to the screen (`_updatePermissionsToggle`, called
from `initState`). The cause is *what it syncs*:

- `Permission.photos` maps to `READ_MEDIA_IMAGES`, which only exists on **API 33+**.
  Below that the grant is unobtainable, so the sync writes `false` on every entry
  and the toggle physically cannot stay on.
- What the toggle gates — `FilePicker.platform.pickFiles()` in
  `setOnShowFileSelector` — goes through the system document picker, which needs
  **no runtime permission on any API level**. The app was refusing an operation
  the OS never restricted.

So the fix is to delete the gate, not to strengthen it. Camera and microphone
keep their toggles: those gate real `WebViewPermissionRequest`s that genuinely
require a grant.

Two smaller defects in the same code are fixed here because this task is already
editing it: `_updatePermissionsToggle` calls `setState` after an `await` with no
`mounted` check, and `handlePermission`'s turn-*off* branch drags the user into
system settings.

**Files:**
- Modify: `SlimSocial_for_Facebook/lib/screens/settings_page.dart`
- Modify: `SlimSocial_for_Facebook/lib/screens/home_page.dart`
- Modify: `SlimSocial_for_Facebook/lib/screens/messenger_page.dart`

- [ ] **Step 1: Open the file picker unconditionally**

`setOnShowFileSelector` is duplicated verbatim in `home_page.dart` (~line 101)
and `messenger_page.dart` (~line 75). In **both**, replace the body with:

```dart
        ..setOnShowFileSelector(
          (FileSelectorParams params) async {
            // The system document picker needs no runtime permission, so there
            // is nothing to gate: SlimSocial used to refuse this when its own
            // photos toggle was off, which on Android 12 and below could never
            // be switched on.
            final result = await FilePicker.platform.pickFiles();

            if (result != null && result.files.single.path != null) {
              final file = File(result.files.single.path!);
              return [file.uri.toString()];
            }
            return [];
          },
        )
```

Leave the manifest's storage and media permissions alone — the image-download
path still relies on them.

- [ ] **Step 2: Remove the photos toggle**

In `lib/screens/settings_page.dart`:

- delete the `SpKeys.photosPermission: Permission.photos` entry from the
  `permissions` map, so the sync no longer clobbers a key nothing reads;
- delete the photos `SettingsTile.switchTile` (the one titled
  `'photo_permission'.tr()`).

Keep the `SpKeys.photosPermission` constant and its assertion in
`consts_test.dart`. The key exists on user devices, and the constant documents
that the string is taken so a future setting does not silently reuse it.

- [ ] **Step 3: Guard the sync against a disposed screen**

`_updatePermissionsToggle` awaits inside a loop and then calls `setState`. If the
user leaves the settings screen mid-loop that throws. Bail out instead:

```dart
  Future<void> _updatePermissionsToggle() async {
    for (final entry in permissions.entries) {
      final permissionValue = await entry.value.isGranted;
      if (!mounted) return;
      setState(() {
        sp.setBool(entry.key, permissionValue);
      });
    }
  }
```

- [ ] **Step 4: Turn-off should not open system settings**

In `handlePermission`, delete the turn-off branch that calls `openAppSettings()`.
Turning a toggle off is SlimSocial's own gate: store `false` and let the webview
handler deny future requests. Revoking the OS grant stays the user's choice, but
the app must not force them into system settings to express "no".

The turn-*on* branch is unchanged: request the permission, reflect the real result.

- [ ] **Step 5: Drop the stale `//fixme` comments**

Remove the `//fixme bug on sp, I should use the permission handler .isgranted`
comments on the remaining tiles. They are wrong: the toggles *are* driven from
`isGranted` via `_updatePermissionsToggle`, and for camera and microphone that is
the correct behaviour.

- [ ] **Step 6: Verify the whole project**

```bash
fvm flutter analyze lib/ test/ && fvm flutter test
```

Expected: `No issues found!` then all tests pass. (Behaviour is device-verified
in Task 5; this gate only proves nothing else regressed.)

- [ ] **Step 7: Commit**

```bash
git add SlimSocial_for_Facebook/lib/screens/settings_page.dart SlimSocial_for_Facebook/lib/screens/home_page.dart SlimSocial_for_Facebook/lib/screens/messenger_page.dart
git commit -m "fix: stop gating webview file upload on an unneeded permission"
```

---

## Task 4: Apply a custom user agent without a force-quit

The agent is set on the `WebViewController` at construction, so changing it in
settings has no effect until the process is restarted. The proxy dialog already
handles this class of change by restarting; do the same for the user agent.

**Files:**
- Modify: `SlimSocial_for_Facebook/lib/screens/settings_page.dart`

- [ ] **Step 1: Confirm the resolver is already covered — do not add tests**

The resolver is not the bug and is already fully specified by four existing tests
in `test/controllers/fb_controller_test.dart`:

- `honours the custom agent once it is enabled`
- `ignores a custom agent that was saved but left disabled`
- `ignores a blank custom agent`
- `uses the light agent together with mbasic`

Read them and confirm they still pass. Do **not** add equivalents — an earlier
draft of this plan proposed two tests that duplicated the first two outright.

There is nothing new to unit-test here: `getUserAgent()` already returns the
right string, and the defect is purely that a running `WebViewController` never
re-reads it. That is UI lifecycle, verified on a device in Task 5.

Note the idiom if you touch this file: it seeds preferences with
`await withPrefs({...})` (which calls `SharedPreferences.setMockInitialValues`
and is reset by `setUp`), never bare `sp.setBool`/`sp.setString`. Mixing the two
leaks state between tests.

```bash
fvm flutter test test/controllers/fb_controller_test.dart
```

Expected: green, unchanged.

- [ ] **Step 2: Restart when the effective agent changed**

In `lib/screens/settings_page.dart`, in the `custom_useragent`
`SettingsTile.navigation` `onPressed`, capture the resolved agent before and
after the dialog and restart only when it actually changed:

```dart
                onPressed: (context) async {
                  final before = PrefController.getUserAgent();
                  await showTextInputDialog(
                    spKey: SpKeys.customUserAgent,
                    hint: PrefController.getUserAgent(),
                  );
                  setState(() {});
                  if (PrefController.getUserAgent() != before) {
                    showToast("rebooting".tr());
                    Restart.restartApp();
                  }
                },
```

This covers every path that changes the outcome — enabling or disabling the
switch, editing the string, or deleting it — because all of them move
`getUserAgent()`. Paths that do not change it (open and cancel) do not restart.

- [ ] **Step 3: Verify the whole project**

```bash
fvm flutter analyze lib/ test/ && fvm flutter test
```

Expected: `No issues found!` then all tests pass.

- [ ] **Step 4: Commit**

```bash
git add SlimSocial_for_Facebook/lib/screens/settings_page.dart
git commit -m "fix: apply a changed custom user agent by restarting the app"
```

---

## Task 5: Manual verification on a device

The permission flows and the user-agent restart have no Dart-side runtime, so
confirm them once in the real app.

**Files:** none — this task only runs and observes.

- [ ] **Step 1: Launch**

```bash
fvm flutter run --debug
```

- [ ] **Step 2: Camera toggle reflects reality**

Grant the app camera permission in system settings, then open SlimSocial's
settings. The camera toggle is **on** without being tapped. Revoke it in system
settings, return: it is **off**.

- [ ] **Step 3: Camera works in the feed**

With the camera toggle on, open a Facebook composer that offers the camera and
take a photo.

Expected: the camera opens.

- [ ] **Step 3b: File upload works with no photos toggle at all**

This is the check on Task 3, and it matters most on an **API 29 or 31** device —
the versions where the old gate could never be switched on. Attach a photo to a
post or a message using the file picker (not the camera).

Expected: the system document picker opens immediately and the file attaches.
There is no photos toggle in settings any more, and no `check_permission` toast.
Before this plan, on these API levels the picker refused to open.

- [ ] **Step 4: Microphone in a Messenger call**

Enable the new microphone toggle. Start a Messenger voice call.

Expected: the mic is offered and the call has audio. Deny the toggle and retry:
the request is refused cleanly (no hang).

- [ ] **Step 5: Turn-off stays in the app**

Turn the camera toggle off.

Expected: it switches off in place — no bounce to system settings.

- [ ] **Step 6: Custom user agent applies immediately**

In advanced settings, enable a custom user agent, set it to a recognisable
string, and save.

Expected: the app restarts on its own, and the feed is then served under the new
agent (verify via a WebView console `navigator.userAgent`, or a site that echoes
it). Before this plan the change did nothing until a manual force-quit.

---

## Self-Review

**Spec coverage.** Each defect in *Current State* maps to a task: problems 1–2 →
Task 3, problem 3 → Task 4, problem 4 → Task 2. Task 1 is the baseline gate; Task
5 covers the behaviour no unit test can reach.

**Every task commits green.** Only Task 2 is test-anchored, because
`isWebViewPermissionSupported` is the only pure function this plan introduces.
Tasks 3 and 4 are UI and permission-plugin behaviour that needs platform mocks to
unit-test, so they are device-verified in Task 5 and their `analyze && test` gate
only proves nothing else regressed. Every task ends on
`fvm flutter analyze lib/ test/ && fvm flutter test` before its commit.

**Validated against the real APIs, not from memory.**
`WebViewPermissionResourceType` is a class with exactly two members (`camera`,
`microphone`); unsupported types come from platform packages, which is why Task 2
uses `AndroidWebViewPermissionResourceType.midiSysex`. The class overrides no
`==`, and the Android implementation returns the canonical `static const`
instances, so `_supported.contains` is sound. `Permission.microphone` exists in
the pinned `permission_handler`. `AndroidSettingsTile` is a `StatelessWidget`
reading `initialValue` straight into `Switch(value:)`, so the toggles do track
rebuilds — which is what ruled out the widget as the cause of the stuck switch
and pointed at `Permission.photos` instead.

**No duplicated tests.** Task 4 deliberately adds none: four existing tests in
`fb_controller_test.dart` already specify the user-agent resolver, and an earlier
draft of this plan duplicated two of them. Where preferences are seeded, the file's
`withPrefs({...})` helper is used, never bare `sp.setBool`/`sp.setString`, so
`setUp` can reset state between tests.

**Cross-plan interactions.** Task 4 touches no tests, so it cannot collide with
the injection plan's Task 7, which gives `getUserAgent` a `role` parameter; the
existing no-argument calls stay valid either way. Task 2 adds `mic_permission` to
the locale files and, if the injection plan's `test/lang_test.dart` exists, to its
key list — the two plans do not otherwise touch the same code.

**Names used consistently.** `SpKeys.micPermission` = `"mic_permission"` is
defined in Task 2 and reused by the toggle and the `permissions` map (both Task 2).
`SpKeys.photosPermission` survives Task 3 as a reserved on-disk key with nothing
reading it, kept referenced by `consts_test.dart`.
`isWebViewPermissionSupported` and `handleWebViewPermissionRequest` keep their
signatures. The manifest microphone entries mirror the existing camera ones.

---

## Follow-up work (separate plans)

1. **Per-permission rationale prompts.** Show why the mic/camera is needed before
   the OS dialog, which lifts grant rates — especially valuable given how much of
   the base is on first-party OEM permission managers that bury re-grant.
2. **Photo picker vs. broad media permission.** `READ_MEDIA_IMAGES` could become
   the Android 14 selected-photos flow, narrowing what the app can see.
