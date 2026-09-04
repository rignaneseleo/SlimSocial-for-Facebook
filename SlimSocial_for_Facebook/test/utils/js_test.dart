import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:slimsocial_for_facebook/utils/ad_filter.dart';
import 'package:slimsocial_for_facebook/utils/js.dart';

void main() {
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

  group('CustomJs.unlockZoomFunc', () {
    test('rewrites every viewport meta on the page', () {
      // Facebook's SPA navigation can leave a second viewport tag behind, so
      // fixing only the first one leaves the later tag deciding the scale.
      final js = CustomJs.unlockZoomFunc();

      expect(js, contains('querySelectorAll'));
      expect(js, contains('meta[name="viewport"]'));
    });

    test('skips a meta it has already rewritten', () {
      // Injection runs on every navigation; without the mark each pass would
      // walk and rewrite tags that are already unlocked.
      final js = CustomJs.unlockZoomFunc();

      expect(js, contains("var MARK = 'data-slim-zoom';"));
      expect(js, contains("if (meta.getAttribute(MARK) === '1') continue;"));
    });

    test('drops the two clauses that block the gesture', () {
      final js = CustomJs.unlockZoomFunc();

      expect(js, contains("key === 'maximum-scale'"));
      expect(js, contains("key === 'minimum-scale'"));
    });

    test('forces user-scalable on, and adds it when it is absent', () {
      final js = CustomJs.unlockZoomFunc();

      expect(js, contains("key === 'user-scalable'"));
      expect(js, contains("out.push('user-scalable=yes');"));
      expect(js, contains('if (!sawUserScalable)'));
    });

    test('never rewrites the whole content string', () {
      // The other clauses have to survive: a hardcoded replacement would drop
      // `width=device-width` and hand back the 980px desktop layout.
      final js = CustomJs.unlockZoomFunc();

      expect(js, contains('out.push(clause);'));
      expect(js, isNot(contains('width=device-width')));
      expect(js, isNot(contains('initial-scale=1')));
    });

    test('installs exactly one observer, guarded by a global', () {
      // The ad observer has the history here: a guard that never sees the
      // previous observer stacks a new one on every page load.
      final js = CustomJs.unlockZoomFunc();

      expect(js, contains('if (!window.slimViewportObserver) {'));
      expect(js, contains('window.slimViewportObserver = new MutationObserver'));
      expect('new MutationObserver'.allMatches(js), hasLength(1));
      expect('.observe('.allMatches(js), hasLength(1));
    });

    test('watches the head for a replaced viewport tag', () {
      // A single-page navigation can swap the tag out after this script has
      // finished, and the replacement arrives locked again.
      final js = CustomJs.unlockZoomFunc();

      expect(js, contains('document.head || document.documentElement'));
      expect(js, contains('childList: true'));
      expect(js, contains('attributes: true'));
      expect(js, contains("attributeFilter: ['content']"));
    });

    test('clears the mark when the content was written again', () {
      // Otherwise the tag keeps the mark from the first pass and is skipped
      // forever, with maximum-scale back in place.
      final js = CustomJs.unlockZoomFunc();

      expect(js, contains("if (records[i].type === 'attributes')"));
      expect(js, contains('records[i].target.removeAttribute(MARK);'));
    });

    test('does not write a value it did not change', () {
      // setAttribute produces a mutation record either way, and the observer
      // clears the mark before re-running: an unconditional write ping-pongs.
      final js = CustomJs.unlockZoomFunc();

      expect(js, contains('if (next !== current)'));
    });

    test('runs as a self-invoking function that swallows its own failure', () {
      final js = CustomJs.unlockZoomFunc();

      expect(js.trim(), startsWith('(function () {'));
      expect(js.trim(), endsWith('})();'));
      expect(js, contains('try {'));
      expect(js, contains('} catch (e) {}'));
    });

    test('carries no javascript: prefix', () {
      // This is passed straight to runJavaScript, which evaluates the string as
      // script; the prefix belongs to the older members that were used as URLs.
      expect(CustomJs.unlockZoomFunc(), isNot(contains('javascript:')));
    });
  });

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
    test('says so when there was no filter to drive', () {
      // Android does not hand a page exception back through `runJavaScript`, so
      // a filter that failed to install leaves no trace on the Dart side. The
      // observer runs after it and is the only thing left that can notice.
      expect(
        CustomJs.removeAdsObserver,
        contains('window.$kDiagnosticsChannelName.postMessage'),
      );
      expect(
        CustomJs.removeAdsObserver,
        contains(jsonEncode(kDiagFilterMissing)),
      );
      expect(kDiagnosticFields, contains(kDiagFilterMissing));
    });

    test('still gives up when the filter is missing', () {
      // Reporting is not a reason to carry on: installing an observer that
      // calls a function which does not exist throws on every mutation.
      final branch = CustomJs.removeAdsObserver.substring(
        CustomJs.removeAdsObserver.indexOf("typeof window.slimRemoveAds"),
        CustomJs.removeAdsObserver.indexOf('var pending'),
      );

      expect(branch, contains('return;'));
      expect(branch, isNot(contains('observe(')));
    });

    test('reports nothing about the page itself', () {
      // The signal is that the filter is absent. Nothing about what the page
      // was showing when it happened belongs in it.
      final payload = CustomJs.removeAdsObserver.substring(
        CustomJs.removeAdsObserver.indexOf('postMessage'),
        CustomJs.removeAdsObserver.indexOf('} catch (e) {}'),
      );

      expect(payload, contains('data: {}'));
      expect(payload, isNot(contains('location')));
      expect(payload, isNot(contains('textContent')));
    });

    test('posts a message the Dart side accepts and empties', () {
      // The observer builds its payload by hand rather than through report(),
      // so it is the one diagnostic that can drift out of step with what the
      // channel will take.
      final parsed = parseDiagnostic(
        jsonEncode({'kind': kDiagFilterMissing, 'data': <String, Object?>{}}),
      );

      expect(parsed, isNotNull);
      expect(parsed!.kind, kDiagFilterMissing);
      expect(parsed.data, isEmpty);
    });
  });

  group('CustomJs.hideAppUpsellFunc', () {
    late String js;

    setUpAll(() => js = CustomJs.hideAppUpsellFunc());

    test('looks only at bottom-docked fixed containers', () {
      expect(js, contains('div.fixed-container.bottom'));
    });

    test('never touches a container holding a form control', () {
      // The comment composer docks in the same container as the upsell.
      expect(js, contains('textarea'));
      expect(js, contains('input'));
      expect(js, contains('[contenteditable]'));
    });

    test('never touches a container holding feed content', () {
      expect(js, contains(kPostSelector));
    });

    test('hides only a bar with exactly one thing to tap', () {
      // The upsell is one label and one button. A share sheet, a reaction
      // picker or a "turn on notifications" dialog is a column of options,
      // and the stylesheet rule that hid every bottom container took those
      // out too — leaving the reader with a dimmer and nothing to tap (#336,
      // #339). Zero is not hidden either: a container still being filled in
      // has nothing tappable yet, and is not yet anything.
      expect(js, contains('[role="button"]'));
      expect(js, contains('a[href]'));
      expect(js, contains('.length !== 1'));
    });

    test('gives a container back once it holds more than the bar', () {
      // A verdict is re-checked on every pass: the same container filled in
      // with a sheet must not stay hidden from an earlier pass.
      expect(js, contains('node.removeAttribute(MARK)'));
      expect(js, contains("node.style.display = ''"));
    });

    test('marks what it hid so a pass is idempotent', () {
      expect(js, contains('data-slim-upsell'));
      expect(js, contains("display = 'none'"));
    });

    test('watches for the bar arriving after the first pass', () {
      // Facebook is a single-page app: the bar is inserted after load and on
      // every in-page navigation. One observer, kept on window like the ad
      // observer, so re-injection does not stack another.
      expect(js, contains('if (!window.slimUpsellObserver) {'));
      expect(js, contains('window.slimUpsellObserver = new MutationObserver'));
      expect('new MutationObserver'.allMatches(js), hasLength(1));
    });

    test('coalesces bursts of mutations into a single pass', () {
      expect(js, contains('setTimeout'));
    });

    test('runs as a self-invoking function that swallows its own failure', () {
      expect(js.trim(), startsWith('(function () {'));
      expect(js.trim(), endsWith('})();'));
      expect(js, contains('try {'));
      expect(js, contains('} catch (e) {}'));
    });

    test('is not the stylesheet rule that hid every bottom sheet', () {
      // The old rule was `div.fixed-container.bottom:not(:has(...)) {
      // display: none !important }`: any sheet without a form control
      // vanished.
      expect(js, isNot(contains('display: none !important')));
      expect(js, isNot(contains(':has(')));
    });
  });

  group('CustomJs.linkLongPressFunc', () {
    final js = CustomJs.linkLongPressFunc('SlimLinkMenu');

    test('posts on the channel it is given', () {
      expect(js, contains(jsonEncode('SlimLinkMenu')));
      expect(js, contains('.postMessage('));
    });

    test('installs the listener only once', () {
      // Injection runs on every page start, and Facebook navigates in-page
      // constantly: without the guard every navigation adds another listener
      // and one long press reports the same link several times.
      expect(js, contains('if (window.__slimLinkMenu) return;'));
      expect(js, contains('window.__slimLinkMenu = true;'));
    });

    test('walks up to the anchor the press landed inside', () {
      // The press usually lands on a span inside the link, never on the <a>.
      expect(js, contains("closest('a[href]')"));
      expect(js, contains("addEventListener('contextmenu'"));
    });

    test('reports http(s) links only', () {
      expect(js, contains("href.indexOf('http://')"));
      expect(js, contains("href.indexOf('https://')"));
    });

    test('leaves the platform long press alone', () {
      // 26.08.28+124 re-enabled the long press on images on purpose, and
      // text selection has to keep working too.
      expect(js, isNot(contains('preventDefault')));
    });

    test('runs as a self-invoking function that swallows its own failure', () {
      expect(js.trim(), startsWith('(function () {'));
      expect(js.trim(), endsWith('})();'));
      expect(js, contains('} catch (e) {}'));
    });
  });

  group('CustomJs.feedGateFunc', () {
    final js = CustomJs.feedGateFunc(hosts: kFeedGateHosts, paths: kFeedPaths);

    test('installs itself once, guarded by a global', () {
      // Injection runs on every page start, and the gate leaves an interval
      // and a listener behind: without the guard each navigation stacks
      // another one on the same page.
      expect(js, contains('window.__slimFeedGate'));
      expect(js, contains('if (window.__slimFeedGate) return;'));
    });

    test('toggles the class the stylesheet is scoped to', () {
      expect(js, contains('slim-hide-feed'));
      expect(js, contains('document.documentElement.classList.toggle'));
    });

    test('carries the hosts and the paths it was given', () {
      for (final host in kFeedGateHosts) {
        expect(js, contains(jsonEncode(host)), reason: host);
      }
      for (final path in kFeedPaths) {
        expect(js, contains(jsonEncode(path)), reason: path);
      }
    });

    test('covers the hosts a redirect can land on', () {
      // Signed-in home is touch.facebook.com, but a redirect to either of the
      // others would leave the gate off and every post on screen.
      expect(kFeedGateHosts, containsAll(kFeedHosts));
      expect(kFeedGateHosts, contains('m.facebook.com'));
      expect(kFeedGateHosts, contains('www.facebook.com'));
    });

    test('decides on both the host and the path', () {
      // Path alone would gate on `/` of any site the webview opens; host alone
      // would keep the class on inside groups and profiles.
      expect(js, contains('location.hostname'));
      expect(js, contains('location.pathname'));
      expect(js, contains('&&'));
    });

    test('re-runs as the address changes in-page', () {
      // pushState fires no event, so a half-second re-read of location is what
      // catches a navigation into a group and takes the class back off.
      expect(js, contains("addEventListener('popstate', update)"));
      expect(js, contains('setInterval(update, 500)'));
    });

    test('runs as a self-invoking function that swallows its own failure', () {
      expect(js.trim(), startsWith('(function () {'));
      expect(js.trim(), endsWith('})();'));
      expect(js, contains('try {'));
      expect(js, contains('} catch (e) {}'));
    });
  });
}
