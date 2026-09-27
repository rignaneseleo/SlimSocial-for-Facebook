## What and why

<!-- What changes for the user, and which issue it closes. -->

## Tests

- [ ] `flutter test` passes

## Device check — required when this PR changes any of these

A user agent string in `lib/consts.dart`, the CSS in `lib/utils/css.dart`, the JS in
`lib/utils/js.dart`, or WebView settings. Facebook serves a different page per
user agent, and unit tests cannot see how it behaves.

On a phone signed in to Facebook, with Android System WebView 130 or newer:

- [ ] `scripts/qa/scroll_smoke.py -s <serial> --out <dir>` passes
- [ ] The feature this PR changes works on the phone

Device / Android / WebView version:

If the phone is not signed in, write "device check: not verified" and keep the PR in draft.

## Release PRs only

- [ ] `scripts/release_gate.py` exits 0
- [ ] The device check above passes on the release build
- [ ] Rollout starts at 20% or less. Run the release gate again before it goes higher
