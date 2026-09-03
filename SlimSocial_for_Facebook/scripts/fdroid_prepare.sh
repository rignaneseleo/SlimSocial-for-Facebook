#!/bin/bash
#
# Turns this checkout into the F-Droid build.
#
# F-Droid ships only free software, so the apk it builds must contain no
# `in_app_purchase` (Google Play Billing) and no `in_app_review` (Play Core).
# Removing the Dart calls is not enough: a Flutter plugin listed in
# pubspec.yaml is registered by GeneratedPluginRegistrant and its Android
# library lands in the apk whether or not any Dart code calls it. So the
# dependency itself has to go.
#
# This script is the only supported way to do that. Run it after checkout and
# before `flutter pub get`:
#
#     ./scripts/fdroid_prepare.sh
#     flutter pub get
#     flutter build apk
#
# It is idempotent: running it twice changes nothing the second time.
#
# What it does, and why each step is safe:
#
#   1. Swaps lib/services/store_binding.dart for its F-Droid twin. That file
#      is four lines and names the implementation the app uses; every screen
#      goes through the StoreServices interface, never through a store SDK.
#   2. Deletes lib/services/store_services_play.dart — the one file in lib/
#      that imports either package.
#   3. Drops the two dependencies from pubspec.yaml and pubspec.lock, so
#      `flutter pub get --enforce-lockfile` still resolves.
#
# The screens ask StoreServices.canPurchase / canRequestReview and show a
# plain donation link instead of the billing tiles, so nothing is left behind
# that does nothing when tapped.
#
# test/fdroid_build_test.dart fails the build if a proprietary import ever
# appears outside store_services_play.dart, which is what keeps this script
# from silently going out of date.

set -euo pipefail

cd "$(dirname "$0")/.."

readonly BINDING="lib/services/store_binding.dart"
readonly BINDING_FOSS="lib/services/store_binding_foss.dart"
readonly PLAY_IMPL="lib/services/store_services_play.dart"

# The pub packages that must not reach the apk. Keep in step with
# test/fdroid_build_test.dart, which asserts the same list is unreachable.
readonly PROPRIETARY_PACKAGES=(
  in_app_purchase
  in_app_review
)

fail() {
  echo "fdroid_prepare: $1" >&2
  exit 1
}

[[ -f pubspec.yaml ]] || fail "run this from the Flutter project (pubspec.yaml not found)"
[[ -f "$BINDING_FOSS" ]] || fail "$BINDING_FOSS is missing"

# 1 + 2 — source.
cp "$BINDING_FOSS" "$BINDING"
rm -f "$PLAY_IMPL"

# 3 — pubspec.yaml. Each of these is a single `  name: version` line; the
# git-sourced dependencies in this file are indented deeper and are untouched.
for pkg in "${PROPRIETARY_PACKAGES[@]}"; do
  sed -i -e "/^  ${pkg}:/d" pubspec.yaml
done

# 3 — pubspec.lock. Matched by *prefix*, not by exact name: each package pulls
# federated siblings (in_app_purchase_android, in_app_review_platform_interface
# and so on) that nothing else depends on. Leaving them behind makes
# `flutter pub get --enforce-lockfile` fail, because the lockfile would then
# describe a resolution that no longer happens. An entry runs from its name to
# the `    version:` line that closes it.
for pkg in "${PROPRIETARY_PACKAGES[@]}"; do
  sed -i -e "/^  ${pkg}/,/^    version:/d" pubspec.lock
done

# Prove it rather than assume it. A sed that quietly matches nothing is how a
# Play Billing library reaches an F-Droid apk in the first place.
for pkg in "${PROPRIETARY_PACKAGES[@]}"; do
  if grep -q "^  ${pkg}" pubspec.yaml; then
    fail "$pkg is still in pubspec.yaml"
  fi
  if grep -q "^  ${pkg}" pubspec.lock; then
    fail "$pkg is still in pubspec.lock"
  fi
done

imports_pattern="$(IFS='|'; echo "${PROPRIETARY_PACKAGES[*]}")"
if grep -rnE --include='*.dart' "package:(${imports_pattern})/" lib/; then
  fail "a proprietary import is still reachable from lib/ (see the lines above)"
fi

echo "fdroid_prepare: done — this checkout now builds the F-Droid variant."
