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
      expect(PrefController.getUserAgent(), kMobileUserAgent);
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

      expect(PrefController.getUserAgent(), kMobileUserAgent);
    });

    test('ignores a blank custom agent', () async {
      await withPrefs({
        SpKeys.customUserAgent: '',
        SpKeys.enabled(SpKeys.customUserAgent): true,
      });

      expect(PrefController.getUserAgent(), kMobileUserAgent);
    });
  });

  group('getUserAgent roles', () {
    test('defaults to the feed agent', () {
      // The redundant-looking explicit role is the assertion: it pins the
      // default to `feed`, so a change of default fails here rather than
      // silently switching which layout Facebook serves.
      // ignore: avoid_redundant_argument_values
      final explicit = PrefController.getUserAgent(role: UserAgentRole.feed);

      expect(PrefController.getUserAgent(), explicit);
    });

    test('gives the feed the mobile agent', () {
      // The role is passed explicitly even though it is the default, because
      // this test is about the feed role specifically, not about the default.
      // ignore: avoid_redundant_argument_values
      final feed = PrefController.getUserAgent(role: UserAgentRole.feed);

      expect(feed, kMobileUserAgent);
    });

    test('gives Messenger the current desktop Firefox agent', () {
      // Desktop, because the inbox only ships its full markup to a desktop
      // agent. Current, because on the 2018 Chrome string this used to send,
      // facebook.com/messages/ carries a "browser no longer supported" banner.
      expect(
        PrefController.getUserAgent(role: UserAgentRole.messenger),
        kFirefoxUserAgent,
      );
    });

    test('basic mode overrides the feed, not Messenger', () async {
      // This file seeds preferences with withPrefs (which calls
      // SharedPreferences.setMockInitialValues and is reset by setUp), never
      // bare sp.setBool — mixing the two leaks state between tests.
      await withPrefs({SpKeys.useMbasic: true});

      expect(
        PrefController.getUserAgent(role: UserAgentRole.feed),
        kOperaMiniUserAgent,
      );
      expect(
        PrefController.getUserAgent(role: UserAgentRole.messenger),
        kFirefoxUserAgent,
      );
    });

    test('a custom agent overrides the feed, not Messenger', () async {
      await withPrefs({
        SpKeys.customUserAgent: 'my-agent',
        SpKeys.enabled(SpKeys.customUserAgent): true,
      });

      expect(
        PrefController.getUserAgent(role: UserAgentRole.feed),
        'my-agent',
      );
      expect(
        PrefController.getUserAgent(role: UserAgentRole.messenger),
        kFirefoxUserAgent,
      );
    });

    test('the desktop-site setting serves 119\'s Firefox agent to the feed',
        () async {
      await withPrefs({SpKeys.useDesktopSite: true});

      expect(
        PrefController.getUserAgent(role: UserAgentRole.feed),
        kFirefoxUserAgent,
      );
      expect(
        PrefController.getUserAgent(role: UserAgentRole.messenger),
        kFirefoxUserAgent,
      );
    });

    test('basic mode wins over the desktop-site setting', () async {
      await withPrefs({
        SpKeys.useDesktopSite: true,
        SpKeys.useMbasic: true,
      });

      expect(
        PrefController.getUserAgent(role: UserAgentRole.feed),
        kOperaMiniUserAgent,
      );
    });

    test('a custom agent wins over the desktop-site setting', () async {
      await withPrefs({
        SpKeys.useDesktopSite: true,
        SpKeys.customUserAgent: 'my-agent',
        SpKeys.enabled(SpKeys.customUserAgent): true,
      });

      expect(
        PrefController.getUserAgent(role: UserAgentRole.feed),
        'my-agent',
      );
    });

    test('every role resolves to a non-empty agent', () {
      for (final role in UserAgentRole.values) {
        expect(PrefController.getUserAgent(role: role), isNotEmpty);
      }
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

  group('ads blocked total', () {
    test('starts at zero', () {
      expect(PrefController.getAdsBlockedTotal(), 0);
    });

    test('accumulates across calls, because each is one filter pass', () async {
      await PrefController.addAdsBlocked(3);
      await PrefController.addAdsBlocked(4);

      expect(PrefController.getAdsBlockedTotal(), 7);
    });

    test('ignores counts that would walk the total backwards', () async {
      // The number comes from the page, so it is not trusted.
      await PrefController.addAdsBlocked(5);
      await PrefController.addAdsBlocked(0);
      await PrefController.addAdsBlocked(-10);

      expect(PrefController.getAdsBlockedTotal(), 5);
    });

    test('returns the running total', () async {
      expect(await PrefController.addAdsBlocked(2), 2);
      expect(await PrefController.addAdsBlocked(3), 5);
    });

    test('survives a value already on disk', () async {
      await withPrefs({SpKeys.adsBlockedTotal: 100});

      expect(PrefController.getAdsBlockedTotal(), 100);
      expect(await PrefController.addAdsBlocked(1), 101);
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
