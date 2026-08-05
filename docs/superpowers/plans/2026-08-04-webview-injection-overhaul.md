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
| 3 | Ad detection matches keywords in `span.textContent` with no length bound, so a post *mentioning* the word is destroyed | 3 |
| 4 | Detection ignores `data-ft` / `data-xt-vimp` / ad-link markers, which are locale-independent and cheaper than text | 3 |
| 5 | `post.innerHTML = myDiv` destroys the post subtree and breaks the virtualising scroller | 3 |
| 6 | The keyword list covers ~24 strings and misses most supported locales | 4 |
| 7 | The observer only reacts to added `SECTION` nodes, has no debounce, and assumes `removeAds` exists | 5 |
| 8 | `assets/lang/ru-RU.json` is invalid JSON, so Russian falls back to English | 6 |
| 9 | `hide_messenger_sidebar` is missing from `en-US.json`, so that settings row shows a raw key | 6 |
| 10 | One desktop user agent for every surface | 7 |
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
| `lib/consts.dart` | Modify | Add user-agent roles |
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

- [ ] **Step 2: Confirm the analyzer is clean**

```bash
fvm flutter analyze lib/ test/
```

Expected: `No issues found!`

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

Tasks 3 and 9 pick DOM selectors. Which selectors are correct depends entirely on which layout Facebook returns for this app's URL and user agent, and that is not knowable from the source: the app requests `touch.facebook.com` but sends a desktop Firefox agent, and the stylesheets in `css.dart` contain selectors from *both* the legacy mobile layout (`._5rgt._5msi`, `#MStoriesTray`) and the current one (`x9f619…`). One of those sets is dead weight.

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

Paste the result into the task notes. It decides three things:

- **`_postSelector` in Task 3.** Use whichever of `article`, `div[data-tracking-duration-id]`, `[role="article"]` or `[data-pagelet^="FeedUnit"]` is non-zero. If the counts disagree with the plan's assumed `'article, div[data-tracking-duration-id]'`, change the plan, not the reality.
- **Whether the `data-ft` / `data-xt-vimp` tiers are worth keeping.** If both are `0`, the attribute tiers cannot fire and Task 3's cascade collapses to the text tier alone — say so and keep the tiers only as forward-compatibility.
- **Whether `data-actual-height` exists**, which is what Task 3's collapse rewrites and what Task 10 Step 4 verifies. If it is absent, the collapse still works (the write is guarded) but drop that assertion from Task 10.

Do not start Task 3 before this step has an answer.

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

    test('encodes newlines so the caller can flatten the snippet', () {
      // The generated code is flattened before it is handed to the webview, so
      // a raw newline inside the string literal would be destroyed.
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

- [ ] **Step 5: Update the Facebook call site**

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

    final body = sheets.entries
        .map((e) => CustomJs.injectCssFunc(e.value, id: e.key))
        .join('\n');

    await _controller.runJavaScript(
      CustomJs.whenDomReady(body).replaceAll('\n', ' '),
    );
  }
```

`CustomCss.adPlaceholderCss` is added in Task 3 — the analyzer will flag it until then, which is expected.

The `removeAdsFunc` injection and the `removeAds();` call move out of `injectCss` and into `runJs` in Task 3, so that ad handling is set up in one place after the page has loaded rather than split across two lifecycle callbacks.

- [ ] **Step 6: Update the Messenger call site**

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

    await _controller.runJavaScript(
      CustomJs.whenDomReady(body).replaceAll('\n', ' '),
    );
  }
```

- [ ] **Step 7: Commit**

```bash
git add SlimSocial_for_Facebook/lib/utils/js.dart SlimSocial_for_Facebook/lib/screens/home_page.dart SlimSocial_for_Facebook/lib/screens/messenger_page.dart SlimSocial_for_Facebook/test/utils/js_test.dart
git commit -m "fix: inject each stylesheet once, into head, as text"
```

---

## Task 3: Layered ad detection

Three defects remain in `removeAdsFunc`.

**No length bound on text matching.** `querySelectorAll('span')` returns thousands of nodes on a loaded feed, and `textContent` on an ancestor includes all descendant text. Any post whose *body* contains the word "Sponsored" — a status complaining about ads, a screenshot caption — is destroyed. A genuine label is a short standalone string, so bounding the match to 4–24 characters removes almost all of these false positives.

**Markup is ignored.** Facebook tags sponsored units with attributes: `data-ft` containing `is_sponsored` or `should_log_endpoint_info`, `data-xt-vimp`, and links to `/ads/about/`. These are locale-independent and vastly cheaper to test than walking every descendant's text. Checking them first means the text tier is only reached for units that carry no attribute at all.

**The post subtree is destroyed.** `post.innerHTML = myDiv` throws away the post's children. Facebook's own scripts still hold references into that subtree, and the mobile feed virtualises on `data-actual-height`, so overwriting content leaves the scroller with wrong geometry. Hiding the children and appending a stub keeps both intact and makes the operation reversible.

**Files:**
- Create: `SlimSocial_for_Facebook/lib/utils/ad_filter.dart`
- Create: `SlimSocial_for_Facebook/test/utils/ad_filter_test.dart`
- Modify: `SlimSocial_for_Facebook/lib/utils/css.dart`
- Modify: `SlimSocial_for_Facebook/lib/screens/home_page.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/utils/ad_filter_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:slimsocial_for_facebook/utils/ad_filter.dart';

void main() {
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

    test('bounds the text tier so prose mentioning the word is spared', () {
      expect(script, contains('> 3'));
      expect(script, contains('< 25'));
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
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
fvm flutter test test/utils/ad_filter_test.dart
```

Expected: `Error: Couldn't resolve the package 'slimsocial_for_facebook/utils/ad_filter.dart'`.

- [ ] **Step 3: Create `lib/utils/ad_filter.dart`**

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

/// Containers that hold a single feed post across Facebook's mobile layouts.
const String _postSelector = 'article, div[data-tracking-duration-id]';

/// Shortest label the text tier will consider.
///
/// Short strings appear all over Facebook's own chrome, so matching them
/// produces false positives.
const int kMinSponsoredLabelLength = 4;

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
  final labels = <String>[
    ...kSponsoredLabels,
    for (final label in extraLabels)
      if (label.trim().length >= kMinSponsoredLabelLength)
        label.trim().toLowerCase(),
  ].toSet().toList();

  return '''
(function () {
  var LABELS = ${jsonEncode(labels)};
  var PLACEHOLDER = ${jsonEncode(placeholderText)};
  var memo = null;

  function isSponsoredLabel(text) {
    if (!text) return false;
    var lower = text.toLowerCase();
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
      // Without this window an ordinary post that merely mentions the word
      // would be hidden along with the real ads.
      if (text.length > 3 && text.length < 25 && isSponsoredLabel(text)) {
        return true;
      }
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

`kSponsoredLabels` is defined in Task 4. Until then the analyzer reports it as undefined — that is expected, and Task 4's tests are what prove the list is sound.

- [ ] **Step 4: Add the placeholder stylesheet**

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

- [ ] **Step 5: Switch the call site over**

In `lib/screens/home_page.dart`, replace `runJs` with:

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

- [ ] **Step 6: Delete the superseded string**

Remove `CustomJs.removeAdsFunc` and `CustomJs.exampleJs` from `lib/utils/js.dart`. `removeAdsFunc` is replaced by `adFilterScript`; `exampleJs` is dead code that blanks the page body and is referenced nowhere.

Confirm nothing still refers to them:

```bash
grep -rn "removeAdsFunc\|exampleJs" lib/ test/
```

Expected: no output.

- [ ] **Step 7: Run the tests to verify they pass**

```bash
fvm flutter test test/utils/ad_filter_test.dart
```

Expected: all 9 tests pass. They will only compile once Task 4 has added `kSponsoredLabels`, so if the analyzer still reports it missing, do Task 4 first and return here.

- [ ] **Step 8: Commit**

```bash
git add SlimSocial_for_Facebook/lib/utils/ad_filter.dart SlimSocial_for_Facebook/lib/utils/js.dart SlimSocial_for_Facebook/lib/utils/css.dart SlimSocial_for_Facebook/lib/screens/home_page.dart SlimSocial_for_Facebook/test/utils/ad_filter_test.dart
git commit -m "feat: detect sponsored posts by markup and collapse them in place"
```

---

## Task 4: Sponsored labels for every supported locale

The keyword list covers roughly 24 strings, several of them machine translations that do not match what Facebook actually renders, and it appends only `"sponsored_keyword_fb".tr()` — the label for the **app's** locale.

That last part is the real gap. Facebook renders the label in the language of the **Facebook account**, which is frequently not the language the app is running in, and a feed can mix several. All 41 locale files already carry a `sponsored_keyword_fb` value, so bundling every one of them costs nothing and covers the mismatch.

**Files:**
- Modify: `SlimSocial_for_Facebook/lib/utils/ad_filter.dart`
- Modify: `SlimSocial_for_Facebook/test/utils/ad_filter_test.dart`

- [ ] **Step 1: Write the failing tests**

Add to `test/utils/ad_filter_test.dart`, inside `main()`:

```dart
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

    test('every label is long enough to survive the length guard', () {
      for (final label in kSponsoredLabels) {
        expect(
          label.length,
          greaterThanOrEqualTo(kMinSponsoredLabelLength),
          reason: '"$label" is too short to ever match',
        );
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

    test('ignores a runtime extra that is too short to match', () {
      final withShort = adFilterScript(
        placeholderText: 'x',
        extraLabels: const ['ad'],
      );
      final bundled = adFilterScript(placeholderText: 'x');

      expect(withShort, bundled);
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
fvm flutter test test/utils/ad_filter_test.dart
```

Expected: compile failure — `Undefined name 'kSponsoredLabels'`.

- [ ] **Step 3: Add the label list**

Add to `lib/utils/ad_filter.dart`, above `adFilterScript`:

```dart
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

If `every label is long enough` fails, a label is shorter than `kMinSponsoredLabelLength` — delete it, because the guard makes it unreachable.

- [ ] **Step 5: Commit**

```bash
git add SlimSocial_for_Facebook/lib/utils/ad_filter.dart SlimSocial_for_Facebook/test/utils/ad_filter_test.dart
git commit -m "feat: bundle sponsored-post labels for every supported locale"
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
fvm flutter analyze lib/ test/ && fvm flutter test
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

One desktop Firefox agent is used everywhere. Different surfaces behave differently: a mobile agent gets Facebook's lightweight mobile renderer, which is faster and much easier to restyle, while Messenger only ships its full markup to a desktop agent, and tablets are offered higher-bitrate video renditions.

Add a role so each call site asks for what it needs, leaving the existing custom-agent and basic-mode overrides in charge.

**Files:**
- Modify: `SlimSocial_for_Facebook/lib/consts.dart`
- Modify: `SlimSocial_for_Facebook/lib/controllers/fb_controller.dart`
- Modify: `SlimSocial_for_Facebook/test/controllers/fb_controller_test.dart`
- Modify: `SlimSocial_for_Facebook/lib/screens/messenger_page.dart`

- [ ] **Step 1: Write the failing tests**

Add to `test/controllers/fb_controller_test.dart`, inside `main()`:

```dart
  group('getUserAgent roles', () {
    test('defaults to the feed agent', () {
      expect(
        PrefController.getUserAgent(),
        PrefController.getUserAgent(role: UserAgentRole.feed),
      );
    });

    test('gives Messenger the desktop agent', () {
      expect(
        PrefController.getUserAgent(role: UserAgentRole.messenger),
        kDesktopUserAgent,
      );
    });

    test('gives video the tablet agent', () {
      expect(
        PrefController.getUserAgent(role: UserAgentRole.video),
        kTabletUserAgent,
      );
    });

    test('basic mode overrides every role', () async {
      await sp.setBool(SpKeys.useMbasic, true);

      for (final role in UserAgentRole.values) {
        expect(
          PrefController.getUserAgent(role: role),
          kOperaMiniUserAgent,
          reason: 'role $role should honour basic mode',
        );
      }
    });

    test('a custom agent overrides every role', () async {
      await sp.setBool(SpKeys.enabled(SpKeys.customUserAgent), true);
      await sp.setString(SpKeys.customUserAgent, 'my-agent');

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

- [ ] **Step 2: Run the tests to verify they fail**

```bash
fvm flutter test test/controllers/fb_controller_test.dart
```

Expected: compile failure — `Undefined name 'UserAgentRole'`, `kDesktopUserAgent`, `kTabletUserAgent`.

- [ ] **Step 3: Add the constants and the role**

In `lib/consts.dart`, add below the existing user-agent block. Leave `kFirefoxUserAgent` exactly as it is — `consts_test.dart` asserts on its version numbers, and it stays the feed default so this task changes no behaviour on its own.

```dart
/// Desktop Safari. Some surfaces — Messenger in particular — only ship their
/// full markup to a desktop agent.
const String kDesktopUserAgent =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 "
    "(KHTML, like Gecko) Version/17.0 Safari/605.1.15";

/// Tablet Safari. Facebook offers higher-bitrate video renditions to tablets.
const String kTabletUserAgent =
    "Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15 "
    "(KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1";

/// Which surface a user agent is being requested for.
///
/// Facebook varies both the markup it serves and the media quality it offers
/// by user agent, so one string for the whole app leaves quality on the table.
enum UserAgentRole {
  /// The main feed and everything reached from it.
  feed,

  /// The Messenger webview.
  messenger,

  /// Video playback and downloads.
  video,
}
```

- [ ] **Step 4: Make `getUserAgent` role-aware**

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
        return kFirefoxUserAgent;
      case UserAgentRole.messenger:
        return kDesktopUserAgent;
      case UserAgentRole.video:
        return kTabletUserAgent;
    }
  }
```

- [ ] **Step 5: Have Messenger ask for its own role**

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

- [ ] **Step 6: Run the tests to verify they pass**

```bash
fvm flutter test test/controllers/fb_controller_test.dart
```

Expected: all tests pass, including the pre-existing ones.

- [ ] **Step 7: Commit**

```bash
git add SlimSocial_for_Facebook/lib/consts.dart SlimSocial_for_Facebook/lib/controllers/fb_controller.dart SlimSocial_for_Facebook/lib/screens/messenger_page.dart SlimSocial_for_Facebook/test/controllers/fb_controller_test.dart
git commit -m "feat: choose the user agent per surface"
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

If the analyzer reports `toARGB32` as undefined, the SDK predates it — use `color.value & 0xFFFFFF` instead.

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

    await _controller.runJavaScript(
      CustomJs.whenDomReady(body).replaceAll('\n', ' '),
    );
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
fvm flutter analyze lib/ test/ && fvm flutter test
```

Expected: `No issues found!` then all tests pass.

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

Record the output. If `legacyStoriesTray` is `false`, the shipped stories selector is confirmed dead and Step 3's replacement is required. If `reelLinks` is `0`, reels are not present on this surface — stop and report, because there is nothing to hide and the rest of this task would be guesswork.

- [ ] **Step 2: Write the failing tests**

Add to `test/utils/css_test.dart`, inside `main()`:

```dart
  group('media trays', () {
    test('the stories rule is not limited to the legacy tray id', () {
      // `#MStoriesTray` is an id from the old mobile layout. On its own it
      // silently matched nothing, so the toggle appeared to do nothing.
      expect(
        CustomCss.hideStoriesCss.code,
        contains('aria-label'),
        reason: 'stories rule needs a selector for the current layout',
      );
    });

    test('there is a reels stylesheet', () {
      expect(CustomCss.hideReelsCss.key, 'hide_reels');
      expect(CustomCss.hideReelsCss.code, contains('/reel/'));
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
  /// `#MStoriesTray` is the legacy mobile id and is kept only so the toggle
  /// keeps working for anyone still served that layout; the `aria-label`
  /// selectors cover the current one.
  static MyCss hideStoriesCss = MyCss(
    key: 'hide_stories',
    description: 'Hide stories',
    code: '#MStoriesTray, '
        'div[aria-label="Stories"], '
        'div[aria-label^="Stories"] '
        '{ display: none !important; }',
  );

  /// Hides reels: both a dedicated tray and any feed post that is a reel.
  ///
  /// The post rule needs `:has()` to match a container by what it contains.
  /// Unsupported engines ignore the rule, so the toggle degrades to a no-op
  /// rather than breaking the layout.
  static MyCss hideReelsCss = MyCss(
    key: 'hide_reels',
    description: 'Hide reels',
    code: 'div[aria-label*="Reels"], '
        'article:has(a[href*="/reel/"]), '
        'div[data-tracking-duration-id]:has(a[href*="/reel/"]), '
        'div[role="article"]:has(a[href*="/reel/"]) '
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

**Spec coverage.** Every numbered problem in *Current State* maps to a task: 1 and 2→2, 3–5→3, 6→4, 7→5, 8 and 9→6, 10→7, 11→8, 12 and 13→9. Task 1 is a preflight gate that records the baseline; Task 10 covers the behaviour no unit test can reach.

**Cross-task dependencies.** Task 2 references `CustomCss.adPlaceholderCss`, added in Task 3. Task 3 references `kSponsoredLabels`, added in Task 4. Both are called out inline where they occur. Executing in order leaves the analyzer briefly unhappy between Tasks 2 and 4; the first green `fvm flutter analyze` gate is at the end of Task 5.

**Names used consistently.** `window.slimRemoveAds` is defined in Task 3 and called in Task 5. `window.slimAdObserver` is only in Task 5. `slim-ad-handled` and `slim-ad-placeholder` match between the script in Task 3 and the stylesheet in Task 3. `CustomJs.injectCssFunc(css, {required String id})` and `CustomJs.whenDomReady(body)` keep the same signatures in Tasks 2, 3 and 8. `cssColorFromColor` and `resolveCssPlaceholders` are only in Task 8.

**Existing tests updated, not duplicated.** Tasks 2 and 5 replace named groups in `test/utils/js_test.dart` because those groups assert on generated strings that these tasks change. Tasks 4, 7 and 8 only add groups.

---

## Follow-up work (separate plans)

1. **Background notifications.** Needs a headless-capable WebView plus a periodic worker at or above the platform's 15-minute floor, a foreground check, and notification channels. Largest remaining item by far.
2. **Word filter and post highlighting.** Hide or highlight posts matching user keywords, reusing the collapse mechanism from Task 3.
3. **Per-URL styling.** Stamp the current URL onto `<html>` as a data attribute so stylesheets can target individual pages with no JavaScript.
4. **Feature flags as `<html>` classes.** Toggle settings by adding and removing root classes instead of re-injecting, so changes apply without a reload.
5. **Higher-quality video.** Use `UserAgentRole.video` from Task 7 when resolving video and image download URLs.
6. **Undo for collapsed ads.** `data-slim-height-original` already makes this a small addition: a tap target on the stub that restores the post.
