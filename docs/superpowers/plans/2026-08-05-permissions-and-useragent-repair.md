# Permissions and custom user agent repair

Three defects that field reports and store reviews keep surfacing, all confirmed
against the current code:

1. **The camera / photos toggles lie.** Their on/off state is read from a stored
   boolean, not from the actual OS grant, so a switch can show *off* while the
   permission is granted (and the in-webview camera path, gated on that same
   boolean, then does nothing). The code carries three `//fixme … should use the
   permission handler .isgranted` notes admitting exactly this.
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
| 1 | Camera/photos toggle state comes from a stored bool, not the OS grant | 3 |
| 2 | Turn-off bounces the user to system settings unnecessarily | 3 |
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

## Task 3: Make the permission toggles tell the truth

The camera / photos / mic toggles read their state from a stored boolean that
can disagree with the real OS grant, and turning one off drags the user into
system settings. Drive the displayed state from the live permission status, and
make turn-off a local action.

This is permission-plugin and UI behaviour that a unit test cannot reach without
platform mocks, so it is verified on a device in Task 5. The change itself is
small and mechanical.

**Files:**
- Modify: `SlimSocial_for_Facebook/lib/screens/settings_page.dart`

- [ ] **Step 1: Seed the stored booleans from the OS on screen load**

In the settings screen's `initState` (or the existing async init), for each of
`Permission.camera`, `Permission.photos`, `Permission.microphone`, read
`await <permission>.status` and write the matching `SpKeys` boolean to
`isGranted`, then `setState`. This makes the stored gate — which the webview
handler reads — match reality on every entry to the screen, and makes the
switches' `initialValue` correct because they read the same booleans.

Guard any `BuildContext` use after the `await` with a `mounted` check;
`use_build_context_synchronously` will flag it otherwise.

- [ ] **Step 2: Turn-off should not open system settings**

In `handlePermission`, delete the turn-off branch that calls `openAppSettings()`.
Turning a toggle off is SlimSocial's own gate: set the boolean false and let the
webview handler deny future requests. Revoking the OS grant itself remains the
user's choice in system settings, but the app must not force them there.

The turn-*on* branch is unchanged: request the permission, and reflect the real
result.

- [ ] **Step 3: Drop the stale `//fixme` comments**

Remove the three `//fixme bug on sp, I should use the permission handler
.isgranted` comments — they describe the bug this task fixes.

- [ ] **Step 4: Verify the whole project**

```bash
fvm flutter analyze lib/ test/ && fvm flutter test
```

Expected: `No issues found!` then all tests pass. (Behaviour is device-verified
in Task 5; this gate only proves nothing else regressed.)

- [ ] **Step 5: Commit**

```bash
git add SlimSocial_for_Facebook/lib/screens/settings_page.dart
git commit -m "fix: drive permission toggles from the real OS grant"
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

Expected: the camera opens. Before this plan, a stale boolean could leave it
dead despite an OS grant.

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

**Every task commits green.** Tasks 2 and 4 are test-anchored (a pure function
and the agent resolver). Task 3 is device-verified because the permission plugin
needs platform mocks to unit-test; its `analyze && test` gate only proves nothing
else regressed. Every task ends on `fvm flutter analyze lib/ test/ &&
fvm flutter test` before its commit.

**Cross-plan interactions.** Task 4's tests call `PrefController.getUserAgent()`
with no argument; if the webview-injection plan's Task 7 has added a `role`
parameter, the no-argument call still resolves to the feed default and the tests
stay valid. Task 2 adds `mic_permission` to the locale files and, if the
injection plan's `test/lang_test.dart` exists, to its key list — the two plans do
not otherwise touch the same code.

**Names used consistently.** `SpKeys.micPermission` = `"mic_permission"` is
defined in Task 2 and reused by the toggle (Task 2) and the status sync (Task 3).
`isWebViewPermissionSupported` and `handleWebViewPermissionRequest` keep their
signatures. The manifest microphone entries mirror the existing camera ones.

---

## Follow-up work (separate plans)

1. **Per-permission rationale prompts.** Show why the mic/camera is needed before
   the OS dialog, which lifts grant rates — especially valuable given how much of
   the base is on first-party OEM permission managers that bury re-grant.
2. **Photo picker vs. broad media permission.** `READ_MEDIA_IMAGES` could become
   the Android 14 selected-photos flow, narrowing what the app can see.
