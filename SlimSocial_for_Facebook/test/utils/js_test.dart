import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
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
  });
}
