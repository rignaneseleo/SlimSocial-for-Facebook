import 'dart:convert';

import 'package:slimsocial_for_facebook/utils/ad_filter.dart';

class CustomJs {
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

  /// Builds JavaScript that hands pinch-to-zoom back to the reader.
  ///
  /// Facebook ships `width=device-width, initial-scale=1, maximum-scale=1,
  /// user-scalable=no` as its viewport, and those last two clauses are exactly
  /// what the browser reads as "this page does not zoom". The text-zoom setting
  /// is no substitute: it reflows text and leaves an image, a screenshot
  /// somebody posted, or a fixed-width table at whatever size it arrived in.
  ///
  /// Only the clauses that block the gesture are dropped. `minimum-scale` goes
  /// with them because a `minimum-scale=1` is what stops the page being pinched
  /// back out again. Every clause we do not recognise is copied through in
  /// place: replacing the whole content string would take `width=device-width`
  /// with it, and the page would come back laid out for a 980px desktop.
  ///
  /// The rewrite cannot be a one-shot. Metas are queried as a list because an
  /// in-page navigation can leave a second viewport tag behind, and the
  /// observer is there because that same navigation can replace the tag after
  /// this script has already finished — the one we fixed is gone, and its
  /// replacement carries `user-scalable=no` again.
  ///
  /// Everything is swallowed by a try/catch: on iOS a page exception comes back
  /// through `runJavaScript`, and a throw here would take the injection steps
  /// queued behind it down as well.
  ///
  /// This only lifts the lock the page puts on itself. The WebView has to allow
  /// the gesture too (`enableZoom`), or none of this reaches the user.
  static String unlockZoomFunc() {
    return """
(function () {
  try {
    var MARK = 'data-slim-zoom';

    function unlockedContent(content) {
      var out = [];
      var sawUserScalable = false;
      var clauses = content.split(',');
      for (var i = 0; i < clauses.length; i++) {
        var clause = clauses[i].trim();
        if (!clause) continue;
        var key = clause.split('=')[0].trim().toLowerCase();
        if (key === 'maximum-scale' || key === 'minimum-scale') continue;
        if (key === 'user-scalable') {
          // Rewritten where it stands rather than dropped and re-appended, so
          // a viewport that spells out its own order keeps it.
          out.push('user-scalable=yes');
          sawUserScalable = true;
          continue;
        }
        out.push(clause);
      }
      if (!sawUserScalable) out.push('user-scalable=yes');
      return out.join(', ');
    }

    function unlockAll() {
      var metas = document.querySelectorAll('meta[name="viewport"]');
      for (var i = 0; i < metas.length; i++) {
        var meta = metas[i];
        // Same guard as the stylesheet injection: this runs on every
        // navigation, and Facebook navigates in-page constantly.
        if (meta.getAttribute(MARK) === '1') continue;
        var current = meta.getAttribute('content') || '';
        var next = unlockedContent(current);
        meta.setAttribute(MARK, '1');
        // Assigning an identical value still produces a mutation record, and
        // the observer below clears the mark before it re-runs: writing
        // unconditionally is an endless ping-pong between the two.
        if (next !== current) meta.setAttribute('content', next);
      }
    }

    unlockAll();

    // Kept on `window` for the same reason as the ad observer: a fresh
    // injection cannot otherwise tell that one is already watching, and every
    // page load would leave another observer behind on the same head.
    if (!window.slimViewportObserver) {
      window.slimViewportObserver = new MutationObserver(function (records) {
        for (var i = 0; i < records.length; i++) {
          // A `content` that has been written again can put maximum-scale
          // back, so the mark from the previous pass has to go or the tag is
          // skipped for the rest of the page's life.
          if (records[i].type === 'attributes') {
            records[i].target.removeAttribute(MARK);
          }
        }
        unlockAll();
      });

      // `document.head` is still null while the head is being parsed, and
      // injection starts from onPageStarted; documentElement exists from the
      // first byte and its subtree covers the head once it arrives.
      window.slimViewportObserver.observe(
        document.head || document.documentElement,
        {
          childList: true,
          subtree: true,
          attributes: true,
          attributeFilter: ['content']
        }
      );
    }
  } catch (e) {}
})();
""";
  }

  /// Builds JavaScript that hides the "Open app" bar Facebook pins to the
  /// bottom of the feed — and nothing else that docks there.
  ///
  /// This used to be a stylesheet rule: `div.fixed-container.bottom` without a
  /// form control inside it was `display: none`. The guard was written for the
  /// comment composer, which docks in the same container, and it was not
  /// enough. Facebook renders its share menu (#336), its reaction picker and
  /// its "turn on notifications" dialog (#339) in that container too. None of
  /// them holds a form control, so all of them vanished — leaving the dimmer
  /// they had opened over the page and nothing under it to tap. On the share
  /// menu that read as a dead share button; on the dialog it read as a feed
  /// that had gone dark and stopped scrolling.
  ///
  /// The stylesheet cannot ask the question that separates the upsell from a
  /// sheet, which is *how many things there are to tap*. The upsell is one
  /// label and one button (the structural test Nora uses, see
  /// docs/research/2026-08-28-nora-comparative-study.md §2). A sheet is a
  /// column of them. So a container is hidden only when it holds exactly one
  /// tappable element, no form control, and no feed post — and the verdict
  /// is re-checked on every pass, so a container that fills in later is put
  /// back.
  ///
  /// Facebook is a single-page app and the bar is inserted after load and on
  /// every in-page navigation, hence the observer, kept on `window` like the
  /// others so re-injection does not stack another. Everything is swallowed
  /// by a try/catch for the same reason as [unlockZoomFunc].
  static String hideAppUpsellFunc() {
    return """
(function () {
  try {
    var MARK = 'data-slim-upsell';
    // A composer, a search box, or a feed post inside the container means it
    // is content, whatever else it looks like.
    var CONTENT = 'textarea, input, [contenteditable], $kPostSelector';
    var TAPPABLE = 'button, [role="button"], a[href]';

    function isUpsell(node) {
      if (node.querySelector(CONTENT)) return false;
      // Exactly one: zero is a container still being filled in, and two or
      // more is a sheet of options.
      if (node.querySelectorAll(TAPPABLE).length !== 1) return false;
      return true;
    }

    function pass() {
      var nodes = document.querySelectorAll('div.fixed-container.bottom');
      for (var i = 0; i < nodes.length; i++) {
        var node = nodes[i];
        var hidden = node.getAttribute(MARK) === '1';
        if (isUpsell(node)) {
          if (hidden) continue;
          node.setAttribute(MARK, '1');
          node.style.display = 'none';
        } else if (hidden) {
          // Re-used for something with more in it: give it back.
          node.removeAttribute(MARK);
          node.style.display = '';
        }
      }
    }

    pass();

    if (!window.slimUpsellObserver) {
      var pending = null;
      window.slimUpsellObserver = new MutationObserver(function () {
        if (pending) return;
        // The feed appends dozens of nodes in a frame; one pass per burst.
        pending = setTimeout(function () {
          pending = null;
          pass();
        }, 250);
      });
      window.slimUpsellObserver.observe(
        document.body || document.documentElement,
        { childList: true, subtree: true }
      );
    }
  } catch (e) {}
})();
""";
  }

  /// Builds JavaScript that reports the link under a long press.
  ///
  /// Android's WebView fires `contextmenu` when a long press lands on a link,
  /// and that is the only signal this app can see: `webview_flutter` exposes
  /// no long-press or context-menu callback of its own (#183).
  ///
  /// The listener sits on `document` and uses `closest`, because the press
  /// usually lands on a span inside the anchor rather than on the anchor
  /// itself. The `href` property, not the attribute, is read so a relative
  /// link arrives absolute. Anything that is not http(s) — `javascript:`,
  /// `fb:`, `intent:` — is dropped here rather than in Dart, so nothing the
  /// page can craft reaches the sheet as something tappable.
  ///
  /// `preventDefault` is deliberately not called: the platform's own selection
  /// and image handling has to keep working, and release 26.08.28+124
  /// re-enabled the long press on images on purpose.
  ///
  /// The guard is on `window` like the observers above: injection runs on
  /// every page start, and without it each in-page navigation would leave
  /// another listener behind and post the same link several times.
  static String linkLongPressFunc(String channelName) {
    return '''
(function () {
  try {
    if (window.__slimLinkMenu) return;
    window.__slimLinkMenu = true;

    document.addEventListener('contextmenu', function (event) {
      try {
        var target = event.target;
        if (!target || !target.closest) return;
        var a = target.closest('a[href]');
        if (!a) return;

        var href = a.href;
        if (typeof href !== 'string') return;
        if (href.indexOf('http://') !== 0 && href.indexOf('https://') !== 0) {
          return;
        }

        // Trimmed short: the label only says which link this is, and a whole
        // post pasted into a bottom sheet is not that.
        var text = (a.textContent || '').trim().slice(0, 120);
        window[${jsonEncode(channelName)}].postMessage(
          JSON.stringify({ href: href, text: text })
        );
      } catch (e) {}
    }, true);
  } catch (e) {}
})();
''';
  }

  static String exampleJs = """
javascript:function foo() {
	     document.body.innerHTML = '';
		}
		foo();""";

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
  //
  // Worth a word home before giving up. Android does not hand a page exception
  // back through `runJavaScript`, so a filter that failed to install is
  // invisible from Dart; this runs afterwards and is the only thing left that
  // can see the gap. It reports at most once per injection, because the
  // observer is installed — and this branch reached — once per page load.
  if (typeof window.slimRemoveAds !== 'function') {
    try {
      window.$kDiagnosticsChannelName.postMessage(
        JSON.stringify({ kind: ${jsonEncode(kDiagFilterMissing)}, data: {} })
      );
    } catch (e) {}
    return;
  }

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
}

String createFabFunc = """
javascript:function createFab() {
		var button = document.createElement('button');
		button.type = 'button';
  		button.innerHTML = '▲';
  		button.className = 'my_fab_btn';

  		button.onclick = function() {
    		window.scrollTo(0,0);
  		};

  		var container = document.getElementById('root');
  		container.appendChild(button);
		}
		createFab();""";
