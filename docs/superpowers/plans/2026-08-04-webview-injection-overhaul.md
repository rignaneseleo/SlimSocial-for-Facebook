# WebView Injection Pipeline Overhaul — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the injected CSS/JS layer correct, precise and theme-aware — so styling lands once per document, sponsored posts are found by markup rather than by guessing at words, and ordinary posts are never destroyed by a false positive.

**Architecture:** The injection layer already builds its JavaScript with `jsonEncode` and keeps a global observer sentinel. What remains is hygiene and precision: give every stylesheet a stable element id so navigations stop stacking `<style>` tags, write CSS through `textContent` into `<head>` instead of `innerHTML` into `<body>`, survive the case where the document finished parsing before the script ran, and replace single-tier text matching with a cheapest-check-first cascade over the locale-independent attributes Facebook puts on sponsored units. Detected ads get collapsed in place rather than having their subtree overwritten.

**Tech Stack:** Flutter 3.44.8 via fvm, Dart, `webview_flutter` 4.10.0, `shared_preferences`, `easy_localization`, `flutter_test`, `very_good_analysis` lints.

**Every command below runs from `SlimSocial_for_Facebook/`** and is prefixed with `fvm` — the project pins its SDK through `.fvmrc`, and a bare `flutter` is not on `PATH`.

**Baseline:** 52 tests pass. Do not let that number go down.

**Out of scope:** background notifications. `webview_flutter` has no headless mode, so that needs a new dependency plus platform channels and gets its own plan.

---

## Current State

Already in place on `master` — do not redo these:

- `CustomJs.injectCssFunc` embeds CSS with `jsonEncode`, so quotes and newlines no longer break the injection
- `CustomJs.removeAdsObserver` guards on `window.newPostsObserver`, so the observer actually installs
- `MyCss` collapses whitespace to a single space instead of stripping it, so multi-token values survive
- `SpKeys` centralises the `SharedPreferences` key strings
- `CustomCss.buildFacebookCss` / `buildMessengerCss` assemble the stylesheet and include the user's own CSS
- A `test/` directory with 52 passing tests
- `.fvmrc` pins Flutter 3.44.8, so `in_app_purchase ^3.3.0` resolves and the suite runs

Still open, and what this plan covers:

| # | Problem | Task |
|---|---|---|
| 1 | CSS goes into `document.body` via `innerHTML`, with no element id, so navigations stack duplicate `<style>` tags | 2 |
| 2 | `DOMContentLoaded` is awaited unconditionally, so injection is lost if parsing already finished | 2 |
| 3 | Ad detection matches keywords in `span.textContent` with no length bound, so a post *mentioning* the word is destroyed | 4 |
| 4 | Detection ignores `data-ft` / `data-xt-vimp` / ad-link markers, which are locale-independent and cheaper than text | 4 |
| 5 | `post.innerHTML = myDiv` destroys the post subtree and breaks the virtualising scroller | 4 |
| 6 | The keyword list covers ~24 strings and misses most supported locales | 3 |
| 7 | The observer only reacts to added `SECTION` nodes, has no debounce, and assumes `removeAds` exists | 5 |
| 8 | `assets/lang/ru-RU.json` is invalid JSON, so Russian falls back to English | 6 |
| 9 | `hide_messenger_sidebar` is missing from `en-US.json`, so that settings row shows a raw key | 6 |
| 10 | A desktop user agent is used for the feed, so Facebook serves the desktop layout none of the injected selectors target | 7 |
| 11 | `#3B5998` hardcoded twice in `fabBtnCss`, ignoring the app theme | 8 |
| 12 | The stories toggle targets `#MStoriesTray`, a legacy id, so it likely hides nothing | 9 |
| 13 | No way to hide reels | 9 |

---

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `lib/utils/js.dart` | Modify | JS source builders; ad-blocker strings move out |
| `lib/utils/ad_filter.dart` | Create | Sponsored-label data + ad-detection script generation |
| `lib/utils/css.dart` | Modify | Add placeholder substitution and the collapse stylesheet |
| `lib/consts.dart` | Modify | Replace the user agents; add roles |
| `lib/controllers/fb_controller.dart` | Modify | `getUserAgent` gains a role |
| `lib/screens/home_page.dart` | Modify | Injection call sites |
| `lib/screens/messenger_page.dart` | Modify | Injection call sites |
| `lib/screens/settings_page.dart` | Modify | Add the reels toggle |
| `assets/lang/ru-RU.json` | Modify | Repair invalid JSON |
| `assets/lang/en-US.json` | Modify | Add the missing keys |
| `test/utils/js_test.dart` | Modify | Existing assertions need updating alongside the generator |
| `test/utils/ad_filter_test.dart` | Create | Label list + generated-script tests |
| `test/utils/css_test.dart` | Modify | Add placeholder tests |
| `test/controllers/fb_controller_test.dart` | Modify | Add role tests |
| `test/consts_test.dart` | Modify | Replace the user-agent assertions |
| `test/lang_test.dart` | Create | Guards every locale file against invalid JSON |

`ad_filter.dart` is split out of `js.dart` because the label data and the detection script change together and for the same reason, leaving `js.dart` as generic plumbing.

---

## Task 1: Preflight — establish the baseline

No code changes. Confirm the toolchain resolves and record the starting test count, so any later regression is unambiguous.

**Files:** none — this task only runs and observes.

- [ ] **Step 1: Confirm the pinned SDK**

```bash
fvm flutter --version
```

Expected: `Flutter 3.44.8`.

If dependency resolution fails with `in_app_purchase 3.3.0 requires SDK version ^3.10.0`, the SDK pin in `.fvmrc` has regressed below 3.10 — set it back to `3.44.8`, run `fvm install`, and retry before going further.

- [ ] **Step 2: Record the analyzer baseline**

```bash
fvm flutter analyze lib/ test/ ; echo "exit=$?"
```

Expected at the time of writing: **`47 issues found.` and `exit=1`** — every one of them `info`-level and pre-existing (18 `unawaited_futures`, 11 `unnecessary_breaks`, 3 `deprecated_member_use`, and a tail of others).

This matters more than it looks. `flutter analyze` exits non-zero on info-level lints, so the obvious gate — `fvm flutter analyze lib/ test/ && fvm flutter test` — **short-circuits before the tests ever run** on this repo. Every verification step in this plan therefore uses:

```bash
fvm flutter analyze --no-fatal-infos lib/ test/ && fvm flutter test
```

which still fails on any `error` or `warning` while tolerating the pre-existing info baseline.

Record the exact count. No task in this plan may increase it, and none may introduce an `error` or `warning`. Cleaning up the existing 47 is explicitly **not** in scope here — it would bury this plan's diffs in unrelated churn.

- [ ] **Step 3: Record the baseline test count**

```bash
fvm flutter test
```

Expected: `52 tests passed` (or more). Note the number — no later task may reduce it.

- [ ] **Step 4: Confirm the working tree is clean**

```bash
git status --short
```

Expected: no output. If `pubspec.lock` moved, commit it on its own before starting Task 2:

```bash
git add SlimSocial_for_Facebook/pubspec.lock
git commit -m "build: refresh dependency lockfile"
```

- [ ] **Step 5: Record which markup Facebook actually serves**

Tasks 4 and 9 pick DOM selectors. Which selectors are correct depends entirely on which layout Facebook returns for this app's URL and user agent, and that is not knowable from the source: the app requests `touch.facebook.com` but sends a desktop Firefox agent, and the stylesheets in `css.dart` contain selectors from *both* the legacy mobile layout (`._5rgt._5msi`, `#MStoriesTray`) and the current one (`x9f619…`). One of those sets is dead weight.

**Run this under the agent Task 7 installs, not the current one.** Task 7 moves the feed to a mobile agent, which changes the layout Facebook serves — recon done under today's desktop agent would describe markup the shipped app never sees. No code change is needed to do this: in Settings, switch on the custom user agent and paste

```
Mozilla/5.0 (Android 10; Mobile; rv:70.0) Gecko/70.0 Firefox/70.0
```

then force-restart the app. Switch it back off when you are done.

Run the app, let the feed load, attach to the WebView from Chrome via `chrome://inspect`, and run in its console:

```js
({
  url: location.href,
  ua: navigator.userAgent,
  article: document.querySelectorAll('article').length,
  roleArticle: document.querySelectorAll('[role="article"]').length,
  dataFt: document.querySelectorAll('[data-ft]').length,
  dataXtVimp: document.querySelectorAll('[data-xt-vimp]').length,
  actualHeight: document.querySelectorAll('[data-actual-height]').length,
  trackingId: document.querySelectorAll('[data-tracking-duration-id]').length,
  feedUnit: document.querySelectorAll('[data-pagelet^="FeedUnit"]').length,
  adsAboutLink: document.querySelectorAll('a[href*="/ads/about/"]').length,
})
```

### Recon result — captured 2026-08-06, answered

Run on an Android 16 emulator against a real logged-in account, reading the live WebView over the DevTools protocol. **This step is done; the numbers below are the answer.** Re-run it only if Facebook's layout visibly changes.

Both agents were measured, because the difference *is* the finding:

| Selector | Desktop UA (today's default) | **Mobile UA (Task 7)** |
|---|---:|---:|
| resolved URL | `www.facebook.com` | `www.facebook.com` |
| `article` | 0 | **0** |
| `[role="article"]` | 2 | 0 |
| `div[data-tracking-duration-id]` | 0 | **30** |
| `[data-actual-height]` | 0 | **713** |
| `[data-ft]` | 0 | **0** |
| `[data-xt-vimp]` | 0 | **0** |
| `a[href*="/ads/about/"]` | 0 | **0** |
| `#MStoriesTray` | 0 | **0** |
| `a[href*="/reel/"]` | 2 | **0** |
| `:has()` supported | yes | **yes** |
| images | 8 | 81 |
| `document.body.innerHTML.length` | 2,602,105 | **304,258** |

What it settles:

- **`_postSelector` is `div[data-tracking-duration-id]` — `article` matches nothing.** A post is `<div data-tracking-duration-id data-actual-height data-mcomponent="MContainer" data-type="container" class="m">`. Drop `article` from the selector; it is dead weight, not a fallback.
- **`data-actual-height` is real** (713 nodes), so Task 4's collapse rewrite is valid and Task 10 Step 4 keeps its assertion.
- **The `data-ft` and `data-xt-vimp` tiers cannot fire** — both zero on both agents. Keep them only as forward compatibility, and understand that in practice **the text tier is doing all the work today**. That raises the stakes on Task 3's label list and on the CJK exact-match path.
- **`#MStoriesTray` is dead**, confirming Task 9's premise: the stories toggle has been doing nothing.
- **This layout has almost no `href`s** — the only route seen was `/wui/`. Navigation is driven by `data-action-id`, so *any* selector written as `a[href*="…"]` is unreliable here. Task 9's original reels selector was written that way and had to change.
- The mobile layout is **8.5× smaller** than the desktop one it currently gets. That is Task 7's justification, measured.

Not observable in this session, and therefore still unverified:

- **No sponsored posts were in the feed**, so ad detection was not exercised against a real ad. Task 10 remains the gate for that.
- **No reels posts either**: every `[data-is-reels]` element carried the value `"false"` (they are ordinary videos). A reels *tray* was present; reel *posts* were not.

Additional finding, recorded because it changes a decision in the media plan: video posts expose **`data-video-url` pointing at a plain `https://video-*.xx.fbcdn.net/…` URL**, not a `blob:`. The companion media plan excludes video download on the grounds that MSE blob URLs cannot be fetched; on this layout that reasoning does not hold. See that plan's follow-up list.

---

The original instructions for this step, kept for when it needs re-running:

Paste the result into the task notes. It decides three things:

- **`_postSelector` in Task 4.** Use whichever of `article`, `div[data-tracking-duration-id]`, `[role="article"]` or `[data-pagelet^="FeedUnit"]` is non-zero. If the counts disagree with the plan's assumed `'article, div[data-tracking-duration-id]'`, change the plan, not the reality.
- **Whether the `data-ft` / `data-xt-vimp` tiers are worth keeping.** If both are `0`, the attribute tiers cannot fire and Task 4's cascade collapses to the text tier alone — say so and keep the tiers only as forward-compatibility.
- **Whether `data-actual-height` exists**, which is what Task 4's collapse rewrites and what Task 10 Step 4 verifies. If it is absent, the collapse still works (the write is guarded) but drop that assertion from Task 10.

Do not start Task 4 before this step has an answer.

---

## Task 2: `<style>` injection hygiene

Four problems in the current `injectCssFunc` and its call sites.

**Duplicate stylesheets.** `injectCss()` runs on every `onPageStarted`. Facebook navigates in-page constantly, so each navigation appends another `<style>` with the same rules. Nothing removes the old ones. Giving each stylesheet a stable id and bailing out when it already exists makes injection idempotent.

**`innerHTML` on a style node.** CSS is not markup. `innerHTML` runs the HTML entity parser over it, so a selector like `a[href*="&utm"]` or any `&` in a media query is silently rewritten. `textContent` assigns the string verbatim.

**`document.body` may not exist.** Injection is triggered from `onPageStarted`. `<head>` is the correct parent for a stylesheet anyway, and `document.documentElement` is a safe fallback.

**The DOM-ready race.** Both webviews wrap the injection in `document.addEventListener("DOMContentLoaded", ...)`. If the document already finished parsing when the script evaluates, that listener never fires and the styling is silently dropped. Checking `document.readyState` first fixes it.

**Files:**
- Modify: `SlimSocial_for_Facebook/lib/utils/js.dart`
- Modify: `SlimSocial_for_Facebook/test/utils/js_test.dart`
- Modify: `SlimSocial_for_Facebook/lib/utils/css.dart`
- Modify: `SlimSocial_for_Facebook/lib/screens/home_page.dart`
- Modify: `SlimSocial_for_Facebook/lib/screens/messenger_page.dart`

- [ ] **Step 1: Replace the `injectCssFunc` tests**

In `test/utils/js_test.dart`, replace the whole `group('CustomJs.injectCssFunc', ...)` block with:

```dart
  group('CustomJs.injectCssFunc', () {
    test('wraps the stylesheet in a valid JS string literal', () {
      final js = CustomJs.injectCssFunc('.a { color: red; }', id: 'slim-a');

      expect(js, contains(jsonEncode('.a { color: red; }')));
    });

    test('escapes single quotes instead of terminating the argument', () {
      // The CSS used to be interpolated into a single-quoted JS string, so an
      // apostrophe in a user stylesheet broke the whole injection.
      final js = CustomJs.injectCssFunc(
        "[aria-label='Next'] { color: red; }",
        id: 'slim-a',
      );

      expect(js, contains("[aria-label='Next']"));
      expect(js, isNot(contains(r"\'")));
    });

    test('escapes double quotes', () {
      final js = CustomJs.injectCssFunc(
        '[aria-label="Next"] { color: red; }',
        id: 'slim-a',
      );

      expect(js, contains(r'[aria-label=\"Next\"]'));
    });

    test('encodes newlines instead of breaking the string literal', () {
      // A raw newline is not legal inside a JS string literal, so the whole
      // injection would be a syntax error without this.
      final js = CustomJs.injectCssFunc('.a {\n  color: red;\n}', id: 'slim-a');

      expect(js, contains(r'\n'));
      expect(js.contains('\n  color'), isFalse);
    });

    test('skips injection when the stylesheet is already present', () {
      final js = CustomJs.injectCssFunc('.a {}', id: 'slim-dark');

      expect(js, contains('document.getElementById'));
      expect(js, contains(jsonEncode('slim-dark')));
    });

    test('writes into head with a documentElement fallback', () {
      final js = CustomJs.injectCssFunc('.a {}', id: 'slim-a');

      expect(js, contains('document.head || document.documentElement'));
      expect(js, isNot(contains('document.body.appendChild')));
    });

    test('assigns the css as text, not as markup', () {
      // innerHTML runs the HTML entity parser over the stylesheet, which
      // rewrites any `&` inside a selector or media query.
      final js = CustomJs.injectCssFunc('.a {}', id: 'slim-a');

      expect(js, contains('textContent'));
      expect(js, isNot(contains('innerHTML')));
    });
  });

  group('CustomJs.whenDomReady', () {
    test('runs immediately when parsing has already finished', () {
      final js = CustomJs.whenDomReady('doThing();');

      expect(js, contains("document.readyState === 'loading'"));
      expect(js, contains("addEventListener('DOMContentLoaded'"));
      expect(js, contains('doThing();'));
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
fvm flutter test test/utils/js_test.dart
```

Expected: compile failure — `injectCssFunc` takes no `id` parameter and `whenDomReady` does not exist.

- [ ] **Step 3: Rewrite the generators in `lib/utils/js.dart`**

Replace the `injectCssFunc` method with the following two members, keeping everything else in the class untouched for now:

```dart
  /// Builds JavaScript that appends [css] to the document in a `<style>` tag.
  ///
  /// [id] makes the operation idempotent. Injection runs on every page start,
  /// and Facebook navigates in-page constantly, so without this each navigation
  /// would append another copy of the same rules.
  ///
  /// jsonEncode gives us a valid JS string literal: it escapes quotes,
  /// backslashes and newlines, so user-provided CSS cannot break out of the
  /// call and turn the whole injection into a syntax error.
  ///
  /// The stylesheet is assigned with `textContent`, not `innerHTML`: CSS is not
  /// markup, and the HTML entity parser mangles any `&` inside a selector.
  /// It goes into `<head>` because `<body>` does not reliably exist yet when
  /// this runs.
  static String injectCssFunc(String css, {required String id}) {
    return '''
      (function (css, id) {
        if (document.getElementById(id)) return;
        var node = document.createElement('style');
        node.id = id;
        node.textContent = css;
        (document.head || document.documentElement).appendChild(node);
      }) (${jsonEncode(css)}, ${jsonEncode(id)});
    ''';
  }

  /// Wraps [body] so it runs as soon as the document is parsed.
  ///
  /// Injection is triggered from `onPageStarted`, but there is no guarantee the
  /// document is still parsing by the time the script evaluates. A bare
  /// DOMContentLoaded listener registered after the event has already fired
  /// never runs, and the styling is silently lost.
  static String whenDomReady(String body) {
    return '''
      (function () {
        function slimRun() { $body }
        if (document.readyState === 'loading') {
          document.addEventListener('DOMContentLoaded', slimRun);
        } else {
          slimRun();
        }
      })();
    ''';
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
fvm flutter test test/utils/js_test.dart
```

Expected: all tests in the file pass.

- [ ] **Step 5: Add the placeholder stylesheet**

In `lib/utils/css.dart`, add to the `CustomCss` class alongside the other definitions:

```dart
  /// Styles the stub left behind where a sponsored post was collapsed.
  ///
  /// Deliberately not in [cssList]: that list drives the user-facing settings
  /// toggles, and this is internal to ad hiding.
  static MyCss adPlaceholderCss = MyCss(
    key: 'ad_placeholder_style',
    description: 'Collapsed sponsored-post placeholder',
    defaultEnabled: true,
    code: '.slim-ad-placeholder { display: flex; align-items: center; '
        'justify-content: center; height: 60px; font-size: 13px; '
        'letter-spacing: 0.5px; opacity: 0.55; }',
  );
```

It is created here rather than in Task 4 so that the call site below compiles against code that already exists. Nothing produces `.slim-ad-placeholder` elements until Task 4, so injecting the sheet now is inert.

- [ ] **Step 6: Update the Facebook call site**

In `lib/screens/home_page.dart`, replace `injectCss` with:

```dart
  Future<void> injectCss() async {
    final sheets = <String, String>{
      'slim-messenger-download': CustomCss.removeMessengerDownloadCss.code,
      'slim-browser-notice': CustomCss.removeBrowserNotSupportedCss.code,
      'slim-ad-placeholder': CustomCss.adPlaceholderCss.code,
      'slim-user-sheet':
          CustomCss.buildFacebookCss(PrefController.getUserCustomCss()),
    };

    final hideAds = sp.getBool(SpKeys.hideAds) ?? true;

    // Defines removeAds(). Task 4 replaces both this and the call below with
    // adFilterScript; until then ad hiding has to keep working.
    if (hideAds) {
      await _controller.runJavaScript(CustomJs.removeAdsFunc);
    }

    final body = [
      ...sheets.entries.map((e) => CustomJs.injectCssFunc(e.value, id: e.key)),
      if (hideAds) 'removeAds();',
    ].join('\n');

    await _controller.runJavaScript(CustomJs.whenDomReady(body));
  }
```

Two things this deliberately does *not* change. The ad injection stays put, so this commit is a pure injection-hygiene change and ad hiding is never broken in between — Task 4 moves it into `runJs` and deletes `removeAdsFunc` in the same commit that adds the replacement. And the body is handed to `runJavaScript` with its newlines intact: `jsonEncode` already escaped every newline *inside* the CSS string literals, so the remaining ones are only between statements. Flattening them is not just unnecessary, it is a hazard — a single `//` comment anywhere in the snippet would comment out the entire rest of the program once the line breaks are gone.

- [ ] **Step 7: Update the Messenger call site**

In `lib/screens/messenger_page.dart`, replace `injectCss` with:

```dart
  Future<void> injectCss() async {
    final sheets = <String, String>{
      'slim-messenger-adapt': CustomCss.adaptMessengerPageCss.code,
      'slim-user-sheet':
          CustomCss.buildMessengerCss(PrefController.getUserCustomCss()),
    };

    final body = sheets.entries
        .map((e) => CustomJs.injectCssFunc(e.value, id: e.key))
        .join('\n');

    await _controller.runJavaScript(CustomJs.whenDomReady(body));
  }
```

- [ ] **Step 8: Verify nothing regressed**

```bash
fvm flutter analyze --no-fatal-infos lib/ test/ && fvm flutter test
```

Expected: analyze exits 0 (see the baseline note in Task 1 Step 2 — info-level lints are pre-existing and non-fatal here; **no new** `error` or `warning` lines), then all tests pass. Every task in this plan commits a green tree; if either command fails, fix it before committing.

- [ ] **Step 9: Commit**

```bash
git add SlimSocial_for_Facebook/lib/utils/js.dart SlimSocial_for_Facebook/lib/utils/css.dart SlimSocial_for_Facebook/lib/screens/home_page.dart SlimSocial_for_Facebook/lib/screens/messenger_page.dart SlimSocial_for_Facebook/test/utils/js_test.dart
git commit -m "fix: inject each stylesheet once, into head, as text"
```

---

## Task 3: Sponsored labels for every supported locale

The keyword list covers roughly 24 strings, several of them machine translations that do not match what Facebook actually renders, and it appends only `"sponsored_keyword_fb".tr()` — the label for the **app's** locale.

That last part is the real gap. Facebook renders the label in the language of the **Facebook account**, which is frequently not the language the app is running in, and a feed can mix several. All 43 locale files already carry a `sponsored_keyword_fb` value, so bundling every one of them costs nothing and covers the mismatch.

The list is self-contained and lands first, so that Task 4's detection script has something to compile against.

**Files:**
- Create: `SlimSocial_for_Facebook/lib/utils/ad_filter.dart`
- Create: `SlimSocial_for_Facebook/test/utils/ad_filter_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/utils/ad_filter_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:slimsocial_for_facebook/utils/ad_filter.dart';

void main() {
  group('kSponsoredLabels', () {
    test('is not empty', () {
      expect(kSponsoredLabels, isNotEmpty);
    });

    test('is entirely lowercase so matching can be case-insensitive', () {
      for (final label in kSponsoredLabels) {
        expect(label, label.toLowerCase(), reason: '"$label" is not lowercase');
      }
    });

    test('has no duplicates', () {
      expect(kSponsoredLabels.toSet().length, kSponsoredLabels.length);
    });

    test('has no stray surrounding whitespace', () {
      for (final label in kSponsoredLabels) {
        expect(label, label.trim(), reason: '"$label" has stray whitespace');
      }
    });

    test('short labels exist and are the CJK ones', () {
      // CJK ad labels are genuinely two characters ("広告", "광고"), so they
      // cannot clear the substring floor. They are not dropped — Task 4 matches
      // anything below the floor as a whole string instead, which is safer than
      // a two-character substring test anyway. This asserts the split is real,
      // because an empty short list would silently mean no CJK detection.
      final short =
          kSponsoredLabels.where((l) => l.length < kMinSponsoredLabelLength);

      expect(short, isNotEmpty);
      expect(short, contains('広告'));
      expect(short, contains('광고'));
    });

    test('no label is a single character', () {
      // One character would match far too much even as an exact string.
      for (final label in kSponsoredLabels) {
        expect(label.length, greaterThanOrEqualTo(2), reason: '"$label"');
      }
    });

    test('covers the scripts used across the supported locales', () {
      expect(kSponsoredLabels, contains('sponsored'));
      expect(kSponsoredLabels, contains('sponsorizzato'));
      expect(kSponsoredLabels, contains('gesponsert'));
      expect(kSponsoredLabels, contains('patrocinado'));
      expect(kSponsoredLabels, contains('реклама'));
      expect(kSponsoredLabels, contains('広告'));
      expect(kSponsoredLabels, contains('광고'));
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
fvm flutter test test/utils/ad_filter_test.dart
```

Expected: `Error: Couldn't resolve the package 'slimsocial_for_facebook/utils/ad_filter.dart'`.

- [ ] **Step 3: Create `lib/utils/ad_filter.dart`**

```dart
/// Shortest label that may be matched as a *substring*.
///
/// A short substring appears all over Facebook's own chrome, so testing for one
/// inside a longer string produces false positives. Labels below this length are
/// not discarded: Task 4 compares them against the candidate's whole trimmed
/// text instead, which cannot fire mid-sentence. CJK labels ("広告", "광고") are
/// genuinely two characters, so without that second path there would be no ad
/// detection at all in Chinese, Japanese or Korean.
const int kMinSponsoredLabelLength = 4;

/// Labels Facebook uses to mark a sponsored post, lowercase, one or more per
/// supported locale.
///
/// The label is rendered in the language of the *Facebook account*, which is
/// often not the language the app is running in, and a single feed can mix
/// several — so every known variant is bundled rather than just the active
/// locale's.
///
/// Values come from the `sponsored_keyword_fb` entries in `assets/lang/*.json`
/// plus the variants below. Matching is a case-insensitive substring test
/// guarded by a length window, so a variant that is wrong for some locale is
/// inert rather than harmful. Still, prefer deleting a doubtful label over
/// guessing at one: every entry widens the false-positive surface.
const List<String> kSponsoredLabels = [
  // Latin script
  'gesponsert',
  'gesponsord',
  'hirdetés',
  'patrocinado',
  'publicidad',
  'rėmėjas',
  'sponsede',
  'sponset',
  'sponsora',
  'sponsored',
  'sponsoreeritud',
  'sponsoreret',
  'sponsorisé',
  'sponsorisée',
  'sponsorizat',
  'sponsorizzato',
  'sponsorlu',
  'sponsoroidut',
  'sponsoroitu',
  'sponsorowane',
  'sponsrad',
  'sponsrat',
  'sponzorirano',
  'sponzorisano',
  'sponzorované',
  'sponzorováno',
  'szponzorált',
  'tài trợ',
  // Cyrillic
  'реклама',
  'спонсорирано',
  'спонсоровано',
  // Hebrew, Arabic, Persian, Urdu
  'ממומן',
  'تعاون',
  'حمایت شده',
  'رعاية',
  'ممول',
  // Indic
  'प्रायोजित',
  'স্পনসরড',
  'பரிந்துரைக்கப்பட்டது',
  'ప్రాయోజించబడిన',
  'പ്രവര്‍ത്തിച്ചിരിക്കുന്നത്',
  // Thai
  'โฆษณา',
  // CJK
  '広告',
  'スポンサー',
  '赞助',
  '贊助',
  '광고',
  '스폰서',
];
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
fvm flutter test test/utils/ad_filter_test.dart
```

Expected: all tests pass.

If `short labels exist and are the CJK ones` fails, the CJK entries were dropped from the list — put them back. They are matched as whole strings by Task 4, not as substrings, so the substring floor does not apply to them.

- [ ] **Step 5: Verify the whole project**

```bash
fvm flutter analyze --no-fatal-infos lib/ test/ && fvm flutter test
```

Expected: analyze exits 0 (see the baseline note in Task 1 Step 2 — info-level lints are pre-existing and non-fatal here; **no new** `error` or `warning` lines), then all tests pass. Nothing imports `ad_filter.dart` yet, so this task adds a self-contained, green unit.

- [ ] **Step 6: Commit**

```bash
git add SlimSocial_for_Facebook/lib/utils/ad_filter.dart SlimSocial_for_Facebook/test/utils/ad_filter_test.dart
git commit -m "feat: bundle sponsored-post labels for every supported locale"
```

---

## Task 4: Layered ad detection

Three defects remain in `removeAdsFunc`.

**No length bound on text matching.** `querySelectorAll('span')` returns thousands of nodes on a loaded feed, and `textContent` on an ancestor includes all descendant text. Any post whose *body* contains the word "Sponsored" — a status complaining about ads, a screenshot caption — is destroyed. A genuine label is a short standalone string, so bounding the match to 4–24 characters removes almost all of these false positives.

**Markup is ignored.** Facebook has historically tagged sponsored units with attributes: `data-ft` containing `is_sponsored` or `should_log_endpoint_info`, `data-xt-vimp`, and links to `/ads/about/`. These are locale-independent and vastly cheaper to test than walking every descendant's text, so they are checked first.

**Be clear-eyed about this tier, though.** The Task 1 recon found **zero** `data-ft`, `data-xt-vimp` and `/ads/about/` nodes on the layout the app actually receives, under either user agent. So today the attribute tiers never fire and **the text tier does all of the work**. They are retained as forward compatibility — they cost one `querySelector` per post and would start working the moment Facebook reinstates the markup — but do not mistake them for the primary mechanism. The practical consequence is that Task 3's label list, and especially the CJK exact-match path, carry the whole feature.

**The post subtree is destroyed.** `post.innerHTML = myDiv` throws away the post's children. Facebook's own scripts still hold references into that subtree, and the mobile feed virtualises on `data-actual-height`, so overwriting content leaves the scroller with wrong geometry. Hiding the children and appending a stub keeps both intact and makes the operation reversible.

**Files:**
- Modify: `SlimSocial_for_Facebook/lib/utils/ad_filter.dart`
- Modify: `SlimSocial_for_Facebook/test/utils/ad_filter_test.dart`
- Modify: `SlimSocial_for_Facebook/lib/utils/js.dart`
- Modify: `SlimSocial_for_Facebook/lib/screens/home_page.dart`

- [ ] **Step 1: Write the failing tests**

Add to `test/utils/ad_filter_test.dart`, inside `main()` and below the `kSponsoredLabels` group that Task 3 created:

```dart
  final script = adFilterScript(
    placeholderText: 'Ad removed',
    extraLabels: const ['werbung'],
  );

  group('adFilterScript detection tiers', () {
    test('checks the post attribute before anything else', () {
      expect(script, contains('is_sponsored'));
      expect(script, contains('should_log_endpoint_info'));
    });

    test('checks the descendant markers Facebook puts on ad units', () {
      expect(script, contains('data-xt-vimp'));
      expect(script, contains('/ads/about/'));
    });

    test('bounds substring matching so prose mentioning the word is spared', () {
      expect(script, contains('lower.length < MIN_LEN'));
      expect(script, contains('lower.length >= MAX_LEN'));
    });

    test('matches short labels against the whole string, not a substring', () {
      // A two-character CJK label tested as a substring would fire inside
      // ordinary prose; compared whole it cannot.
      expect(script, contains('EXACT_LABELS'));
      expect(script, contains('lower === EXACT_LABELS[e]'));
    });

    test('bundles the CJK labels into the exact-match list', () {
      // Guards the split itself: if these ended up in the substring list they
      // would be unreachable, and CJK ad detection would silently be dead.
      final exact = script.substring(
        script.indexOf('var EXACT_LABELS ='),
        script.indexOf('var MIN_LEN ='),
      );

      expect(exact, contains('広告'));
      expect(exact, contains('광고'));
    });

    test('embeds the bundled labels and the runtime extras', () {
      expect(script, contains('sponsored'));
      expect(script, contains('werbung'));
    });
  });

  group('adFilterScript collapsing', () {
    test('marks handled posts so they are never processed twice', () {
      expect(script, contains('slim-ad-handled'));
    });

    test('preserves the original virtual-scroller height', () {
      expect(script, contains('data-actual-height'));
      expect(script, contains('data-slim-height-original'));
    });

    test('never overwrites the post subtree', () {
      expect(script, isNot(contains('innerHTML')));
    });

    test('exposes the entry point the observer calls', () {
      expect(script, contains('window.slimRemoveAds'));
    });

    test('shows the placeholder text it was given', () {
      expect(script, contains('Ad removed'));
    });
  });

  group('adFilterScript label handling', () {
    test('drops a runtime extra that duplicates a bundled label', () {
      final withDuplicate = adFilterScript(
        placeholderText: 'x',
        extraLabels: const ['Sponsored'],
      );
      final bundled = adFilterScript(placeholderText: 'x');

      // The encoded array must be identical: no duplicate entry was added.
      expect(withDuplicate, bundled);
    });

    test('routes a short runtime extra into the exact-match list', () {
      // This is the CJK app-locale case. Dropping it for being short would
      // remove ad detection in exactly the locales that need it, so it must
      // survive — as an exact match rather than a substring.
      final script = adFilterScript(
        placeholderText: 'x',
        extraLabels: const ['广告'],
      );
      final exact = script.substring(
        script.indexOf('var EXACT_LABELS ='),
        script.indexOf('var MIN_LEN ='),
      );
      final substrings = script.substring(
        script.indexOf('var LABELS ='),
        script.indexOf('var EXACT_LABELS ='),
      );

      expect(exact, contains('广告'));
      expect(substrings, isNot(contains('广告')));
    });

    test('still ignores a runtime extra of a single character', () {
      final withOneChar = adFilterScript(
        placeholderText: 'x',
        extraLabels: const ['a'],
      );
      final bundled = adFilterScript(placeholderText: 'x');

      expect(withOneChar, bundled);
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
fvm flutter test test/utils/ad_filter_test.dart
```

Expected: compile failure — `Method not found: 'adFilterScript'`.

- [ ] **Step 3: Add the script generator to `lib/utils/ad_filter.dart`**

Add the import and the three declarations below to the file Task 3 created, keeping `kSponsoredLabels` and `kMinSponsoredLabelLength` as they are:

```dart
import 'dart:convert';

/// Markers Facebook puts on the descendants of a sponsored unit.
///
/// Checked before any text matching: they do not depend on the viewer's
/// language and a single `querySelector` is far cheaper than walking every
/// descendant's text content.
const String _sponsoredMarkerSelector =
    '[data-ft*="is_sponsored"], [data-xt-vimp], a[href*="/ads/about/"], '
    'a[href*="client_token="], a[href*="sponsored"]';

/// Containers that hold a single feed post.
///
/// Measured against the live mobile layout (Task 1 Step 5): 30 matches, while
/// `article` and `[role="article"]` matched nothing at all. `article` was in an
/// earlier draft of this selector and is deliberately gone — it was dead weight
/// rather than a fallback.
const String _postSelector = 'div[data-tracking-duration-id]';

/// Builds the ad-hiding script and installs it as `window.slimRemoveAds`.
///
/// Detection runs cheapest-first and stops at the first hit:
///   1. the post's own `data-ft` attribute
///   2. a descendant carrying one of the sponsored markers
///   3. a short standalone text label, bounded to 4..24 characters
///
/// A matched post is collapsed, not emptied: its children are hidden in place
/// and `data-actual-height` is rewritten so the virtualising scroller keeps
/// working, with the original value stashed so the change can be undone.
String adFilterScript({
  required String placeholderText,
  List<String> extraLabels = const [],
}) {
  // A runtime extra is the app locale's own label. It must not be dropped for
  // being short: in a CJK locale it is exactly the two-character case, which is
  // precisely when it matters most. Short entries go to the exact-match list.
  final all = <String>{
    ...kSponsoredLabels,
    for (final label in extraLabels)
      if (label.trim().length >= 2) label.trim().toLowerCase(),
  };

  final substringLabels =
      all.where((l) => l.length >= kMinSponsoredLabelLength).toList();
  final exactLabels =
      all.where((l) => l.length < kMinSponsoredLabelLength).toList();

  return '''
(function () {
  var LABELS = ${jsonEncode(substringLabels)};
  var EXACT_LABELS = ${jsonEncode(exactLabels)};
  var MIN_LEN = $kMinSponsoredLabelLength;
  var MAX_LEN = 25;
  var PLACEHOLDER = ${jsonEncode(placeholderText)};
  var memo = null;

  function isSponsoredLabel(text) {
    if (!text) return false;
    var lower = text.toLowerCase();

    // CJK labels are two characters, so they are compared against the whole
    // trimmed string. An exact match cannot fire inside prose, which is what
    // makes a two-character label safe to test at all.
    for (var e = 0; e < EXACT_LABELS.length; e++) {
      if (lower === EXACT_LABELS[e]) return true;
    }

    // Everything else is a substring test, bounded so that an ordinary post
    // merely mentioning the word is not hidden along with the real ads.
    if (lower.length < MIN_LEN || lower.length >= MAX_LEN) return false;

    // Once one language has matched, every later post in the same feed is
    // almost certainly the same language, so try that one first.
    if (memo && lower.indexOf(memo) !== -1) return true;
    for (var i = 0; i < LABELS.length; i++) {
      if (lower.indexOf(LABELS[i]) !== -1) {
        memo = LABELS[i];
        return true;
      }
    }
    return false;
  }

  function isSponsoredPost(post) {
    var dataFt = post.getAttribute('data-ft') || '';
    if (dataFt.indexOf('is_sponsored') !== -1) return true;
    if (dataFt.indexOf('should_log_endpoint_info') !== -1) return true;

    if (post.querySelector(${jsonEncode(_sponsoredMarkerSelector)})) return true;

    var candidates = post.querySelectorAll('span, div, a');
    for (var i = 0; i < candidates.length; i++) {
      var text = (candidates[i].textContent || '').trim();
      // Skip empty nodes and anything long enough to be post body rather than a
      // label. The lower bound lives in isSponsoredLabel, which applies it only
      // to substring matching: a two-character CJK label has to reach it.
      if (text.length === 0 || text.length >= MAX_LEN) continue;
      if (isSponsoredLabel(text)) return true;
    }
    return false;
  }

  function collapse(post) {
    post.classList.add('slim-ad-handled');

    var height = post.getAttribute('data-actual-height');
    if (height !== null) {
      post.setAttribute('data-slim-height-original', height);
      post.setAttribute('data-actual-height', '60');
    }

    // Hide the real content without detaching it: Facebook's own scripts still
    // hold references into this subtree.
    var child = post.firstElementChild;
    while (child) {
      child.style.display = 'none';
      child = child.nextElementSibling;
    }

    var stub = document.createElement('div');
    stub.className = 'slim-ad-placeholder';
    stub.textContent = PLACEHOLDER;
    post.appendChild(stub);
  }

  window.slimRemoveAds = function () {
    var handled = 0;
    var posts = document.querySelectorAll(${jsonEncode(_postSelector)});
    for (var i = 0; i < posts.length; i++) {
      var post = posts[i];
      if (post.classList.contains('slim-ad-handled')) continue;
      if (!isSponsoredPost(post)) continue;
      collapse(post);
      handled++;
    }
    return handled;
  };

  window.slimRemoveAds();
})();
''';
}
```

`kSponsoredLabels` and `kMinSponsoredLabelLength` come from Task 3, so both already exist in this file.

- [ ] **Step 4: Run the tests to verify they pass**

```bash
fvm flutter test test/utils/ad_filter_test.dart
```

Expected: all tests in the file pass.

- [ ] **Step 5: Switch the call sites over**

Ad handling moves out of `injectCss` and into `runJs`, so that it is set up in one place after the page has loaded rather than split across two lifecycle callbacks. Both halves of that move happen in this one commit: dropping `removeAdsFunc` before `adFilterScript` exists would leave a build with no ad hiding at all.

In `lib/screens/home_page.dart`, drop the ad lines added in Task 2 from `injectCss`, leaving it as pure stylesheet injection:

```dart
  Future<void> injectCss() async {
    final sheets = <String, String>{
      'slim-messenger-download': CustomCss.removeMessengerDownloadCss.code,
      'slim-browser-notice': CustomCss.removeBrowserNotSupportedCss.code,
      'slim-ad-placeholder': CustomCss.adPlaceholderCss.code,
      'slim-user-sheet':
          CustomCss.buildFacebookCss(PrefController.getUserCustomCss()),
    };

    final body = sheets.entries
        .map((e) => CustomJs.injectCssFunc(e.value, id: e.key))
        .join('\n');

    await _controller.runJavaScript(CustomJs.whenDomReady(body));
  }
```

Then replace `runJs` with:

```dart
  Future<void> runJs() async {
    if (sp.getBool(SpKeys.hideAds) ?? true) {
      // Define and run the filter first: the observer below calls into it.
      await _controller.runJavaScript(
        adFilterScript(
          placeholderText: 'ad_removed'.tr(),
          extraLabels: [ 'sponsored_keyword_fb'.tr() ],
        ),
      );
      await _controller.runJavaScript(CustomJs.removeAdsObserver);
    }

    final userCustomJs = PrefController.getUserCustomJs();
    if (userCustomJs != null) {
      await _controller.runJavaScript(userCustomJs);
    }
  }
```

`getUserCustomJs()` already returns `null` when the setting is off or blank, so the old `isNotEmpty` check was redundant.

Add the import, keeping the block alphabetically ordered — `very_good_analysis` enforces `directives_ordering`:

```dart
import 'package:slimsocial_for_facebook/utils/ad_filter.dart';
```

- [ ] **Step 6: Delete the superseded strings**

Remove `CustomJs.removeAdsFunc` and `CustomJs.exampleJs` from `lib/utils/js.dart`. `removeAdsFunc` is replaced by `adFilterScript`; `exampleJs` is dead code that blanks the page body and is referenced nowhere.

Confirm nothing still refers to them:

```bash
grep -rn "removeAdsFunc\|exampleJs" lib/ test/
```

Expected: no output. If `home_page.dart` still appears, Step 5's `injectCss` edit was missed.

- [ ] **Step 7: Verify the whole project**

```bash
fvm flutter analyze --no-fatal-infos lib/ test/ && fvm flutter test
```

Expected: analyze exits 0 (see the baseline note in Task 1 Step 2 — info-level lints are pre-existing and non-fatal here; **no new** `error` or `warning` lines), then all tests pass.

- [ ] **Step 8: Commit**

```bash
git add SlimSocial_for_Facebook/lib/utils/ad_filter.dart SlimSocial_for_Facebook/lib/utils/js.dart SlimSocial_for_Facebook/lib/screens/home_page.dart SlimSocial_for_Facebook/test/utils/ad_filter_test.dart
git commit -m "feat: detect sponsored posts by markup and collapse them in place"
```

---

## Task 5: Make the feed observer robust

The observer installs correctly now, but three things limit it.

**It only reacts to added `SECTION` elements.** Facebook appends feed posts inside `div` wrappers on most surfaces, so on those the callback fires and matches nothing.

**No debounce.** The feed can append dozens of nodes in one frame, and the callback calls `removeAds()` once per matching mutation. Each of those calls walks the whole document.

**It assumes `removeAds` exists.** The function was defined by a separate `runJavaScript` at a different point in the page lifecycle. If that injection did not land, every mutation throws a `ReferenceError`.

**Files:**
- Modify: `SlimSocial_for_Facebook/lib/utils/js.dart`
- Modify: `SlimSocial_for_Facebook/test/utils/js_test.dart`

- [ ] **Step 1: Replace the observer tests**

In `test/utils/js_test.dart`, replace the whole `group('CustomJs.removeAdsObserver', ...)` block with:

```dart
  group('CustomJs.removeAdsObserver', () {
    test('installs the observer when none is running yet', () {
      // The guard used to be `typeof newPostsObserver !== 'undefined'` against
      // a name that only existed inside the branch, so it was always false and
      // the observer was never created: ads reappeared as soon as you scrolled.
      expect(
        CustomJs.removeAdsObserver,
        contains('if (window.slimAdObserver) return;'),
      );
    });

    test('stores the observer globally so it is not re-created', () {
      expect(
        CustomJs.removeAdsObserver,
        contains('window.slimAdObserver = new MutationObserver'),
      );
    });

    test('observes the document subtree for added nodes', () {
      expect(CustomJs.removeAdsObserver, contains('.observe('));
      expect(CustomJs.removeAdsObserver, contains('childList: true'));
      expect(CustomJs.removeAdsObserver, contains('subtree: true'));
    });

    test('never declares a block-scoped observer again', () {
      expect(CustomJs.removeAdsObserver, isNot(contains('const newPosts')));
      expect(CustomJs.removeAdsObserver, isNot(contains('let newPosts')));
    });

    test('does not filter mutations down to SECTION elements', () {
      // Posts arrive inside plain divs on most surfaces, so a SECTION-only
      // filter matched nothing there.
      expect(CustomJs.removeAdsObserver, isNot(contains("'SECTION'")));
    });

    test('coalesces bursts of mutations into a single pass', () {
      expect(CustomJs.removeAdsObserver, contains('setTimeout'));
    });

    test('bails out when the filter was never installed', () {
      expect(
        CustomJs.removeAdsObserver,
        contains("typeof window.slimRemoveAds !== 'function'"),
      );
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
fvm flutter test test/utils/js_test.dart
```

Expected: the new assertions FAIL — the current string still contains `'SECTION'` and `window.newPostsObserver`.

- [ ] **Step 3: Rewrite `removeAdsObserver`**

In `lib/utils/js.dart`, replace the `removeAdsObserver` string with:

```dart
  /// Re-runs the ad filter as Facebook appends posts during infinite scroll.
  ///
  /// Kept on `window` so it survives being re-injected on every page load:
  /// without a global we cannot tell whether one is already running. (The guard
  /// used to read `typeof newPostsObserver !== 'undefined'` against a
  /// block-scoped `const` declared inside the branch, so it was always false
  /// and the observer was never installed — ads came back as soon as you
  /// scrolled.)
  static String removeAdsObserver = """
(function () {
  if (window.slimAdObserver) return;
  // The filter defines this. If its injection did not land, every mutation
  // would otherwise throw a ReferenceError.
  if (typeof window.slimRemoveAds !== 'function') return;

  var pending = null;
  function schedule() {
    if (pending) return;
    // The feed can append dozens of nodes in one frame, and each pass walks
    // the whole document, so coalesce a burst into a single run.
    pending = setTimeout(function () {
      pending = null;
      window.slimRemoveAds();
    }, 250);
  }

  window.slimAdObserver = new MutationObserver(function (mutations) {
    for (var i = 0; i < mutations.length; i++) {
      // Any added node is worth a pass: posts arrive inside plain divs on most
      // surfaces, so filtering on a specific tag name missed them.
      if (mutations[i].addedNodes.length > 0) {
        schedule();
        return;
      }
    }
  });

  window.slimAdObserver.observe(document.body, {
    childList: true,
    subtree: true
  });
})();
""";
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
fvm flutter test test/utils/js_test.dart
```

Expected: all tests in the file pass.

- [ ] **Step 5: Verify the whole project**

```bash
fvm flutter analyze --no-fatal-infos lib/ test/ && fvm flutter test
```

Expected: `No issues found!` then all tests pass, with a total above the 52 baseline.

- [ ] **Step 6: Commit**

```bash
git add SlimSocial_for_Facebook/lib/utils/js.dart SlimSocial_for_Facebook/test/utils/js_test.dart
git commit -m "fix: observe all added feed nodes and debounce the ad filter"
```

---

## Task 6: Repair the localisation files

`assets/lang/ru-RU.json` is not valid JSON — line 52 is missing its trailing comma — so `jsonDecode` throws and Russian users get English. `_.json` was repaired already; `ru-RU.json` was missed.

`hide_messenger_sidebar` is used by the settings screen but missing from `en-US.json`, which is the `fallbackLocale`, so that row renders the raw key in every language.

**Files:**
- Create: `SlimSocial_for_Facebook/test/lang_test.dart`
- Modify: `SlimSocial_for_Facebook/assets/lang/ru-RU.json:52`
- Modify: `SlimSocial_for_Facebook/assets/lang/en-US.json`

- [ ] **Step 1: Write the failing test**

Create `test/lang_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final files = Directory('assets/lang')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('there are localisation files to check', () {
    expect(files, isNotEmpty);
  });

  for (final file in files) {
    test('${file.uri.pathSegments.last} is valid JSON', () {
      expect(
        () => jsonDecode(file.readAsStringSync()),
        returnsNormally,
        reason: '${file.path} does not parse, so that locale silently falls '
            'back to English',
      );
    });
  }

  test('the fallback locale defines every key the UI asks for', () {
    final fallback = jsonDecode(
      File('assets/lang/en-US.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    for (final key in const [
      'ad_removed',
      'dark_theme',
      'hide_ads',
      'hide_messenger_sidebar',
      'hide_stories',
      'sponsored_keyword_fb',
    ]) {
      expect(fallback.keys, contains(key), reason: '$key missing from en-US');
    }
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
fvm flutter test test/lang_test.dart
```

Expected: `ru-RU.json is valid JSON` FAILS, and `the fallback locale defines every key the UI asks for` FAILS on `hide_messenger_sidebar`.

- [ ] **Step 3: Fix `ru-RU.json`**

Line 52 is missing a comma. Change:

```json
  "enabled": "Включен"
  "proxy_is_active": "Прокси активен",
```

to:

```json
  "enabled": "Включен",
  "proxy_is_active": "Прокси активен",
```

- [ ] **Step 4: Add the missing key to `en-US.json`**

Add the entry, putting a comma on the line that was previously last:

```json
  "hide_messenger_sidebar": "Hide Messenger sidebar"
```

- [ ] **Step 5: Run the test to verify it passes**

```bash
fvm flutter test test/lang_test.dart
```

Expected: all tests pass — one per locale file plus the two others.

- [ ] **Step 6: Commit**

```bash
git add SlimSocial_for_Facebook/assets/lang/ru-RU.json SlimSocial_for_Facebook/assets/lang/en-US.json SlimSocial_for_Facebook/test/lang_test.dart
git commit -m "fix: repair ru-RU localisation file and add missing key"
```

---

## Task 7: A user agent per surface

One **desktop** Firefox agent is used for everything, and that is the bug. Facebook decides which layout to serve from the user agent, and a desktop agent gets the desktop layout — heavier, harder to restyle, and in several countries served in a variant that renders badly on a phone. Every selector in this plan is written against the touch layout.

Two changes fix it: a mobile Android Firefox agent for the feed, and a desktop agent for Messenger, which only ships its full markup to one.

**These two strings are known-good in production.** Do not "modernise" them while applying this task — the version numbers are load-bearing, see Step 3.

**Files:**
- Modify: `SlimSocial_for_Facebook/lib/consts.dart`
- Modify: `SlimSocial_for_Facebook/test/consts_test.dart`
- Modify: `SlimSocial_for_Facebook/lib/controllers/fb_controller.dart`
- Modify: `SlimSocial_for_Facebook/test/controllers/fb_controller_test.dart`
- Modify: `SlimSocial_for_Facebook/lib/screens/messenger_page.dart`

- [ ] **Step 1: Replace the user-agent tests in `consts_test.dart`**

Replace the whole `group('kFirefoxUserAgent', ...)` block with:

```dart
  group('kMobileUserAgent', () {
    test('asks Facebook for the mobile layout', () {
      // This is the whole point of the constant: every selector this app
      // injects is written against the touch layout, and Facebook picks the
      // layout from the user agent.
      expect(kMobileUserAgent, contains('Android'));
      expect(kMobileUserAgent, contains('Mobile'));
      expect(kMobileUserAgent, contains('Firefox/'));
    });

    test('is pinned to the exact string known to serve the touch layout', () {
      // Do not "modernise" this. The version numbers are load-bearing: this
      // precise agent is what Facebook serves the mobile feed to across the
      // regions where a desktop agent gets a broken layout. A newer Firefox
      // is not automatically safer — it is untested against that behaviour.
      // If Facebook ever rejects it as outdated (Task 10 Step 1 checks), bump
      // `Gecko/` and `Firefox/` together and re-run the recon, in one commit.
      expect(
        kMobileUserAgent,
        'Mozilla/5.0 (Android 10; Mobile; rv:70.0) Gecko/70.0 Firefox/70.0',
      );
    });
  });

  group('kDesktopUserAgent', () {
    test('is a desktop agent, which is what Messenger needs', () {
      expect(kDesktopUserAgent, contains('Macintosh'));
      expect(kDesktopUserAgent, isNot(contains('Mobile')));
    });
  });
```

- [ ] **Step 2: Write the failing controller tests**

Add to `test/controllers/fb_controller_test.dart`, inside `main()`:

```dart
  group('getUserAgent roles', () {
    test('defaults to the feed agent', () {
      expect(
        PrefController.getUserAgent(),
        PrefController.getUserAgent(role: UserAgentRole.feed),
      );
    });

    test('gives the feed the mobile agent', () {
      expect(
        PrefController.getUserAgent(role: UserAgentRole.feed),
        kMobileUserAgent,
      );
    });

    test('gives Messenger the desktop agent', () {
      expect(
        PrefController.getUserAgent(role: UserAgentRole.messenger),
        kDesktopUserAgent,
      );
    });

    test('basic mode overrides every role', () async {
      // This file seeds preferences with withPrefs (which calls
      // SharedPreferences.setMockInitialValues and is reset by setUp), never
      // bare sp.setBool — mixing the two leaks state between tests.
      await withPrefs({SpKeys.useMbasic: true});

      for (final role in UserAgentRole.values) {
        expect(
          PrefController.getUserAgent(role: role),
          kOperaMiniUserAgent,
          reason: 'role $role should honour basic mode',
        );
      }
    });

    test('a custom agent overrides every role', () async {
      await withPrefs({
        SpKeys.customUserAgent: 'my-agent',
        SpKeys.enabled(SpKeys.customUserAgent): true,
      });

      for (final role in UserAgentRole.values) {
        expect(PrefController.getUserAgent(role: role), 'my-agent');
      }
    });

    test('every role resolves to a non-empty agent', () {
      for (final role in UserAgentRole.values) {
        expect(PrefController.getUserAgent(role: role), isNotEmpty);
      }
    });
  });
```

Then update the four existing references to `kFirefoxUserAgent` in this file to `kMobileUserAgent` — the constant is being replaced, not added alongside.

- [ ] **Step 3: Run the tests to verify they fail**

```bash
fvm flutter test test/consts_test.dart test/controllers/fb_controller_test.dart
```

Expected: compile failure — `Undefined name 'kMobileUserAgent'`, `kDesktopUserAgent`, `UserAgentRole`.

- [ ] **Step 4: Replace the constants**

In `lib/consts.dart`, replace the whole user-agent block — `kFirefoxUserAgent` and `kIpadUserAgent` both go. `kIpadUserAgent` is referenced nowhere and its value is not even an iPad agent; the video-quality agent that would justify it arrives with the follow-up that uses it. Keep `kOperaMiniUserAgent`: basic mode still uses it.

```dart
//user agent for the webview
//
//Facebook picks which layout to serve from the user agent, so these strings
//decide what every injected selector in this app has to match. A desktop agent
//gets the desktop layout, which is heavier, harder to restyle, and in some
//regions served in a variant that renders badly on a phone.
//
//Facebook serves a "browser not supported" notice and a degraded page to
//agents it considers outdated, so if it ever rejects one of these, bump its
//version numbers together with a device check on the feed — see the plan notes.

/// Firefox for Android. Gets Facebook's touch layout.
///
/// This exact string is a known-good production value: it is what serves the
/// mobile feed correctly in the regions where a desktop agent gets a broken
/// layout. The age of the version is not the point — the layout Facebook
/// returns for it is — so do not "modernise" it without re-checking the feed.
const String kMobileUserAgent =
    "Mozilla/5.0 (Android 10; Mobile; rv:70.0) Gecko/70.0 Firefox/70.0";

/// Desktop Chrome on macOS. Messenger only ships its full markup to a desktop
/// agent; on a mobile one it pushes the native-app interstitial instead.
const String kDesktopUserAgent =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_6) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/68.0.3440.84 Safari/537.36";

/// Opera Mini. Used only by basic mode, which targets `mbasic.facebook.com`.
const String kOperaMiniUserAgent =
    "Opera/9.80 (Android; Opera Mini/69.0.2254/191.303; U; en) Presto/2.12.423 Version/12.16";

/// Which surface a user agent is being requested for.
///
/// Facebook varies the markup it serves by user agent, so one string for the
/// whole app means one of the two surfaces always gets the wrong layout.
enum UserAgentRole {
  /// The main feed and everything reached from it.
  feed,

  /// The Messenger webview.
  messenger,
}
```

- [ ] **Step 5: Make `getUserAgent` role-aware**

In `lib/controllers/fb_controller.dart`, replace `getUserAgent` with:

```dart
  /// Returns the user agent to use for [role].
  ///
  /// An explicit custom agent wins over everything, then basic mode, then the
  /// per-role default.
  static String getUserAgent({UserAgentRole role = UserAgentRole.feed}) {
    final customUserAgent = _getOverride(SpKeys.customUserAgent);
    if (customUserAgent != null) {
      debugPrint("Using custom user agent: $customUserAgent");
      return customUserAgent;
    }

    if (sp.getBool(SpKeys.useMbasic) ?? false) return kOperaMiniUserAgent;

    switch (role) {
      case UserAgentRole.feed:
        return kMobileUserAgent;
      case UserAgentRole.messenger:
        return kDesktopUserAgent;
    }
  }
```

- [ ] **Step 6: Have Messenger ask for its own role**

In `lib/screens/messenger_page.dart`, change:

```dart
      ..setUserAgent(PrefController.getUserAgent())
```

to:

```dart
      ..setUserAgent(
        PrefController.getUserAgent(role: UserAgentRole.messenger),
      )
```

`home_page.dart` needs no change — `UserAgentRole.feed` is the default.

- [ ] **Step 7: Verify the whole project**

```bash
fvm flutter analyze --no-fatal-infos lib/ test/ && fvm flutter test
```

Expected: analyze exits 0 (see the baseline note in Task 1 Step 2 — info-level lints are pre-existing and non-fatal here; **no new** `error` or `warning` lines), then all tests pass. If `kFirefoxUserAgent` or `kIpadUserAgent` is still referenced anywhere, the analyzer says so.

- [ ] **Step 8: Re-check the feed selectors against the new layout**

The feed is now served a different layout, so the recon from Task 1 Step 5 has to be re-read and `_postSelector` in `lib/utils/ad_filter.dart` adjusted if the counts moved. If Step 5 of Task 1 was already run under this agent — as that step instructs — this is a no-op and can be ticked off immediately.

Any selector change here belongs in this commit, because it is this task that invalidated it.

- [ ] **Step 9: Commit**

```bash
git add SlimSocial_for_Facebook/lib/consts.dart SlimSocial_for_Facebook/lib/controllers/fb_controller.dart SlimSocial_for_Facebook/lib/screens/messenger_page.dart SlimSocial_for_Facebook/lib/utils/ad_filter.dart SlimSocial_for_Facebook/test/consts_test.dart SlimSocial_for_Facebook/test/controllers/fb_controller_test.dart
git commit -m "fix: serve the feed the mobile layout and Messenger the desktop one"
```

---

## Task 8: Drive the injected accent colour from the theme

`fabBtnCss` hardcodes `#3B5998` twice — once as `background-color`, once as `background`. The injected button therefore ignores the app's colour scheme and cannot follow a theme change. Introduce a `{accent}` placeholder resolved at injection time.

**Files:**
- Modify: `SlimSocial_for_Facebook/lib/utils/css.dart`
- Modify: `SlimSocial_for_Facebook/test/utils/css_test.dart`
- Modify: `SlimSocial_for_Facebook/lib/screens/home_page.dart`
- Modify: `SlimSocial_for_Facebook/lib/screens/messenger_page.dart`

- [ ] **Step 1: Write the failing tests**

Add to `test/utils/css_test.dart`, inside `main()`, and add `import 'package:flutter/material.dart';` at the top of the file:

```dart
  group('resolveCssPlaceholders', () {
    test('substitutes the accent colour', () {
      expect(
        resolveCssPlaceholders('a { color: {accent}; }', accent: '#112233'),
        'a { color: #112233; }',
      );
    });

    test('substitutes every occurrence', () {
      final result = resolveCssPlaceholders(
        'a { color: {accent}; border-color: {accent}; }',
        accent: '#112233',
      );

      expect(result, isNot(contains('{accent}')));
    });

    test('leaves a stylesheet without placeholders untouched', () {
      const css = 'a { color: red; }';

      expect(resolveCssPlaceholders(css, accent: '#112233'), css);
    });
  });

  group('cssColorFromColor', () {
    test('formats a colour as a six-digit hex string', () {
      expect(cssColorFromColor(const Color(0xFF3B5998)), '#3b5998');
    });

    test('drops the alpha channel', () {
      expect(cssColorFromColor(const Color(0x803B5998)), '#3b5998');
    });
  });

  group('theme-aware stylesheets', () {
    test('no bundled stylesheet hardcodes the legacy accent hex', () {
      for (final css in CustomCss.cssList) {
        expect(
          css.code.toLowerCase(),
          isNot(contains('#3b5998')),
          reason: '${css.key} should use the {accent} placeholder',
        );
      }
    });

    test('the floating button uses the placeholder', () {
      expect(CustomCss.fabBtnCss.code, contains('{accent}'));
      expect(
        CustomCss.fabBtnCss.code.toLowerCase(),
        isNot(contains('#3b5998')),
      );
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
fvm flutter test test/utils/css_test.dart
```

Expected: compile failure — `Undefined name 'resolveCssPlaceholders'`.

- [ ] **Step 3: Add the helpers**

In `lib/utils/css.dart`, add `import 'package:flutter/material.dart';` at the top, then these top-level functions above the `CustomCss` class:

```dart
/// Formats [color] as a CSS six-digit hex string, discarding alpha.
String cssColorFromColor(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0')}';
}

/// Replaces the placeholders in [css] with live theme values.
///
/// Stylesheets are authored with `{accent}` rather than a literal colour so one
/// source of truth drives both the Flutter chrome and the injected CSS.
String resolveCssPlaceholders(String css, {required String accent}) {
  return css.replaceAll('{accent}', accent);
}
```

`toARGB32()` exists in the pinned SDK (3.44.8) — this was checked. Do **not** substitute `color.value`: it is `@Deprecated` there, so `flutter analyze` would stop reporting `No issues found!` and every task in this plan gates on that.

- [ ] **Step 4: Replace the hardcoded colour**

In `lib/utils/css.dart`, change `fabBtnCss` to use the placeholder and drop the duplicate declaration:

```dart
  static MyCss fabBtnCss = MyCss(
    key: 'fabBtn',
    description: 'Floating action button',
    code: '.my_fab_btn { position: fixed; z-index: 6; bottom: 10px; '
        'right: 10px; width: 60px; height: 60px; border-radius: 100%; '
        'background: {accent}; border: none; outline: none; color: #FFF; '
        'font-size: 23px; box-shadow: 0 3px 6px rgba(0, 0, 0, 0.16), '
        '0 3px 6px rgba(0, 0, 0, 0.23); transition: .3s; '
        '-webkit-tap-highlight-color: rgba(0, 0, 0, 0); }',
  );
```

- [ ] **Step 5: Resolve the placeholder at injection time**

In `lib/screens/home_page.dart`, in `injectCss`, capture the colour before building the body — read it first so no `BuildContext` is touched after an `await`, which `use_build_context_synchronously` would flag:

```dart
  Future<void> injectCss() async {
    final accent = cssColorFromColor(Theme.of(context).colorScheme.primary);

    final sheets = <String, String>{
      'slim-messenger-download': CustomCss.removeMessengerDownloadCss.code,
      'slim-browser-notice': CustomCss.removeBrowserNotSupportedCss.code,
      'slim-ad-placeholder': CustomCss.adPlaceholderCss.code,
      'slim-user-sheet':
          CustomCss.buildFacebookCss(PrefController.getUserCustomCss()),
    };

    final body = sheets.entries
        .map(
          (e) => CustomJs.injectCssFunc(
            resolveCssPlaceholders(e.value, accent: accent),
            id: e.key,
          ),
        )
        .join('\n');

    await _controller.runJavaScript(CustomJs.whenDomReady(body));
  }
```

Apply the same two changes to `messenger_page.dart`'s `injectCss`: read `accent` first, then wrap each `e.value` in `resolveCssPlaceholders`.

- [ ] **Step 6: Run the tests to verify they pass**

```bash
fvm flutter test test/utils/css_test.dart
```

Expected: all tests pass.

- [ ] **Step 7: Verify the whole project**

```bash
fvm flutter analyze --no-fatal-infos lib/ test/ && fvm flutter test
```

Expected: analyze exits 0 (see the baseline note in Task 1 Step 2 — info-level lints are pre-existing and non-fatal here; **no new** `error` or `warning` lines), then all tests pass.

- [ ] **Step 8: Commit**

```bash
git add SlimSocial_for_Facebook/lib/utils/css.dart SlimSocial_for_Facebook/lib/screens/home_page.dart SlimSocial_for_Facebook/lib/screens/messenger_page.dart SlimSocial_for_Facebook/test/utils/css_test.dart
git commit -m "feat: drive injected accent colour from the app theme"
```

---

## Task 9: Repair the stories toggle and add a reels toggle

`hideStoriesCss` targets `#MStoriesTray` — an id from the legacy `m.facebook.com` layout. If the recon in Task 1 shows the app is not being served that layout, the toggle has been doing nothing, and users have been switching it on and concluding the app is broken. There is no reels toggle at all.

Both are ordinary `MyCss` entries plus a settings tile, so this task is mostly mechanical. The one judgement call is the selector, and Task 1's recon output decides it.

`:has()` is required to hide a post *because of* what it contains. It is supported in Android WebView 105+ and iOS 15.4+. Below that the rule is simply ignored — the toggle degrades to doing nothing rather than breaking the page.

**Files:**
- Modify: `SlimSocial_for_Facebook/lib/utils/css.dart`
- Modify: `SlimSocial_for_Facebook/lib/screens/settings_page.dart`
- Modify: `SlimSocial_for_Facebook/assets/lang/en-US.json`
- Modify: `SlimSocial_for_Facebook/test/utils/css_test.dart`

- [ ] **Step 1: Confirm which selectors are live**

With the app running and attached via `chrome://inspect`, run in the WebView console:

```js
({
  legacyStoriesTray: !!document.querySelector('#MStoriesTray'),
  ariaStories: document.querySelectorAll('[aria-label="Stories"], [aria-label^="Stories"]').length,
  reelLinks: document.querySelectorAll('a[href*="/reel/"], a[href*="/reels/"]').length,
  reelsTray: document.querySelectorAll('[aria-label*="Reels"]').length,
})
```

**This step is already answered by the Task 1 recon — do not redo it.** Results: `legacyStoriesTray` was `0`, confirming the shipped stories selector is dead and the replacement is required. `reelLinks` was `0` too, but that is *not* the "reels are absent, stop" case the earlier draft of this step described — it turned out to mean this layout does not use hrefs at all. A reels carousel was present and is matched by `aria-label`; reel *posts* were not present during the recon, so their rule is verified in Task 10 rather than here.

- [ ] **Step 2: Write the failing tests**

Add to `test/utils/css_test.dart`, inside `main()`:

```dart
  group('media trays', () {
    test('the stories rule leads with a language-independent selector', () {
      // `#MStoriesTray` is an id from the old mobile layout and matched nothing
      // in the recon, so the toggle appeared to do nothing. The replacement
      // keys off `data-srat`, which — unlike an aria-label — is the same in
      // every locale.
      expect(
        CustomCss.hideStoriesCss.code,
        contains('div[data-type="vscroller"] > div[data-srat]'),
        reason: 'stories rule needs a selector for the current layout',
      );
    });

    test('there is a reels stylesheet', () {
      expect(CustomCss.hideReelsCss.key, 'hide_reels');
    });

    test('the reels rule does not rely on hrefs', () {
      // This layout drives navigation through data-action-id and has almost no
      // hrefs; the recon found zero `/reel/` links with reels on screen. A
      // href-based rule silently matches nothing.
      expect(CustomCss.hideReelsCss.code, isNot(contains('href')));
    });

    test('the reels rule tests the attribute value, not its presence', () {
      // Ordinary video posts also carry data-is-reels, with the value "false".
      // Matching on presence alone would hide every video in the feed.
      expect(CustomCss.hideReelsCss.code, contains('[data-is-reels="true"]'));
      expect(CustomCss.hideReelsCss.code, isNot(contains('[data-is-reels]')));
    });

    test('both trays are offered as settings toggles', () {
      final keys = CustomCss.cssList.map((c) => c.key);

      expect(keys, contains('hide_stories'));
      expect(keys, contains('hide_reels'));
    });

    test('neither rule hides the whole feed', () {
      // A selector that matches an ancestor of the feed would blank the page.
      for (final css in [CustomCss.hideStoriesCss, CustomCss.hideReelsCss]) {
        expect(css.code, isNot(contains('body')), reason: css.key);
        expect(css.code, isNot(contains('#root')), reason: css.key);
      }
    });
  });
```

- [ ] **Step 3: Run the tests to verify they fail**

```bash
fvm flutter test test/utils/css_test.dart
```

Expected: compile failure — `CustomCss.hideReelsCss` does not exist.

- [ ] **Step 4: Widen the stories rule and add the reels rule**

In `lib/utils/css.dart`, replace `hideStoriesCss` and add `hideReelsCss` beside it:

```dart
  /// Hides the stories tray.
  ///
  /// The live layout renders the feed as a `vscroller` whose direct children
  /// are the trays and posts. Exactly one of those children carries
  /// `data-srat`, and it is the stories tray — verified against the real DOM,
  /// where the selector matched once and the match contained the create-story
  /// tile. That attribute is language-independent, which the `aria-label`
  /// fallbacks are not, so it leads.
  ///
  /// `#MStoriesTray` is the legacy id. The recon found zero of them, so it is
  /// kept only for anyone still served that older layout.
  static MyCss hideStoriesCss = MyCss(
    key: 'hide_stories',
    description: 'Hide stories',
    code: '#MStoriesTray, '
        'div[data-type="vscroller"] > div[data-srat], '
        'div[data-type="vscroller"] > div:has([aria-label^="Create story"]), '
        'div[data-type="vscroller"] > div:has([aria-label*="story" i]) '
        '{ display: none !important; }',
  );

  /// Hides reels: the reels carousel, and any feed post that is a reel.
  ///
  /// Two things to know here.
  ///
  /// The obvious selector — `a[href*="/reel/"]` — does **not** work. This
  /// layout barely uses hrefs at all; navigation runs through `data-action-id`,
  /// and the recon found zero `/reel/` links while reels were plainly on
  /// screen. An earlier draft of this rule was written that way and would have
  /// hidden nothing.
  ///
  /// The reel *post* rule must test `[data-is-reels="true"]`, not merely the
  /// presence of the attribute: every `data-is-reels` node in the recon carried
  /// the value `"false"`, because ordinary video posts have it too. Matching on
  /// presence would hide **every video in the feed**.
  ///
  /// Honest limitation: no reel posts were in the feed during the recon, so the
  /// `="true"` rule is reasoned from the attribute's meaning rather than
  /// observed matching. The carousel rule *was* observed. Task 10 verifies both.
  static MyCss hideReelsCss = MyCss(
    key: 'hide_reels',
    description: 'Hide reels',
    code: 'div[data-type="vscroller"] > div:has([aria-label*="reel" i]), '
        'div[data-tracking-duration-id]:has([data-is-reels="true"]) '
        '{ display: none !important; }',
  );
```

Then add it to the toggle list:

```dart
  static List<MyCss> cssList = [
    centerTextPostsCss,
    addSpaceBetweenPostsCss,
    hideStoriesCss,
    hideReelsCss,
    fixedBarCss,
    //hideAdsAndPeopleYouMayKnowCss,
    darkThemeCss,
    hideMessengerSidebar,
  ];
```

- [ ] **Step 5: Add the settings tile**

In `lib/screens/settings_page.dart`, directly after the `hideStoriesCss` tile, add:

```dart
              SettingsTile.switchTile(
                onToggle: (value) {
                  setState(() {
                    sp.setBool(CustomCss.hideReelsCss.key, value);
                  });
                  ref.invalidate(fbWebViewProvider);
                },
                initialValue: CustomCss.hideReelsCss.isEnabled(),
                title: Text(CustomCss.hideReelsCss.key.tr()),
                leading: const Icon(Icons.video_library_outlined),
              ),
```

- [ ] **Step 6: Add the label and guard it**

In `assets/lang/en-US.json`, add:

```json
  "hide_reels": "Hide reels"
```

Then extend the key list in the `the fallback locale defines every key the UI asks for` test in `test/lang_test.dart`, which Task 6 created, so the new key is guarded too — add `'hide_reels',` between `'hide_ads'` and `'hide_stories'`.

- [ ] **Step 7: Run the tests to verify they pass**

```bash
fvm flutter test test/utils/css_test.dart test/lang_test.dart
```

Expected: all tests pass.

The pre-existing `every bundled stylesheet is collapsed to one line` test also covers the two new entries — `MyCss` normalises them, so no extra work.

- [ ] **Step 8: Commit**

```bash
git add SlimSocial_for_Facebook/lib/utils/css.dart SlimSocial_for_Facebook/lib/screens/settings_page.dart SlimSocial_for_Facebook/assets/lang/en-US.json SlimSocial_for_Facebook/test/utils/css_test.dart SlimSocial_for_Facebook/test/lang_test.dart
git commit -m "feat: add a reels toggle and repair the stories selector"
```

---

## Task 10: Manual verification on a device

Everything above is unit-tested Dart. The injected JavaScript has no Dart-side runtime, so its behaviour needs confirming once in the real app.

**Files:** none — this task only runs and observes.

- [ ] **Step 1: Launch**

```bash
fvm flutter run --debug
```

Wait for the feed and log in if needed.

Before anything else, confirm the feed is being served the layout everything else here assumes. Attach to the WebView from Chrome via `chrome://inspect` and run:

```js
({
  ua: navigator.userAgent,
  url: location.href,
  notice: document.body.innerText.indexOf('browser') !== -1,
})
```

Expected: the agent contains `Android` and `Mobile`, and the feed renders as the touch layout — single column, no desktop sidebars. If a "browser not supported" notice is visible, the agent's version numbers are too old for what Facebook now accepts: bump `rv:`, `Gecko/` and `Firefox/` in `kMobileUserAgent` together, re-run the Task 1 recon, and land the change in Task 7's commit. Stop here if the feed does not render — nothing below is meaningful on the wrong layout.

- [ ] **Step 2: Confirm no duplicate stylesheets**

Attach to the WebView from Chrome via `chrome://inspect`, then in its console:

```js
document.querySelectorAll('style[id^="slim-"]').length
```

Note the number, open a post, come back, and re-run it.

Expected: the count does not grow. Before this plan every navigation appended another copy.

- [ ] **Step 3: Confirm ad hiding survives scrolling**

With **Hide some ads** on, scroll until several screens of new posts have loaded, then:

```js
document.querySelectorAll('.slim-ad-handled').length
```

Expected: greater than zero, and it keeps growing as you scroll.

- [ ] **Step 4: Confirm ads are collapsed, not destroyed**

```js
var p = document.querySelector('.slim-ad-handled');
[p.getAttribute('data-slim-height-original'),
 p.getAttribute('data-actual-height'),
 p.children.length]
```

Expected: the original height is preserved, the current height is `60`, and `children.length` is greater than 1 — the subtree still exists.

- [ ] **Step 5: Confirm no false positives**

Find or post a status whose text contains the word "Sponsored" as ordinary prose, then refresh.

Expected: it is **not** collapsed. The length guard is what makes this pass; before it, any such post was overwritten.

- [ ] **Step 6: Confirm styling still applies**

Enable **Fixed top bar** and **Add space between posts** in Settings, return to the feed, pull to refresh.

Expected: the top bar stays pinned while scrolling and posts are visibly further apart.

- [ ] **Step 7: Confirm the accent colour follows the theme**

Toggle **Enable dark theme** and let the app restart. If the floating button is enabled, check its colour.

Expected: it matches the app's primary colour, not the old fixed blue.

- [ ] **Step 8: Confirm Messenger still works**

Open Messenger from the app. Send yourself a message.

Expected: the conversation list and composer render normally. This is the check on the desktop agent from Task 7.

- [ ] **Step 9: Confirm Russian localisation loads**

Switch the device language to Russian and relaunch.

Expected: settings labels are Russian.

- [ ] **Step 10: Confirm the stories and reels toggles do something**

Turn **Hide stories** on, return to the feed, pull to refresh.

Expected: the stories row is gone. If it is still there, the selector from Task 9 Step 1 was wrong — go back and re-read the live DOM rather than guessing again.

Turn **Hide reels** on and refresh.

Expected: reel posts and any reels tray are gone, and ordinary posts are untouched. Check the feed still scrolls: if it is empty, a `:has()` selector matched an ancestor of the feed and must be tightened.

---

## Self-Review

**Spec coverage.** Every numbered problem in *Current State* maps to a task: 1 and 2→2, 3–5→4, 6→3, 7→5, 8 and 9→6, 10→7, 11→8, 12 and 13→9. Task 1 is a preflight gate that records the baseline; Task 10 covers the behaviour no unit test can reach.

**Cross-task dependencies.** Every task commits a tree that compiles, passes `fvm flutter analyze lib/ test/` and passes the whole suite — there is no intermediate state where the app is broken or ad hiding is off. Three orderings enforce that. `CustomCss.adPlaceholderCss` is created in Task 2, where its call site first needs it, rather than in Task 4. `kSponsoredLabels` lands in Task 3, before Task 4's script references it, which is why the label list comes first even though the detection logic is the headline change. And Task 4 deletes `CustomJs.removeAdsFunc` in the same commit that adds `adFilterScript`, so Task 2 deliberately keeps the old ad injection in place.

**Names used consistently.** `window.slimRemoveAds` is defined in Task 4 and called in Task 5. `window.slimAdObserver` is only in Task 5. `slim-ad-handled` and `slim-ad-placeholder` match between the script in Task 4 and the stylesheet in Task 2. `CustomJs.injectCssFunc(css, {required String id})` and `CustomJs.whenDomReady(body)` keep the same signatures in Tasks 2, 4 and 8. `cssColorFromColor` and `resolveCssPlaceholders` are only in Task 8.

**Existing tests updated, not duplicated.** Tasks 2 and 5 replace named groups in `test/utils/js_test.dart`, and Task 7 replaces the `kFirefoxUserAgent` group in `test/consts_test.dart`, because those groups assert on values these tasks change. Tasks 4 and 8 only add groups.

**Validated before acceptance, not just proofread.** Every generated script in this plan (`injectCssFunc`, `whenDomReady`, `adFilterScript`, `removeAdsObserver`) was extracted, had its Dart interpolations substituted, and was parsed with `node --check` — all four are syntactically valid. Every assertion in Task 2 was executed against the proposed implementation and passes. `toARGB32()` was confirmed present in the pinned SDK. `ru-RU.json` was confirmed still invalid (line 53 by the parser's count) and `hide_messenger_sidebar` still absent from `en-US.json`, so Task 6's premises hold; all 43 locale files do carry `sponsored_keyword_fb`.

The label matcher was not merely string-asserted but **executed**: `広告` and `광고` match, `Sponsored` matches, and neither a long English sentence containing "Sponsored" nor a long Japanese sentence containing `広告` matches. That last case is the whole reason short labels are compared as whole strings.

**A blocker this validation caught.** An earlier draft asserted that every bundled label was at least `kMinSponsoredLabelLength` (4) characters while also asserting that `広告` and `광고` were present — two tests that cannot both pass, since those labels are two characters. Worse, the text tier's lower bound of `> 3` meant CJK labels could never have matched even if the list kept them, so ad filtering was silently dead in Chinese, Japanese and Korean. Labels below the substring floor are now compared against the candidate's whole trimmed text, and a short *runtime* extra — which in a CJK locale is the app's own `sponsored_keyword_fb` — is routed there too instead of being discarded.

**The one risky task is 7.** Everything else is invisible to Facebook: it changes what the app injects, not what the app asks for. Task 7 changes what Facebook serves, so it can regress the whole feed rather than one feature — which is why it re-runs Task 1's recon (Step 8), owns any selector change that recon forces, and is gated first in Task 10 Step 1. Its two constants are not guesses: the feed agent is the exact string captured from the reference app's live server config — the value that serves the mobile layout in the regions where a desktop agent breaks — and the Messenger agent is that app's conversation agent. `consts_test.dart` pins the feed agent verbatim so a well-meaning version bump cannot silently switch the served layout back.

---

## Follow-up work (separate plans)

1. **Background notifications.** Needs a headless-capable WebView plus a periodic worker at or above the platform's 15-minute floor, a foreground check, and notification channels. Largest remaining item by far.
2. **Word filter and post highlighting.** Hide or highlight posts matching user keywords, reusing the collapse mechanism from Task 4.
3. **Per-URL styling.** Stamp the current URL onto `<html>` as a data attribute so stylesheets can target individual pages with no JavaScript.
4. **Feature flags as `<html>` classes.** Toggle settings by adding and removing root classes instead of re-injecting, so changes apply without a reload.
5. **Higher-quality media.** Facebook offers higher-bitrate renditions to tablet agents. Add a `UserAgentRole.video` backed by an iPad agent — `Mozilla/5.0 (iPad; U; CPU OS 12_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/69.0.3497.105 Mobile/15E148 Safari/605.1` — and use it when resolving media URLs. Left out of Task 7 because nothing consumes it yet.
6. **Undo for collapsed ads.** `data-slim-height-original` already makes this a small addition: a tap target on the stub that restores the post.
