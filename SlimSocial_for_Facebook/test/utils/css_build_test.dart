import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slimsocial_for_facebook/main.dart';
import 'package:slimsocial_for_facebook/utils/css.dart';

Future<void> withPrefs(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  sp = await SharedPreferences.getInstance();
}

void main() {
  setUp(() => withPrefs({}));

  group('buildFacebookCss', () {
    test('applies the user stylesheet', () {
      // This is the regression that mattered: the Facebook page never looked at
      // the user's CSS, so the setting only did anything inside Messenger.
      expect(
        CustomCss.buildFacebookCss('.mine { color: red; }'),
        contains('.mine { color: red; }'),
      );
    });

    test('puts the user stylesheet last so it wins the cascade', () async {
      await withPrefs({CustomCss.centerTextPostsCss.key: true});

      final css = CustomCss.buildFacebookCss('.mine { color: red; }');

      expect(
        css.indexOf('.mine'),
        greaterThan(css.indexOf(CustomCss.centerTextPostsCss.code)),
      );
    });

    test('includes the stylesheets the user switched on', () async {
      await withPrefs({CustomCss.hideStoriesCss.key: true});

      expect(
        CustomCss.buildFacebookCss(null),
        contains(CustomCss.hideStoriesCss.code),
      );
    });

    test('leaves out the stylesheets that are off', () {
      expect(
        CustomCss.buildFacebookCss(null),
        isNot(contains(CustomCss.hideStoriesCss.code)),
      );
    });

    test('separates the stylesheets so rules do not merge', () async {
      await withPrefs({
        CustomCss.hideStoriesCss.key: true,
        CustomCss.centerTextPostsCss.key: true,
      });

      final css = CustomCss.buildFacebookCss(null);

      expect(css, isNot(contains('}.')));
      expect(css, isNot(contains('};')));
    });

    test('carries the feed rule when the feed toggle is on', () async {
      // The toggle is only a stored bool until this list picks it up, and the
      // class gate the rule depends on is injected separately.
      await withPrefs({CustomCss.hideFeedCss.key: true});

      expect(
        CustomCss.buildFacebookCss(null),
        contains(CustomCss.hideFeedCss.code),
      );
    });

    test('handles a null and a blank user stylesheet', () {
      expect(CustomCss.buildFacebookCss(null), isNotNull);
      expect(CustomCss.buildFacebookCss(''), isNot(contains('  ')));
    });
  });

  group('buildMessengerCss', () {
    test('applies the user stylesheet', () {
      expect(
        CustomCss.buildMessengerCss('.mine { color: red; }'),
        contains('.mine { color: red; }'),
      );
    });

    test('adds the Messenger dark theme only when dark mode is on', () async {
      expect(
        CustomCss.buildMessengerCss(null),
        isNot(contains(CustomCss.darkThemeMessengerCss.code)),
      );

      await withPrefs({CustomCss.darkThemeCss.key: true});

      expect(
        CustomCss.buildMessengerCss(null),
        contains(CustomCss.darkThemeMessengerCss.code),
      );
    });
  });
}
