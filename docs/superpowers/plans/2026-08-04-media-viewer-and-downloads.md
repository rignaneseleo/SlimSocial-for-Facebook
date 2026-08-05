# Photo Viewer and Downloads — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user open any photo in the feed full-screen and save it, without leaving the app or losing their scroll position.

**Architecture:** A small injected script decorates every sufficiently large image with two overlay buttons. Tapping one posts a JSON message over a `JavaScriptChannel` to Dart, which either pushes a Flutter full-screen viewer route or runs a download helper. No page navigation is involved, so the feed keeps its scroll position and the webview is never sent to a raw CDN URL.

**Tech Stack:** Flutter 3.44.8 via fvm, Dart, `webview_flutter` 4.10.0, `flutter_file_downloader`, `share_plus`, `open_file_plus`, `flutter_test`.

**Every command below runs from `SlimSocial_for_Facebook/`** and is prefixed with `fvm`.

**Depends on:** `2026-08-04-webview-injection-overhaul.md`. That plan fixes `injectCssFunc` (stable ids, `textContent`, `<head>`) and adds `resolveCssPlaceholders`, which Task 3 here uses. Land it first.

**Not in scope: video.** Video full-screen already works — `setCustomWidgetCallbacks` at `home_page.dart:85` hands Facebook's own full-screen widget to a Flutter route, and nothing here touches it. Video *download* is deliberately excluded: where Facebook delivers video through Media Source Extensions, `<video>.src` is a `blob:` URL that exists only inside the page and cannot be handed to a downloader, so supporting it would mean intercepting network requests — something `webview_flutter` cannot do. Task 7 Step 7 confirms video playback and full-screen still work; no video button is offered anywhere.

---

## What already works, and what does not

| Capability | Today |
|---|---|
| Video full-screen | **Works**, untouched by this plan. |
| Photo full-screen | Missing. Tapping a photo navigates the whole webview, and `fbcdn.net` is not in `kPermittedHostnamesFb`, so some taps leave the app for the system browser. |
| Photo download | Only after the webview has already navigated to a `scontent.*` URL, via the `isScontentUrl` buttons in the app bar. Not available from the feed. |
| Sharing a downloaded photo | Works, same `isScontentUrl` path. |
| Video download | Out of scope, see above. |

This plan builds an in-page affordance, a channel, a viewer and a download helper. It leaves the existing `isScontentUrl` app-bar buttons in place — they remain the fallback for when the user has already navigated to a bare image.

---

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `lib/utils/media_overlay.dart` | Create | Generates the injected overlay script; defines the message contract |
| `lib/utils/media_download.dart` | Create | Download a URL to the device; filename derivation |
| `lib/screens/media_viewer_page.dart` | Create | Full-screen photo viewer route |
| `lib/utils/css.dart` | Modify | Overlay button styling |
| `lib/screens/home_page.dart` | Modify | Register the channel, inject the overlay, route messages |
| `lib/utils/utils.dart` | Modify | `downloadImage` becomes a thin wrapper over the new helper |
| `assets/lang/en-US.json` | Modify | New strings |
| `test/utils/media_overlay_test.dart` | Create | Message contract + generated-script tests |
| `test/utils/media_download_test.dart` | Create | Filename derivation tests |

The names stay `media_*` rather than `photo_*`: the download helper and the viewer are URL-generic, and only the overlay's *scan* is photo-specific. That keeps the door open for video later without renaming three files.

`media_overlay.dart` and `media_download.dart` are separate because one is a string generator with no I/O and the other is all I/O — they are tested completely differently.

---

## Task 1: The message contract

Dart and the injected script have to agree on a payload. Define and test that first, in Dart, before any JavaScript exists — a typo in a channel message is otherwise invisible until manual testing.

**Files:**
- Create: `SlimSocial_for_Facebook/lib/utils/media_overlay.dart`
- Create: `SlimSocial_for_Facebook/test/utils/media_overlay_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/utils/media_overlay_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:slimsocial_for_facebook/utils/media_overlay.dart';

void main() {
  group('MediaRequest.fromJson', () {
    test('parses a view request', () {
      final request = MediaRequest.fromJson(
        jsonEncode({
          'action': 'view',
          'url': 'https://scontent.example/a.jpg',
        }),
      );

      expect(request, isNotNull);
      expect(request!.action, MediaAction.view);
      expect(request.url, 'https://scontent.example/a.jpg');
    });

    test('parses a save request', () {
      final request = MediaRequest.fromJson(
        jsonEncode({
          'action': 'save',
          'url': 'https://scontent.example/a.jpg',
        }),
      );

      expect(request!.action, MediaAction.save);
    });

    test('returns null for a malformed payload', () {
      expect(MediaRequest.fromJson('not json'), isNull);
      expect(MediaRequest.fromJson('[]'), isNull);
      expect(MediaRequest.fromJson('{}'), isNull);
      expect(MediaRequest.fromJson(jsonEncode({'action': 'view'})), isNull);
      expect(
        MediaRequest.fromJson(jsonEncode({'url': 'https://a.example/a.jpg'})),
        isNull,
      );
    });

    test('returns null for an unknown action', () {
      expect(
        MediaRequest.fromJson(
          jsonEncode({'action': 'delete', 'url': 'https://a.example/a.jpg'}),
        ),
        isNull,
      );
    });

    test('rejects a url that is not http(s)', () {
      // The page can post anything it likes down this channel, so the scheme is
      // checked here rather than trusted. blob: and data: matter in particular:
      // an <img> can carry either, and neither can be downloaded or shared.
      for (final url in const [
        'blob:https://facebook.com/abc',
        'data:image/png;base64,iVBORw0KGgo=',
        'javascript:alert(1)',
        'file:///etc/passwd',
        'https://',
        '',
      ]) {
        expect(
          MediaRequest.fromJson(jsonEncode({'action': 'save', 'url': url})),
          isNull,
          reason: 'should have rejected $url',
        );
      }
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
fvm flutter test test/utils/media_overlay_test.dart
```

Expected: `Error: Couldn't resolve the package 'slimsocial_for_facebook/utils/media_overlay.dart'`.

- [ ] **Step 3: Create the contract**

Create `lib/utils/media_overlay.dart`:

```dart
import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Name of the `JavaScriptChannel` the overlay posts to.
const String kMediaChannelName = 'SlimMedia';

/// What the user asked for.
enum MediaAction { view, save }

/// A request posted by the injected overlay.
///
/// Anything can be posted down a JavaScript channel — the page's own scripts
/// included — so every field is validated here and a bad payload yields null
/// rather than a partly-populated object.
@immutable
class MediaRequest {
  const MediaRequest({required this.action, required this.url});

  /// Parses [raw], returning null if it is not a well-formed request for an
  /// http(s) URL.
  static MediaRequest? fromJson(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;

    final url = decoded['url'];
    if (url is! String) return null;

    MediaAction? action;
    for (final value in MediaAction.values) {
      if (value.name == decoded['action']) action = value;
    }
    if (action == null) return null;

    // blob:, data:, javascript: and file: must never reach a downloader or an
    // Image widget.
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    if (uri.host.isEmpty) return null;

    return MediaRequest(action: action, url: url);
  }

  final MediaAction action;
  final String url;
}
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
fvm flutter test test/utils/media_overlay_test.dart
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add SlimSocial_for_Facebook/lib/utils/media_overlay.dart SlimSocial_for_Facebook/test/utils/media_overlay_test.dart
git commit -m "feat: define the media request contract for the webview channel"
```

---

## Task 2: The overlay script

Decorate photos with a view button and a save button. The script runs on an interval rather than a `MutationObserver` because it has to react to images *growing*: Facebook swaps in a full-resolution source after layout, so an image that measured 40px when first seen can be 400px a moment later, and a mutation-driven pass would already have dismissed it.

Two guards matter:

- **A size floor.** Avatars, reaction icons and emoji are all `<img>`. Decorating them would put a button over every face in the feed. Only images at least 200px on both axes qualify.
- **A processed marker.** Without one the interval re-decorates the same image every tick.

**Files:**
- Modify: `SlimSocial_for_Facebook/lib/utils/media_overlay.dart`
- Modify: `SlimSocial_for_Facebook/test/utils/media_overlay_test.dart`

- [ ] **Step 1: Write the failing tests**

Add to `test/utils/media_overlay_test.dart`, inside `main()`:

```dart
  group('mediaOverlayScript', () {
    final script = mediaOverlayScript(viewLabel: 'View', saveLabel: 'Save');

    test('posts to the agreed channel', () {
      expect(script, contains(kMediaChannelName));
    });

    test('sends the agreed action names', () {
      expect(script, contains(MediaAction.view.name));
      expect(script, contains(MediaAction.save.name));
    });

    test('embeds the labels it was given', () {
      expect(script, contains('View'));
      expect(script, contains('Save'));
    });

    test('skips images too small to be content', () {
      // Avatars and reaction icons are <img> too; decorating them would put a
      // button over every face in the feed.
      expect(script, contains('$kMinMediaEdge'));
    });

    test('marks decorated nodes so the interval does not re-decorate them', () {
      expect(script, contains('slim-media-done'));
    });

    test('re-checks periodically because images grow after layout', () {
      expect(script, contains('setInterval'));
    });

    test('is idempotent across repeated injection', () {
      expect(script, contains('if (window.slimMediaTimer) return;'));
    });

    test('never posts a blob or data url', () {
      // An <img> can carry either, and neither survives outside the page.
      expect(script, contains("indexOf('blob:')"));
      expect(script, contains("indexOf('data:')"));
    });

    test('touches no video element', () {
      // Video is deliberately out of scope: MSE sources are blob: URLs.
      expect(script, isNot(contains('video')));
    });

    test('stops the tap from following the photo permalink', () {
      expect(script, contains('preventDefault'));
      expect(script, contains('stopPropagation'));
    });

    test('has balanced delimiters', () {
      // Not a parser, but it catches the typo that `contains` assertions sail
      // straight past. There is no JS engine in `flutter test`, so this plus
      // the manual pass in Task 7 is the whole safety net.
      for (final pair in const [
        ['(', ')'],
        ['{', '}'],
        ['[', ']'],
      ]) {
        expect(
          script.split(pair[0]).length,
          script.split(pair[1]).length,
          reason: 'unbalanced ${pair[0]}${pair[1]}',
        );
      }
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
fvm flutter test test/utils/media_overlay_test.dart
```

Expected: compile failure — `mediaOverlayScript` and `kMinMediaEdge` are not defined.

- [ ] **Step 3: Add the generator**

Append to `lib/utils/media_overlay.dart`:

```dart
/// Smallest edge, in CSS pixels, an image must have before it gets buttons.
///
/// Avatars, reaction icons and emoji are all `<img>`; without a floor the feed
/// ends up with a button over every face.
const int kMinMediaEdge = 200;

/// Builds the script that puts view/save buttons on feed photos.
///
/// Runs on an interval rather than a MutationObserver: Facebook swaps in a
/// full-resolution source after layout, so an image that measured 40px when it
/// was first seen can be 400px a tick later, and a mutation-driven pass would
/// have already dismissed it.
///
/// Only `<img>` is scanned. Video is out of scope — its sources are `blob:`
/// URLs from Media Source Extensions, which cannot be downloaded.
String mediaOverlayScript({
  required String viewLabel,
  required String saveLabel,
}) {
  return '''
(function () {
  if (window.slimMediaTimer) return;

  var MIN_EDGE = $kMinMediaEdge;
  var VIEW_LABEL = ${jsonEncode(viewLabel)};
  var SAVE_LABEL = ${jsonEncode(saveLabel)};

  function post(action, url) {
    if (!url) return;
    if (url.indexOf('blob:') === 0) return;
    if (url.indexOf('data:') === 0) return;
    try {
      window.$kMediaChannelName.postMessage(JSON.stringify({
        action: action,
        url: url
      }));
    } catch (e) {}
  }

  function button(label, onTap) {
    var el = document.createElement('button');
    el.type = 'button';
    el.className = 'slim-media-btn';
    el.textContent = label;
    el.addEventListener('click', function (event) {
      // The photo is usually wrapped in a link to its permalink; without this
      // the tap navigates the whole webview away from the feed.
      event.preventDefault();
      event.stopPropagation();
      onTap();
    }, true);
    return el;
  }

  function decorate(img, url) {
    img.classList.add('slim-media-done');

    var bar = document.createElement('div');
    bar.className = 'slim-media-bar';
    bar.appendChild(button(VIEW_LABEL, function () {
      post('${MediaAction.view.name}', url);
    }));
    bar.appendChild(button(SAVE_LABEL, function () {
      post('${MediaAction.save.name}', url);
    }));

    // The bar is absolutely positioned, so it needs a positioned ancestor. Use
    // the one that already wraps the image rather than restyling the post.
    var host = img.parentElement || img;
    if (getComputedStyle(host).position === 'static') {
      host.classList.add('slim-media-host');
    }
    host.appendChild(bar);
  }

  function scan() {
    try {
      var images = document.querySelectorAll('img:not(.slim-media-done)');
      for (var i = 0; i < images.length; i++) {
        var img = images[i];
        // naturalWidth is the source's own size, clientWidth the rendered one.
        // Both must clear the floor: a big source scaled down to an avatar is
        // still an avatar.
        if (img.naturalWidth < MIN_EDGE || img.naturalHeight < MIN_EDGE) continue;
        if (img.clientWidth < MIN_EDGE || img.clientHeight < MIN_EDGE) continue;
        decorate(img, img.currentSrc || img.src);
      }
    } catch (e) {}
  }

  window.slimMediaTimer = setInterval(scan, 1000);
  scan();
})();
''';
}
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
fvm flutter test test/utils/media_overlay_test.dart
```

Expected: all tests pass.

If `has balanced delimiters` fails there is a genuine typo in the generated JavaScript — fix it before moving on, because nothing downstream will catch it.

- [ ] **Step 5: Commit**

```bash
git add SlimSocial_for_Facebook/lib/utils/media_overlay.dart SlimSocial_for_Facebook/test/utils/media_overlay_test.dart
git commit -m "feat: generate the in-page photo overlay script"
```

---

## Task 3: Overlay styling

The buttons need to sit over the photo without the page's own styles swallowing them, and without the overlay blocking a scroll gesture.

**Files:**
- Modify: `SlimSocial_for_Facebook/lib/utils/css.dart`
- Modify: `SlimSocial_for_Facebook/test/utils/css_test.dart`

- [ ] **Step 1: Write the failing tests**

Add to `test/utils/css_test.dart`, inside `main()`:

```dart
  group('media overlay styling', () {
    test('exists and targets the overlay classes', () {
      expect(CustomCss.mediaOverlayCss.key, 'media_overlay_style');
      expect(CustomCss.mediaOverlayCss.code, contains('.slim-media-bar'));
      expect(CustomCss.mediaOverlayCss.code, contains('.slim-media-btn'));
      expect(CustomCss.mediaOverlayCss.code, contains('.slim-media-host'));
    });

    test('lets touches through the bar but not the buttons', () {
      // A bar that swallowed gestures would break scrolling over every photo.
      expect(CustomCss.mediaOverlayCss.code, contains('pointer-events: none'));
      expect(CustomCss.mediaOverlayCss.code, contains('pointer-events: auto'));
    });

    test('uses the theme accent placeholder rather than a fixed colour', () {
      expect(CustomCss.mediaOverlayCss.code, contains('{accent}'));
    });

    test('is not offered as a user-facing toggle', () {
      final keys = CustomCss.cssList.map((c) => c.key);

      expect(keys, isNot(contains('media_overlay_style')));
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
fvm flutter test test/utils/css_test.dart
```

Expected: compile failure — `CustomCss.mediaOverlayCss` is not defined.

- [ ] **Step 3: Add the stylesheet**

In `lib/utils/css.dart`, add to the `CustomCss` class:

```dart
  /// Styles the view/save buttons the photo overlay injects.
  ///
  /// The bar itself is `pointer-events: none` so a swipe that starts on a photo
  /// still scrolls the feed; only the buttons take input.
  ///
  /// Not in [cssList]: that list drives the settings toggles, and this is
  /// structural rather than a preference.
  static MyCss mediaOverlayCss = MyCss(
    key: 'media_overlay_style',
    description: 'Photo overlay buttons',
    defaultEnabled: true,
    code: '.slim-media-host { position: relative !important; } '
        '.slim-media-bar { position: absolute; right: 8px; bottom: 8px; '
        'display: flex; gap: 6px; z-index: 9999; pointer-events: none; } '
        '.slim-media-btn { pointer-events: auto; border: none; '
        'border-radius: 16px; padding: 6px 12px; font-size: 12px; '
        'font-weight: 600; color: #fff; background: {accent}; '
        'box-shadow: 0 1px 4px rgba(0, 0, 0, 0.4); '
        '-webkit-tap-highlight-color: rgba(0, 0, 0, 0); } '
        '.slim-media-btn:active { opacity: 0.7; }',
  );
```

`{accent}` is resolved by `resolveCssPlaceholders` from the injection-overhaul plan's Task 8. If that has not landed, the buttons render with a literal `{accent}` and no background — land it first.

- [ ] **Step 4: Run the tests to verify they pass**

```bash
fvm flutter test test/utils/css_test.dart
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add SlimSocial_for_Facebook/lib/utils/css.dart SlimSocial_for_Facebook/test/utils/css_test.dart
git commit -m "feat: style the injected photo overlay buttons"
```

---

## Task 4: Download and save

`downloadImage` in `utils.dart` puts the file wherever `flutter_file_downloader` defaults to and reports errors by toast. Generalise it: an explicit result so callers can react, a derived filename, and no toast inside the helper so it stays testable.

**Files:**
- Create: `SlimSocial_for_Facebook/lib/utils/media_download.dart`
- Create: `SlimSocial_for_Facebook/test/utils/media_download_test.dart`
- Modify: `SlimSocial_for_Facebook/lib/utils/utils.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/utils/media_download_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:slimsocial_for_facebook/utils/media_download.dart';

void main() {
  group('mediaFileName', () {
    test('keeps a sensible name from the path', () {
      expect(
        mediaFileName('https://scontent.example/v/t1/photo_123.jpg'),
        'photo_123.jpg',
      );
    });

    test('drops the query string', () {
      // Facebook CDN URLs carry a long signed query that would otherwise end
      // up in the filename.
      expect(
        mediaFileName('https://scontent.example/a.jpg?oh=1&oe=2&_nc_sid=x'),
        'a.jpg',
      );
    });

    test('falls back to a fixed name when the path is bare', () {
      expect(mediaFileName('https://scontent.example/'), 'slimsocial');
      expect(mediaFileName('https://scontent.example'), 'slimsocial');
    });

    test('strips path separators so the name cannot escape the directory', () {
      expect(mediaFileName('https://x.example/a/../../etc/passwd'), 'passwd');
    });

    test('never returns an empty string', () {
      for (final url in const [
        'https://x.example',
        'https://x.example/',
        'https://x.example/?a=1',
        'not a url at all',
        '',
      ]) {
        expect(mediaFileName(url), isNotEmpty, reason: url);
      }
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
fvm flutter test test/utils/media_download_test.dart
```

Expected: `Error: Couldn't resolve the package 'slimsocial_for_facebook/utils/media_download.dart'`.

- [ ] **Step 3: Create the helper**

Create `lib/utils/media_download.dart`:

```dart
import 'package:flutter_file_downloader/flutter_file_downloader.dart';

/// Derives a filename from [url].
///
/// Facebook CDN URLs carry a long signed query string; keeping it would produce
/// unusable filenames. Path separators are stripped so a crafted URL cannot
/// write outside the download directory.
String mediaFileName(String url) {
  final uri = Uri.tryParse(url);
  final segments = uri?.pathSegments.where((s) => s.isNotEmpty).toList() ?? [];

  final last = segments.isEmpty ? '' : segments.last;
  final cleaned = last.replaceAll(RegExp(r'[/\\]'), '').trim();

  if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') return 'slimsocial';

  return cleaned;
}

/// Outcome of a download attempt.
///
/// Returned rather than toasted so the caller decides what the user sees and
/// the helper stays testable.
class MediaDownloadResult {
  const MediaDownloadResult.success(this.path)
      : failed = false,
        error = null;

  const MediaDownloadResult.failure(this.error)
      : failed = true,
        path = null;

  final String? path;
  final bool failed;
  final String? error;
}

/// Downloads [url] to the device.
Future<MediaDownloadResult> downloadMedia(String url) async {
  String? failure;

  final file = await FileDownloader.downloadFile(
    url: url,
    name: mediaFileName(url),
    onDownloadError: (String? error) => failure = error,
  );

  if (file == null) return MediaDownloadResult.failure(failure);

  return MediaDownloadResult.success(file.path);
}
```

- [ ] **Step 4: Point the old helper at the new one**

In `lib/utils/utils.dart`, replace `downloadImage` with:

```dart
/// Kept for the existing `isScontentUrl` buttons in the app bar.
Future<String?> downloadImage(String url) async {
  final result = await downloadMedia(url);
  if (result.failed) {
    showToast("error_trylater".tr());
    return null;
  }
  return result.path;
}
```

Add the import, keeping the block alphabetically ordered — `very_good_analysis` enforces `directives_ordering`:

```dart
import 'package:slimsocial_for_facebook/utils/media_download.dart';
```

Remove the now-unused `flutter_file_downloader` import from `utils.dart` if the analyzer flags it.

- [ ] **Step 5: Run the tests to verify they pass**

```bash
fvm flutter test test/utils/media_download_test.dart
```

Expected: all tests pass.

- [ ] **Step 6: Verify nothing else broke**

```bash
fvm flutter analyze lib/ test/ && fvm flutter test
```

Expected: `No issues found!` then all tests pass.

- [ ] **Step 7: Commit**

```bash
git add SlimSocial_for_Facebook/lib/utils/media_download.dart SlimSocial_for_Facebook/lib/utils/utils.dart SlimSocial_for_Facebook/test/utils/media_download_test.dart
git commit -m "feat: add a shared media download helper"
```

---

## Task 5: The full-screen photo viewer

A Flutter route showing one photo, pinch-zoomable, with save and share.

**Files:**
- Create: `SlimSocial_for_Facebook/lib/screens/media_viewer_page.dart`
- Modify: `SlimSocial_for_Facebook/assets/lang/en-US.json`

- [ ] **Step 1: Add the strings**

In `assets/lang/en-US.json`, add:

```json
  "media_view": "View",
  "media_save": "Save",
  "media_saved": "Saved"
```

`downloading`, `sharing` and `error_trylater` already exist and are reused.

- [ ] **Step 2: Create the viewer**

Create `lib/screens/media_viewer_page.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:slimsocial_for_facebook/utils/media_download.dart';
import 'package:slimsocial_for_facebook/utils/utils.dart';

/// Full-screen viewer for a single photo.
///
/// Deliberately not a gallery: the overlay reports one image at a time, and
/// pairing a tapped `<img>` with the rest of its album would mean reasoning
/// about Facebook's DOM structure, which changes without warning.
class MediaViewerPage extends StatelessWidget {
  const MediaViewerPage({required this.url, super.key});

  final String url;

  Future<void> _save() async {
    showToast("${"downloading".tr()}...");
    final result = await downloadMedia(url);

    if (result.failed || result.path == null) {
      showToast("error_trylater".tr());
      return;
    }
    showToast("media_saved".tr());
    await OpenFile.open(result.path);
  }

  Future<void> _share() async {
    showToast("${"sharing".tr()}...");
    final result = await downloadMedia(url);

    if (result.failed || result.path == null) {
      showToast("error_trylater".tr());
      return;
    }
    await Share.shareXFiles([XFile(result.path!)]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _save,
            icon: const Icon(Icons.save_alt),
          ),
          IconButton(
            onPressed: _share,
            icon: const Icon(Icons.ios_share_outlined),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 6,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const CircularProgressIndicator();
            },
            errorBuilder: (context, error, stack) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Verify it compiles**

```bash
fvm flutter analyze lib/screens/media_viewer_page.dart
```

Expected: `No issues found!`

- [ ] **Step 4: Run the suite**

```bash
fvm flutter test
```

Expected: all tests pass — this task adds no tests, and must break none.

- [ ] **Step 5: Commit**

```bash
git add SlimSocial_for_Facebook/lib/screens/media_viewer_page.dart SlimSocial_for_Facebook/assets/lang/en-US.json
git commit -m "feat: add a full-screen photo viewer"
```

---

## Task 6: Wire it into the feed

Register the channel, inject the overlay, and route messages.

**Files:**
- Modify: `SlimSocial_for_Facebook/lib/screens/home_page.dart`

- [ ] **Step 1: Register the channel**

In `lib/screens/home_page.dart`, in `_initWebViewController`, add to the cascade immediately after `setNavigationDelegate(...)` and before `loadRequest`:

```dart
      ..addJavaScriptChannel(
        kMediaChannelName,
        onMessageReceived: _onMediaMessage,
      )
```

- [ ] **Step 2: Inject the overlay**

Still in `home_page.dart`, extend `runJs` so the overlay is installed once the page has settled. Add this immediately before the `userCustomJs` block:

```dart
    await _controller.runJavaScript(
      mediaOverlayScript(
        viewLabel: 'media_view'.tr(),
        saveLabel: 'media_save'.tr(),
      ),
    );
```

- [ ] **Step 3: Handle the messages**

Add these two methods to `_HomePageState`:

```dart
  /// Routes a request from the injected photo overlay.
  ///
  /// The payload is page-supplied, so it is parsed defensively and a malformed
  /// message is dropped rather than trusted.
  void _onMediaMessage(JavaScriptMessage message) {
    final request = MediaRequest.fromJson(message.message);
    if (request == null) {
      debugPrint('ignored media message: ${message.message}');
      return;
    }
    unawaited(_handleMediaRequest(request));
  }

  Future<void> _handleMediaRequest(MediaRequest request) async {
    switch (request.action) {
      case MediaAction.view:
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => MediaViewerPage(url: request.url),
          ),
        );
      case MediaAction.save:
        showToast("${"downloading".tr()}...");
        final result = await downloadMedia(request.url);
        if (result.failed || result.path == null) {
          showToast("error_trylater".tr());
          return;
        }
        showToast("media_saved".tr());
    }
  }
```

`unawaited` needs `import 'dart:async';`, which `home_page.dart` already has.

Add the remaining imports, keeping the block alphabetically ordered:

```dart
import 'package:slimsocial_for_facebook/screens/media_viewer_page.dart';
import 'package:slimsocial_for_facebook/utils/media_download.dart';
import 'package:slimsocial_for_facebook/utils/media_overlay.dart';
```

- [ ] **Step 4: Inject the overlay stylesheet**

In `injectCss`, add an entry to the `sheets` map:

```dart
      'slim-media-overlay': CustomCss.mediaOverlayCss.code,
```

- [ ] **Step 5: Verify**

```bash
fvm flutter analyze lib/ test/ && fvm flutter test
```

Expected: `No issues found!` then all tests pass.

If the analyzer reports `use_build_context_synchronously` on the `Navigator.of(context)` call, the `if (!mounted) return;` guard above it is missing — add it.

- [ ] **Step 6: Commit**

```bash
git add SlimSocial_for_Facebook/lib/screens/home_page.dart
git commit -m "feat: wire the photo overlay into the feed webview"
```

---

## Task 7: Manual verification on a device

The overlay is injected JavaScript with no Dart-side runtime, so behaviour has to be confirmed in the app.

**Files:** none — this task only runs and observes.

- [ ] **Step 1: Launch**

```bash
fvm flutter run --debug
```

- [ ] **Step 2: Confirm buttons appear on photos and nowhere else**

Scroll to a post with a photo.

Expected: **View** and **Save** appear over the photo, and no buttons appear on avatars, reaction icons or emoji. Attach via `chrome://inspect` and run in the WebView console:

```js
[document.querySelectorAll('.slim-media-btn').length,
 document.querySelectorAll('img.slim-media-done').length,
 document.querySelectorAll('img').length]
```

The first two greater than zero, and the second far smaller than the third. If the second is close to the third, the size floor is not working.

- [ ] **Step 3: Confirm scrolling still works over a photo**

Start a swipe with your finger on a photo and drag.

Expected: the feed scrolls. If it does not, `pointer-events: none` on `.slim-media-bar` is not applying.

- [ ] **Step 4: Confirm View opens the viewer, not Facebook**

Tap **View**.

Expected: a black full-screen Flutter route with the photo; pinch-zoom works; the webview behind it has **not** navigated. Go back.

Expected: the feed is exactly where it was, same scroll position. This is the whole point of the plan — if the feed jumped or reloaded, the tap leaked through to the permalink link and `preventDefault` is not firing.

- [ ] **Step 5: Confirm Save works from the feed**

Tap **Save** on a photo.

Expected: a "downloading" toast, then "Saved". Check the file lands in the gallery or Downloads, opens, and is named after the photo rather than carrying a query string.

- [ ] **Step 6: Confirm no duplicate buttons**

Scroll down several screens and back up, then:

```js
[document.querySelectorAll('.slim-media-bar').length,
 document.querySelectorAll('img.slim-media-done').length]
```

Expected: roughly equal, not a multiple. A multiple means the processed marker is not holding and the interval is re-decorating.

- [ ] **Step 7: Confirm video is untouched**

Play a video in the feed, then tap Facebook's own full-screen control.

Expected: it plays, no overlay buttons appear on it, and full-screen still opens the Flutter route. Video is out of scope for this plan, so "no button on video" is the correct outcome, not a bug.

- [ ] **Step 8: Confirm the fallback path still works**

Navigate the webview to a bare image so the URL host contains `scontent`.

Expected: the app-bar Download and Share buttons still appear and work. This plan did not remove them.

- [ ] **Step 9: Confirm a malformed message is ignored**

In the WebView console:

```js
window.SlimMedia.postMessage('{"action":"view","url":"javascript:alert(1)"}');
window.SlimMedia.postMessage('{"action":"save","url":"blob:https://x/y"}');
window.SlimMedia.postMessage('garbage');
```

Expected: nothing happens, and the Flutter log shows `ignored media message:` three times. No navigation, no download, no crash.

---

## Self-Review

**Requested scope coverage.** Photos full-screen → Tasks 2, 5, 6. Photos download → Tasks 2, 4, 6. Video full-screen → already working, confirmed unbroken in Task 7 Step 7, no code. Video download → excluded by decision, stated at the top and re-stated in Tasks 2 and 7. Hiding stories and reels is **not** here — those are CSS toggles and live in Task 9 of the injection-overhaul plan.

**Names used consistently.** `kMediaChannelName` is defined in Task 1 and used in Tasks 2 and 6. `MediaAction` and `MediaRequest.fromJson` are defined in Task 1 and used in Tasks 2 and 6. `kMinMediaEdge` is defined in Task 2 and asserted in Task 2's tests. `mediaOverlayScript({viewLabel, saveLabel})` keeps that signature in Tasks 2 and 6. `downloadMedia`, `MediaDownloadResult` and `mediaFileName` are defined in Task 4 and used in Tasks 4, 5 and 6. `MediaViewerPage({required url})` is defined in Task 5 and used in Task 6. The CSS classes `slim-media-bar`, `slim-media-btn`, `slim-media-host` and `slim-media-done` match between Task 2's script and Task 3's stylesheet.

**Every task commits green.** Task 1 is self-contained. Task 2 depends only on Task 1. Task 3 depends only on `MyCss`. Task 4 is self-contained. Task 5 depends on Task 4. Task 6 depends on 1–5. No task references a symbol a later task creates.

**Known limitation, stated rather than hidden.** The overlay script is verified by string assertions plus a delimiter-balance check; there is no JavaScript engine in `flutter test`. Task 7 is the real behavioural gate, and the plan does not claim otherwise.

**External dependency.** Task 3's `{accent}` needs `resolveCssPlaceholders` from the injection-overhaul plan's Task 8. Called out inline.

---

## Follow-up work (separate plans)

1. **Album gallery.** Swipe between the photos of one post. Needs a reliable way to enumerate an album from the DOM, which is the fragile part.
2. **Long-press instead of buttons.** Less visual clutter than a permanent overlay, at the cost of discoverability. Worth testing against the button version once both exist.
3. **Save location setting.** Let the user choose the download directory rather than accepting the downloader's default.
4. **Video download.** Only viable via request interception, which needs a WebView plugin that exposes it. Revisit only if that dependency is worth taking on.
