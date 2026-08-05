import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slimsocial_for_facebook/consts.dart';
import 'package:slimsocial_for_facebook/controllers/fb_controller.dart';
import 'package:slimsocial_for_facebook/main.dart';

Future<void> withPrefs(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  sp = await SharedPreferences.getInstance();
}

void main() {
  setUp(() => withPrefs({}));

  group('getHomePage', () {
    test('defaults to the touch site with the chronological suffix off', () {
      expect(PrefController.getHomePage(), '$kTouchFacebookHomeUrl$suffixDefault');
    });

    test('switches to mbasic when asked', () async {
      await withPrefs({SpKeys.useMbasic: true});

      expect(
        PrefController.getHomePage(),
        '$kFacebookHomeBasicUrl$suffixDefault',
      );
    });

    test('appends the recent-first suffix', () async {
      await withPrefs({SpKeys.recentFirst: true});

      expect(
        PrefController.getHomePage(),
        '$kTouchFacebookHomeUrl$suffixRecentFirst',
      );
    });
  });

  group('getUserAgent', () {
    test('defaults to the bundled Firefox agent', () {
      expect(PrefController.getUserAgent(), kFirefoxUserAgent);
    });

    test('uses the light agent together with mbasic', () async {
      await withPrefs({SpKeys.useMbasic: true});

      expect(PrefController.getUserAgent(), kOperaMiniUserAgent);
    });

    test('honours the custom agent once it is enabled', () async {
      await withPrefs({
        SpKeys.customUserAgent: 'my-agent',
        SpKeys.enabled(SpKeys.customUserAgent): true,
      });

      expect(PrefController.getUserAgent(), 'my-agent');
    });

    test('ignores a custom agent that was saved but left disabled', () async {
      await withPrefs({SpKeys.customUserAgent: 'my-agent'});

      expect(PrefController.getUserAgent(), kFirefoxUserAgent);
    });

    test('ignores a blank custom agent', () async {
      await withPrefs({
        SpKeys.customUserAgent: '',
        SpKeys.enabled(SpKeys.customUserAgent): true,
      });

      expect(PrefController.getUserAgent(), kFirefoxUserAgent);
    });
  });

  group('getUserCustomCss', () {
    test('returns null when unset', () {
      expect(PrefController.getUserCustomCss(), isNull);
    });

    test('returns null while the switch is off', () async {
      await withPrefs({SpKeys.customCss: '.a { color: red; }'});

      expect(PrefController.getUserCustomCss(), isNull);
    });

    test('returns the stylesheet once enabled', () async {
      await withPrefs({
        SpKeys.customCss: '.a { color: red; }',
        SpKeys.enabled(SpKeys.customCss): true,
      });

      expect(PrefController.getUserCustomCss(), '.a { color: red; }');
    });
  });

  group('getUserCustomJs', () {
    test('returns null while the switch is off', () async {
      await withPrefs({SpKeys.customJs: 'foo();'});

      expect(PrefController.getUserCustomJs(), isNull);
    });

    test('returns the snippet once enabled', () async {
      await withPrefs({
        SpKeys.customJs: 'foo();',
        SpKeys.enabled(SpKeys.customJs): true,
      });

      expect(PrefController.getUserCustomJs(), 'foo();');
    });
  });

  group('text zoom', () {
    test('leaves the page at its own size until the user asks otherwise', () {
      expect(PrefController.getTextZoom(), kDefaultTextZoom);
    });

    test('returns the value the user picked', () async {
      await PrefController.setTextZoom(130);

      expect(PrefController.getTextZoom(), 130);
    });

    test('refuses to store a value outside the usable range', () async {
      await PrefController.setTextZoom(1000);
      expect(PrefController.getTextZoom(), kMaxTextZoom);

      await PrefController.setTextZoom(0);
      expect(PrefController.getTextZoom(), kMinTextZoom);
    });

    test('clamps a stored value it did not write itself', () async {
      // A build with a wider range, or a hand-edited preferences file, must not
      // be able to leave the page at an unreadable size.
      await withPrefs({SpKeys.textZoom: 5});
      expect(PrefController.getTextZoom(), kMinTextZoom);

      await withPrefs({SpKeys.textZoom: 400});
      expect(PrefController.getTextZoom(), kMaxTextZoom);
    });

    test('keeps the range wide enough to be worth offering', () {
      expect(kMinTextZoom, lessThan(kDefaultTextZoom));
      expect(kMaxTextZoom, greaterThan(kDefaultTextZoom));
    });

    test('the slider divides the range into whole steps', () {
      // The dialog uses (max - min) / 5 divisions; a remainder would put the
      // last stop somewhere the user cannot actually select.
      expect((kMaxTextZoom - kMinTextZoom) % 5, 0);
    });
  });
}
