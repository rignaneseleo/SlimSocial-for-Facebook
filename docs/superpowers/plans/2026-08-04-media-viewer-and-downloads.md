# Media Viewer and Downloads — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user open any photo in the feed full-screen and save it, without leaving the app — and save videos where the page exposes a real video URL.

**Architecture:** A small injected script decorates every sufficiently large image and every video container with two overlay buttons. Tapping one posts a JSON message over a `JavaScriptChannel` to Dart, which either pushes a Flutter full-screen viewer route or runs the existing download helper. No page navigation is involved, so the feed keeps its scroll position and the webview is never sent to a raw CDN URL. Video download is attempted only where the DOM exposes a plain URL; where Facebook uses MSE with `blob:` sources there is nothing to download and the button is not offered.

**Tech Stack:** Flutter 3.44.8 via fvm, Dart, `webview_flutter` 4.10.0, `flutter_file_downloader`, `share_plus`, `open_file_plus`, `permission_handler`, `flutter_test`.

**Every command below runs from `SlimSocial_for_Facebook/`** and is prefixed with `fvm`.

**Depends on:** `2026-08-04-webview-injection-overhaul.md`. That plan fixes `injectCssFunc` (stable ids, `textContent`, `<head>`), adds `CustomJs.whenDomReady`, and — critically — its Task 1 Step 5 records which markup Facebook actually serves. This plan's selectors are chosen from that recording. Do not start before it exists.

---

## What already works, and what does not

| Capability | Today |
|---|---|
| Video full-screen | **Works.** `setCustomWidgetCallbacks` at `home_page.dart:85` hands Facebook's own full-screen widget to a Flutter route. Nothing to build. |
| Photo full-screen | Missing. Tapping a photo navigates the whole webview, and `fbcdn.net` is not in `kPermittedHostnamesFb`, so some taps leave the app for the system browser. |
| Photo download | Only after the webview has already navigated to a `scontent.*` URL, via the `isScontentUrl` buttons in the app bar. Not available from the feed. |
| Video download | Missing. |
| Sharing a downloaded file | Works, same `isScontentUrl` path. |

So this plan builds: an in-page affordance, a channel, a viewer, and a generalised download helper. It deliberately leaves the existing `isScontentUrl` buttons in place — they are the fallback for the case where the user has already navigated to a bare image.

**Honest scope note on video.** On the legacy mobile layout Facebook exposes `data-video-url` / `data-store` attributes holding a plain `.mp4`. On the current layout video is delivered through Media Source Extensions and `<video>.src` is a `blob:` URL that exists only inside the page — it cannot be handed to a downloader. Task 6 detects which case applies and only offers the button when a real URL exists. If the recon shows this app only ever gets MSE video, Task 6 reduces to "do not offer the button", and downloading video would need request interception, which is a separate plan.

---

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `lib/utils/media_overlay.dart` | Create | Generates the injected overlay script; defines the message contract |
| `lib/utils/media_download.dart` | Create | Download, save and share a media URL; permission handling |
| `lib/screens/media_viewer_page.dart` | Create | Full-screen photo viewer route |
| `lib/utils/css.dart` | Modify | Overlay button styling |
| `lib/screens/home_page.dart` | Modify | Register the channel, inject the overlay, route messages |
| `lib/utils/utils.dart` | Modify | `downloadImage` becomes a thin wrapper over the new helper |
| `assets/lang/en-US.json` | Modify | New strings |
| `test/utils/media_overlay_test.dart` | Create | Message contract + generated-script tests |
| `test/utils/media_download_test.dart` | Create | URL validation tests |

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
    test('parses a photo view request', () {
      final request = MediaRequest.fromJson(
        jsonEncode({
          'action': 'view',
          'kind': 'photo',
          'url': 'https://scontent.example/a.jpg',
        }),
      );

      expect(request, isNotNull);
      expect(request!.action, MediaAction.view);
      expect(request.kind, MediaKind.photo);
      expect(request.url, 'https://scontent.example/a.jpg');
    });

    test('parses a video save request', () {
      final request = MediaRequest.fromJson(
        jsonEncode({
          'action': 'save',
          'kind': 'video',
          'url': 'https://video.example/a.mp4',
        }),
      );

      expect(request!.action, MediaAction.save);
      expect(request.kind, MediaKind.video);
    });

    test('returns null for a malformed payload', () {
      expect(MediaRequest.fromJson('not json'), isNull);
      expect(MediaRequest.fromJson('{}'), isNull);
      expect(MediaRequest.fromJson(jsonEncode({'action': 'view'})), isNull);
    });

    test('returns null for an unknown action or kind', () {
      expect(
        MediaRequest.fromJson(
          jsonEncode({'action': 'delete', 'kind': 'photo', 'url': 'https://a'}),
        ),
        isNull,
      );
      expect(
        MediaRequest.fromJson(
          jsonEncode({'action': 'view', 'kind': 'audio', 'url': 'https://a'}),
        ),
        isNull,
      );
    });

    test('rejects a url that is not http(s)', () {
      // The page can post anything it likes down this channel, so the scheme is
      // checked here rather than trusted.
      for (final url in const [
        'blob:https://facebook.com/abc',
        'javascript:alert(1)',
        'file:///etc/passwd',
        'data:text/html,<script>',
        '',
      ]) {
        expect(
          MediaRequest.fromJson(
            jsonEncode({'action': 'save', 'kind': 'photo', 'url': url}),
          ),
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

/// What they asked for it on.
enum MediaKind { photo, video }

/// A request posted by the injected overlay.
///
/// Anything can be posted down a JavaScript channel — the page's own scripts
/// included — so every field is validated here and a bad payload yields null
/// rather than a partly-populated object.
@immutable
class MediaRequest {
  const MediaRequest({
    required this.action,
    required this.kind,
    required this.url,
  });

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

    final action = _byName(MediaAction.values, decoded['action']);
    final kind = _byName(MediaKind.values, decoded['kind']);
    final url = decoded['url'];

    if (action == null || kind == null || url is! String) return null;

    // blob:, data:, javascript: and file: must never reach a downloader or an
    // Image widget.
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    if (uri.host.isEmpty) return null;

    return MediaRequest(action: action, kind: kind, url: url);
  }

  final MediaAction action;
  final MediaKind kind;
  final String url;

  static T? _byName<T extends Enum>(List<T> values, Object? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }
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

Decorate images with a view button and a save button. The script runs on an interval rather than a `MutationObserver` because it has to react to images *growing* — Facebook swaps in a full-resolution source after layout, and an image that was 40px when first seen may be 400px a moment later.

Two guards matter:

- **A size floor.** Avatars, reaction icons and emoji are all `<img>`. Decorating them would put buttons over every face in the feed. Only images at least 200px on both axes get buttons.
- **A processed marker.** Without one, the interval re-decorates the same image every tick.

**Files:**
- Modify: `SlimSocial_for_Facebook/lib/utils/media_overlay.dart`
- Modify: `SlimSocial_for_Facebook/test/utils/media_overlay_test.dart`

- [ ] **Step 1: Write the failing tests**

Add to `test/utils/media_overlay_test.dart`, inside `main()`:

```dart
  group('mediaOverlayScript', () {
    final script = mediaOverlayScript(
      viewLabel: 'View',
      saveLabel: 'Save',
      offerVideoDownload: true,
    );

    test('posts to the agreed channel', () {
      expect(script, contains(kMediaChannelName));
    });

    test('sends the agreed action and kind names', () {
      expect(script, contains(MediaAction.view.name));
      expect(script, contains(MediaAction.save.name));
      expect(script, contains(MediaKind.photo.name));
      expect(script, contains(MediaKind.video.name));
    });

    test('skips images too small to be content', () {
      // Avatars and reaction icons are <img> too; decorating them would put a
      // button over every face in the feed.
      expect(script, contains('200'));
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

    test('never posts a blob url', () {
      // MSE video has a blob: src that means nothing outside the page.
      expect(script, contains("indexOf('blob:')"));
    });

    test('omits the video button when video download is unavailable', () {
      final withoutVideo = mediaOverlayScript(
        viewLabel: 'View',
        saveLabel: 'Save',
        offerVideoDownload: false,
      );

      expect(withoutVideo, contains('OFFER_VIDEO = false'));
      expect(script, contains('OFFER_VIDEO = true'));
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

Expected: compile failure — `mediaOverlayScript` is not defined.

- [ ] **Step 3: Add the generator**

Append to `lib/utils/media_overlay.dart`:

```dart
/// Smallest edge, in CSS pixels, an image must have before it gets buttons.
///
/// Avatars, reaction icons and emoji are all `<img>`; without a floor the feed
/// ends up with a button over every face.
const int kMinMediaEdge = 200;

/// Builds the script that puts view/save buttons on feed media.
///
/// Runs on an interval rather than a MutationObserver: Facebook swaps in a
/// full-resolution source after layout, so an image that measured 40px when it
/// was first seen can be 400px a tick later, and a mutation-driven pass would
/// have already dismissed it.
///
/// [offerVideoDownload] should be false when the page delivers video through
/// Media Source Extensions, because then `<video>.src` is a `blob:` URL that
/// cannot be downloaded — see Task 6.
String mediaOverlayScript({
  required String viewLabel,
  required String saveLabel,
  required bool offerVideoDownload,
}) {
  return '''
(function () {
  if (window.slimMediaTimer) return;

  var MIN_EDGE = $kMinMediaEdge;
  var OFFER_VIDEO = $offerVideoDownload;
  var VIEW_LABEL = ${jsonEncode(viewLabel)};
  var SAVE_LABEL = ${jsonEncode(saveLabel)};

  function post(action, kind, url) {
    if (!url) return;
    if (url.indexOf('blob:') === 0) return;
    if (url.indexOf('data:') === 0) return;
    try {
      window.$kMediaChannelName.postMessage(JSON.stringify({
        action: action,
        kind: kind,
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
      // The whole image is usually inside a link to the photo permalink.
      event.preventDefault();
      event.stopPropagation();
      onTap();
    }, true);
    return el;
  }

  function decorate(node, kind, url) {
    node.classList.add('slim-media-done');

    var bar = document.createElement('div');
    bar.className = 'slim-media-bar';

    if (kind === '${MediaKind.photo.name}') {
      bar.appendChild(button(VIEW_LABEL, function () {
        post('${MediaAction.view.name}', kind, url);
      }));
    }
    bar.appendChild(button(SAVE_LABEL, function () {
      post('${MediaAction.save.name}', kind, url);
    }));

    // The bar is absolutely positioned, so it needs a positioned ancestor. Use
    // the closest one that already exists rather than restyling the post.
    var host = node.parentElement || node;
    if (getComputedStyle(host).position === 'static') {
      host.classList.add('slim-media-host');
    }
    host.appendChild(bar);
  }

  function scanImages() {
    var images = document.querySelectorAll('img:not(.slim-media-done)');
    for (var i = 0; i < images.length; i++) {
      var img = images[i];
      if (img.naturalWidth < MIN_EDGE || img.naturalHeight < MIN_EDGE) continue;
      if (img.clientWidth < MIN_EDGE || img.clientHeight < MIN_EDGE) continue;
      decorate(img, '${MediaKind.photo.name}', img.currentSrc || img.src);
    }
  }

  function videoUrl(video) {
    // A plain src is downloadable; a blob: from Media Source Extensions is not.
    var direct = video.currentSrc || video.src || '';
    if (direct && direct.indexOf('blob:') !== 0) return direct;

    var source = video.querySelector('source[src]');
    if (source && source.getAttribute('src').indexOf('blob:') !== 0) {
      return source.getAttribute('src');
    }

    // Legacy mobile markup hangs the real URL off an ancestor.
    var holder = video.closest('[data-video-url]');
    if (holder) return holder.getAttribute('data-video-url');

    return '';
  }

  function scanVideos() {
    if (!OFFER_VIDEO) return;
    var videos = document.querySelectorAll('video:not(.slim-media-done)');
    for (var i = 0; i < videos.length; i++) {
      var url = videoUrl(videos[i]);
      // Mark it either way: without this a blob-only video is re-examined on
      // every tick forever.
      videos[i].classList.add('slim-media-done');
      if (url) decorate(videos[i], '${MediaKind.video.name}', url);
    }
  }

  function scan() {
    try {
      scanImages();
      scanVideos();
    } catch (e) {}
  }

  window.slimMediaTimer = setInterval(scan, 1000);
  scan();
})();
''';
}
```

Add `import 'dart:convert';` if the analyzer reports it missing — Task 1 already added it.

- [ ] **Step 4: Run the tests to verify they pass**

```bash
fvm flutter test test/utils/media_overlay_test.dart
```

Expected: all tests pass.

If `has balanced delimiters` fails, there is a genuine typo in the generated JavaScript — fix it before moving on, because nothing downstream will catch it.

- [ ] **Step 5: Commit**

```bash
git add SlimSocial_for_Facebook/lib/utils/media_overlay.dart SlimSocial_for_Facebook/test/utils/media_overlay_test.dart
git commit -m "feat: generate the in-page media overlay script"
```

---

## Task 3: Overlay styling

The buttons need to sit over the media without the page's own styles swallowing them, and without the overlay itself blocking a scroll gesture.

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
  /// Styles the view/save buttons the media overlay injects.
  ///
  /// The bar itself is `pointer-events: none` so a swipe that starts on a photo
  /// still scrolls the feed; only the buttons take input.
  ///
  /// Not in [cssList]: that list drives the settings toggles, and this is
  /// structural.
  static MyCss mediaOverlayCss = MyCss(
    key: 'media_overlay_style',
    description: 'Media overlay buttons',
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

`{accent}` is resolved by `resolveCssPlaceholders`, added in Task 8 of the injection-overhaul plan. If that task has not landed, this stylesheet will render a literal `{accent}` and the buttons will be unstyled — land it first.

- [ ] **Step 4: Run the tests to verify they pass**

```bash
fvm flutter test test/utils/css_test.dart
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add SlimSocial_for_Facebook/lib/utils/css.dart SlimSocial_for_Facebook/test/utils/css_test.dart
git commit -m "feat: style the injected media overlay buttons"
```

---

## Task 4: Download and save

`downloadImage` in `utils.dart` puts the file wherever `flutter_file_downloader` defaults to and reports errors by toast. Generalise it: one helper for photos and videos, an explicit result so callers can react, and no toast inside the helper so it stays testable.

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
      expect(
        mediaFileName('https://scontent.example/a.jpg?oh=1&oe=2&_nc_sid=x'),
        'a.jpg',
      );
    });

    test('falls back to an extension-appropriate name when the path is bare', () {
      expect(mediaFileName('https://scontent.example/'), 'slimsocial');
    });

    test('strips path separators so the name cannot escape the directory', () {
      expect(mediaFileName('https://x.example/a/../../etc/passwd'), 'passwd');
    });

    test('does not return an empty string', () {
      for (final url in const [
        'https://x.example',
        'https://x.example/',
        'https://x.example/?a=1',
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

Add the import, keeping the block alphabetically ordered:

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

A Flutter route showing one image, pinch-zoomable, with save and share.

**Files:**
- Create: `SlimSocial_for_Facebook/lib/screens/media_viewer_page.dart`
- Modify: `SlimSocial_for_Facebook/assets/lang/en-US.json`

- [ ] **Step 1: Add the strings**

In `assets/lang/en-US.json`, add:

```json
  "media_view": "View",
  "media_save": "Save",
  "media_saved": "Saved",
  "media_no_video_url": "This video cannot be saved"
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

  Future<void> _save(BuildContext context) async {
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
            onPressed: () => _save(context),
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
            errorBuilder: (context, error, stack) => Icon(
              Icons.broken_image_outlined,
              color: Colors.white.withValues(alpha: 0.5),
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}
```

If the analyzer rejects `withValues`, the SDK predates it — use `Colors.white.withOpacity(0.5)`.

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

Register the channel, inject the overlay, and route messages. Whether the video button is offered at all is decided here.

**Files:**
- Modify: `SlimSocial_for_Facebook/lib/screens/home_page.dart`

- [ ] **Step 1: Decide whether video download is possible**

With the app running and attached via `chrome://inspect`, play a video in the feed, then run in the console:

```js
Array.from(document.querySelectorAll('video')).map(function (v) {
  return {
    currentSrc: (v.currentSrc || '').slice(0, 12),
    hasSourceTag: !!v.querySelector('source[src]'),
    ancestorUrl: !!v.closest('[data-video-url]'),
  };
})
```

- If `currentSrc` starts with `blob:` and both booleans are `false` on every entry, this layout uses Media Source Extensions and there is no URL to download. Set `offerVideoDownload: false` in Step 3, note the finding, and stop expecting video saves — that would need request interception, a separate plan.
- If any entry shows an `http` `currentSrc`, a `<source>` tag, or an ancestor `data-video-url`, set `offerVideoDownload: true`.

Record which case applies. Everything else in this task is the same either way.

- [ ] **Step 2: Register the channel**

In `lib/screens/home_page.dart`, in `_initWebViewController`, add to the cascade immediately after `setNavigationDelegate(...)` and before `loadRequest`:

```dart
      ..addJavaScriptChannel(
        kMediaChannelName,
        onMessageReceived: _onMediaMessage,
      )
```

- [ ] **Step 3: Inject the overlay**

Still in `home_page.dart`, extend `runJs` so the overlay is installed after the page settles. Add this immediately before the `userCustomJs` block:

```dart
    await _controller.runJavaScript(
      mediaOverlayScript(
        viewLabel: 'media_view'.tr(),
        saveLabel: 'media_save'.tr(),
        // Set from the finding in Step 1.
        offerVideoDownload: false,
      ),
    );
```

- [ ] **Step 4: Handle the messages**

Add these two methods to `_HomePageState`:

```dart
  /// Routes a request from the injected media overlay.
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

- [ ] **Step 5: Inject the overlay stylesheet**

In `injectCss`, add an entry to the `sheets` map:

```dart
      'slim-media-overlay': CustomCss.mediaOverlayCss.code,
```

- [ ] **Step 6: Verify**

```bash
fvm flutter analyze lib/ test/ && fvm flutter test
```

Expected: `No issues found!` then all tests pass.

If the analyzer reports `use_build_context_synchronously` on the `Navigator.of(context)` call, the `if (!mounted) return;` guard above it is missing — add it.

- [ ] **Step 7: Commit**

```bash
git add SlimSocial_for_Facebook/lib/screens/home_page.dart
git commit -m "feat: wire the media overlay into the feed webview"
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

Expected: **View** and **Save** appear over the photo. No buttons on avatars, reaction icons or emoji. In the WebView console:

```js
[document.querySelectorAll('.slim-media-btn').length,
 document.querySelectorAll('img.slim-media-done').length]
```

Both greater than zero, and the second should be far smaller than `document.querySelectorAll('img').length`. If it is close to the total, the size floor is not working.

- [ ] **Step 3: Confirm scrolling still works over a photo**

Start a swipe with your finger on a photo and drag.

Expected: the feed scrolls. If it does not, `pointer-events: none` on `.slim-media-bar` is not applying.

- [ ] **Step 4: Confirm View opens the viewer, not Facebook**

Tap **View**.

Expected: a black full-screen Flutter route with the photo, pinch-zoom works, and the webview behind it has **not** navigated. Go back.

Expected: the feed is exactly where it was, same scroll position.

- [ ] **Step 5: Confirm Save works from the feed**

Tap **Save** on a photo.

Expected: a "downloading" toast, then "Saved". Check the file is in the gallery or Downloads and opens.

- [ ] **Step 6: Confirm no duplicate buttons**

Scroll down several screens and back up.

```js
document.querySelectorAll('.slim-media-bar').length
```

Compare with `document.querySelectorAll('img.slim-media-done').length`. Expected: roughly equal, not a multiple. A multiple means the processed marker is not holding and the interval is re-decorating.

- [ ] **Step 7: Confirm the video decision from Task 6 Step 1**

Play a video.

Expected: if `offerVideoDownload` was set `true`, a **Save** button appears and saves a playable file. If it was set `false`, no button appears on videos — and that is correct, not a bug.

Either way, confirm Facebook's own full-screen button still opens the Flutter full-screen route, since that path is untouched by this plan.

- [ ] **Step 8: Confirm the fallback path still works**

Navigate the webview to a bare image so the URL host contains `scontent`.

Expected: the app-bar Download and Share buttons still appear and work. This plan did not remove them.

- [ ] **Step 9: Confirm a malformed message is ignored**

In the WebView console:

```js
window.SlimMedia.postMessage('{"action":"view","kind":"photo","url":"javascript:alert(1)"}');
window.SlimMedia.postMessage('garbage');
```

Expected: nothing happens, and the Flutter log shows `ignored media message:` twice. No navigation, no crash.

---

## Self-Review

**Requested scope coverage.** Photos full-screen → Tasks 2, 5, 6. Photos download → Tasks 2, 4, 6. Videos full-screen → already working, confirmed in Task 7 Step 7, no code. Videos download → Task 6 Step 1 decides feasibility, Task 2 supplies the URL extraction, Task 4 the download. Hiding stories and reels is **not** here — those are CSS toggles and live in Task 9 of the injection-overhaul plan.

**Names used consistently.** `kMediaChannelName` is defined in Task 1 and used in Tasks 2 and 6. `MediaAction` / `MediaKind` / `MediaRequest.fromJson` are defined in Task 1 and used in Tasks 2 and 6. `mediaOverlayScript({viewLabel, saveLabel, offerVideoDownload})` keeps that signature in Tasks 2 and 6. `downloadMedia` / `MediaDownloadResult` / `mediaFileName` are defined in Task 4 and used in Tasks 4, 5 and 6. `MediaViewerPage({required url})` is defined in Task 5 and used in Task 6. The CSS classes `slim-media-bar`, `slim-media-btn`, `slim-media-host` and `slim-media-done` match between Task 2's script and Task 3's stylesheet.

**Every task commits green.** Task 1 is self-contained. Task 2 depends only on Task 1. Task 3 depends only on `MyCss`. Task 4 is self-contained. Task 5 depends on Task 4. Task 6 depends on 1–5. No task references a symbol a later task creates.

**Known limitation, stated rather than hidden.** The overlay script is verified by string assertions plus a delimiter-balance check; there is no JavaScript engine in `flutter test`. Task 7 is the real behavioural gate, and the plan does not claim otherwise.

**External dependency.** Task 3's `{accent}` needs `resolveCssPlaceholders` from the injection-overhaul plan's Task 8. Called out inline.

---

## Follow-up work (separate plans)

1. **Video download via request interception.** Only worth doing if Task 6 Step 1 finds MSE-only video. Needs a request-inspecting WebView, which `webview_flutter` does not offer.
2. **Album gallery.** Swipe between the photos of one post. Needs a reliable way to enumerate an album from the DOM, which is the fragile part.
3. **Long-press instead of buttons.** Less visual clutter than a permanent overlay, at the cost of discoverability. Worth testing against the button version once both exist.
4. **Save location setting.** Let the user choose the download directory rather than accepting the downloader's default.
