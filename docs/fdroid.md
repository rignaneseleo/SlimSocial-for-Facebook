# Building the F-Droid variant

F-Droid ships only free software. Two of this app's dependencies are not free:

| Package | What it is |
| --- | --- |
| `in_app_purchase` | Google Play Billing — the coffee and pizza donations |
| `in_app_review` | Play Core — the store's own rating sheet |

Removing the Dart calls is not enough. A Flutter plugin listed in
`pubspec.yaml` is registered by `GeneratedPluginRegistrant` and its Android
library lands in the apk whether or not any Dart code calls it. The dependency
itself has to go.

## The one command

From `SlimSocial_for_Facebook/`:

```bash
./scripts/fdroid_prepare.sh
flutter pub get --enforce-lockfile
flutter build apk
```

`fdroid_prepare.sh` is idempotent, and it fails loudly rather than quietly
leaving a proprietary package behind.

## What it changes

1. Copies `lib/services/store_binding_foss.dart` over
   `lib/services/store_binding.dart`. That file is four lines: it names the
   `StoreServices` implementation the app uses.
2. Deletes `lib/services/store_services_play.dart` — the only file in `lib/`
   that imports either package.
3. Drops both packages, and their federated siblings, from `pubspec.yaml` and
   `pubspec.lock`, so `--enforce-lockfile` still resolves.

Nothing else in the tree is touched. No `sed` runs over a screen.

## What the user sees

Every screen goes through the `StoreServices` interface and asks it what this
build can do, so nothing is left behind that does nothing when tapped:

| | Play build | F-Droid build |
| --- | --- | --- |
| Share the app | links to Google Play | links to F-Droid |
| Leave a 5 star review | opens the Play rating sheet | tile is not shown |
| Buy me a coffee / a pizza | in-app billing | one `donate` tile, opens PayPal in a browser |
| Rating prompt, 4-5 stars | opens the Play rating sheet | shows a thank-you toast |
| Rating prompt, 1-3 stars | feedback box | feedback box, unchanged |

Crash reporting is unaffected: `sentry_flutter` is free software, it is off
unless a DSN was compiled in with `--dart-define=SENTRY_DSN=...`, and a build
made from these instructions passes no DSN.

## Keeping it working

`test/fdroid_build_test.dart` fails if `in_app_purchase` or `in_app_review` is
imported anywhere in `lib/` except `store_services_play.dart`, and if the
script stops naming the file it deletes. Adding a proprietary call to a screen
breaks the test suite before it can break F-Droid's build server.

To add another store-only feature, put it on the `StoreServices` interface,
implement it in both `store_services_play.dart` and `store_services_foss.dart`,
and gate the UI on a capability getter.

## Releasing both variants

Both APKs are built and published by Codemagic, which triggers on tag
creation. There are two workflows, identical apart from four things:

| | Play workflow | F-Droid workflow |
| --- | --- | --- |
| Post-clone script | none | `cd "$CM_BUILD_DIR/SlimSocial_for_Facebook" && ./scripts/fdroid_prepare.sh` |
| `SENTRY_DSN` | set | **absent** |
| Google Play publishing | on | off |
| APK name in the post-build script | `..._v<tag>.apk` | `..._v<tag>-fdroid.apk` |

Putting the strip in the *post-clone* script matters: it has to happen before
Codemagic resolves dependencies, so that `flutter packages get` never sees the
proprietary packages and the plugin registrant is generated without them.

Leaving `SENTRY_DSN` out of the F-Droid workflow entirely, rather than having a
script decline to pass it, means that build cannot carry a DSN by accident.

Each workflow ends with this post-build script, which attaches its APK to the
GitHub release for the tag. Only the `APK=` line differs between the two — it
is `-fdroid` in the F-Droid workflow and absent in the Play one:

```bash
set -euo pipefail
[ -n "${CM_TAG:-}" ] || { echo "not a tag build, skipping"; exit 0; }
cd "$CM_BUILD_DIR/SlimSocial_for_Facebook/build/app/outputs/flutter-apk"
APK="SlimSocial_for_Facebook_v${CM_TAG}-fdroid.apk"
mv app-release.apk "$APK"
gh release view "$CM_TAG" >/dev/null 2>&1 || \
  gh release create "$CM_TAG" --title "SlimSocial for Facebook $CM_TAG" --generate-notes || true
gh release upload "$CM_TAG" "$APK" --clobber
```

The rename is needed because both workflows produce `app-release.apk`, so the
variant has to be written into the file name before upload.

The name is written out in each script rather than pulled from a shared
environment variable on purpose. Codemagic groups its variables, and a suffix
set in a group both workflows use would put `-fdroid` on both APKs.

The `view || create || true` shape is needed because the two workflows run in
parallel on the same tag. Whichever finishes first creates the release; the
second either finds it, or loses the race on `create` and still succeeds at
`upload --clobber`. Both orders work.

The token comes from `GITHUB_TOKEN`, a secret environment variable on both
workflows holding a personal access token with write access to the repository.
Codemagic's GitHub app connection lets it clone the repository and report build
statuses, but does not hand build scripts a usable token, so this one has to be
added by hand. (`gh` checks `GH_TOKEN` first and falls back to `GITHUB_TOKEN`,
so either name works.)

## For the fdroiddata recipe

The whole `prebuild:` block becomes:

```yaml
    prebuild:
      - flutterVersion=$(grep flutter\" .fvmrc | cut -d "\"" -f 4)
      - '[[ $flutterVersion ]]'
      - git -C $$flutter$$ checkout -f $flutterVersion
      - ./scripts/fdroid_prepare.sh
      - export PUB_CACHE=$(pwd)/.pub-cache
      - $$flutter$$/bin/flutter config --no-analytics
      - $$flutter$$/bin/flutter packages pub get --enforce-lockfile
```

The four `sed` lines that edited `pubspec.yaml`, `pubspec.lock` and
`lib/screens/settings_page.dart` are no longer needed.
