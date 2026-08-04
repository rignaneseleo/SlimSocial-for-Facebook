import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:slimsocial_for_facebook/utils/js.dart';

void main() {
  group('CustomJs.injectCssFunc', () {
    test('wraps the stylesheet in a valid JS string literal', () {
      final js = CustomJs.injectCssFunc('.a { color: red; }');

      expect(js, contains(jsonEncode('.a { color: red; }')));
    });

    test('escapes single quotes instead of terminating the argument', () {
      // The CSS used to be interpolated into a single-quoted JS string, so an
      // apostrophe in a user stylesheet broke the whole injection.
      final js = CustomJs.injectCssFunc("[aria-label='Next'] { color: red; }");

      expect(js, isNot(contains("('[aria-label='")));
      expect(js, contains("[aria-label='Next']"));
    });

    test('escapes double quotes', () {
      final js = CustomJs.injectCssFunc('[aria-label="Next"] { color: red; }');

      expect(js, contains(r'[aria-label=\"Next\"]'));
    });

    test('encodes newlines so the caller can flatten the snippet', () {
      // Both webviews run `.replaceAll("\n", " ")` over the generated code;
      // a raw newline inside the string literal would be destroyed by that.
      final js = CustomJs.injectCssFunc('.a {\n  color: red;\n}');
      final argument = js.substring(js.indexOf('}) (') + 4);

      expect(argument, contains(r'\n'));
      expect(argument.contains('\n  color'), isFalse);
    });
  });

  group('CustomJs.removeAdsObserver', () {
    test('installs the observer when none is running yet', () {
      // The guard used to be `typeof newPostsObserver !== 'undefined'` against
      // a name that only existed inside the branch, so it was always false and
      // the observer was never created: ads reappeared as soon as you scrolled.
      expect(
        CustomJs.removeAdsObserver,
        contains("typeof window.newPostsObserver === 'undefined'"),
      );
    });

    test('stores the observer globally so it is not re-created', () {
      expect(
        CustomJs.removeAdsObserver,
        contains('window.newPostsObserver = new MutationObserver'),
      );
    });

    test('observes using the global reference', () {
      expect(
        CustomJs.removeAdsObserver,
        contains('window.newPostsObserver.observe(bodyNode, config)'),
      );
    });

    test('never declares a block-scoped observer again', () {
      expect(CustomJs.removeAdsObserver, isNot(contains('const newPosts')));
      expect(CustomJs.removeAdsObserver, isNot(contains('let newPosts')));
    });
  });
}
