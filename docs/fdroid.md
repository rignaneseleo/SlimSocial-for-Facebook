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
