## What and why

<!-- What changes for the user, and which issue it closes. -->

## Tests

- [ ] `flutter test` passes

## Device check — required when this PR changes any of these

A user agent string in `lib/consts.dart`, the CSS in `lib/utils/css.dart`, the JS in
`lib/utils/js.dart`, or WebView settings. Facebook serves a different page per
user agent, and unit tests cannot see how it behaves.

Test on a phone signed in to Facebook, with Android System WebView 130 or newer.
Write the device, Android version and WebView version
(Settings > Apps > Android System WebView).

Device / Android / WebView:

- [ ] `scripts/qa/scroll_smoke.py -s <serial>` passes: the feed scrolls with one finger
- [ ] Pinch zoom and two-finger scroll still work
- [ ] Tap Like, and long-press Like to open the reactions
- [ ] Open the comments of a post and scroll them
- [ ] Open a Reel and scroll to the next one
- [ ] Same checks with "Use desktop site" on

If the test account is not signed in, write "device check: not verified" here and keep
the PR in draft.

## Release PRs only

- [ ] `scripts/release_gate.py` exits 0, or every issue it names is fixed or triaged
- [ ] The device check above passes on the release build
- [ ] Rollout starts at 20% or less. Before it goes higher, run the release gate again
