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
}
