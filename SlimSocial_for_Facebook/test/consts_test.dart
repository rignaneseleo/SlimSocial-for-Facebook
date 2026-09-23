import 'package:flutter_test/flutter_test.dart';
import 'package:slimsocial_for_facebook/consts.dart';

void main() {
  group('SpKeys', () {
    // These literals are persisted on the user's device. Changing one silently
    // resets that setting for everyone who already has the app installed, so
    // they are pinned here on purpose.
    test('keeps the keys already written to disk by released versions', () {
      expect(SpKeys.gpsPermission, 'gps_permission');
      expect(SpKeys.cameraPermission, 'camera_permission');
      expect(SpKeys.photosPermission, 'photos_permission');
      expect(SpKeys.enableMessenger, 'enable_messenger');
      expect(SpKeys.hideAds, 'hide_ads');
      expect(SpKeys.recentFirst, 'recent_first');
      expect(SpKeys.useMbasic, 'use_mbasic');
      expect(SpKeys.useDesktopSite, 'use_desktop_site');
      expect(SpKeys.customUserAgent, 'custom_useragent');
      expect(SpKeys.customCss, 'custom_css');
      expect(SpKeys.customJs, 'custom_js');
      expect(SpKeys.customProxy, 'custom_proxy');
      expect(SpKeys.textZoom, 'text_zoom');
    });

    test('derives the companion switch key', () {
      expect(SpKeys.enabled(SpKeys.customCss), 'custom_css_enabled');
      expect(SpKeys.enabled(SpKeys.customJs), 'custom_js_enabled');
      expect(
        SpKeys.enabled(SpKeys.customUserAgent),
        'custom_useragent_enabled',
      );
      expect(SpKeys.enabled(SpKeys.customProxy), 'custom_proxy_enabled');
    });

    test('derives the proxy host and port keys', () {
      expect(SpKeys.customProxyIp, 'custom_proxy_ip');
      expect(SpKeys.customProxyPort, 'custom_proxy_port');
    });

    test('the gallery key is plural, matching what the webviews read', () {
      // The settings screen wrote `photo_permission` while both webviews read
      // `photos_permission`, so the toggle looked permanently switched off.
      expect(SpKeys.photosPermission, isNot('photo_permission'));
    });
  });

  group('kMobileUserAgent', () {
    test('asks Facebook for the mobile layout', () {
      // This is the whole point of the constant: every selector this app
      // injects is written against the touch layout, and Facebook picks the
      // layout from the user agent.
      expect(kMobileUserAgent, contains('Android'));
      expect(kMobileUserAgent, contains('Mobile'));
      expect(kMobileUserAgent, contains('Chrome/'));
    });

    test('is pinned to the Chrome 131 Pixel 7 string from the #373 A/B', () {
      // Firefox 70 / Android mobile kept touch layout but decoded Reels at
      // 360p. Chrome 131 Mobile Pixel 7 kept touch and decoded 720p. Do not
      // swap without re-checking both: touch surface + video decode.
      expect(
        kMobileUserAgent,
        'Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36',
      );
    });
  });

  group('kFirefoxUserAgent', () {
    test('is the 119 desktop feed agent, pinned verbatim', () {
      expect(
        kFirefoxUserAgent,
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:147.0) Gecko/20100101 Firefox/147.0',
      );
      expect(kFirefoxUserAgent, isNot(contains('Mobile')));
      expect(kFirefoxUserAgent, isNot(kMobileUserAgent));
    });
  });

  group('kMessengerInboxUrl', () {
    test("is Facebook's own inbox, not messenger.com", () {
      // The host is the whole point: messenger.com keeps its own cookies and
      // asks for a second sign-in even when facebook.com is logged in (#326,
      // #300). This address renders the same inbox on the session the feed
      // already has.
      expect(Uri.parse(kMessengerInboxUrl).host, 'www.facebook.com');
      expect(kMessengerInboxUrl, endsWith('/messages/'));
    });
  });

  group('rating prompt keys', () {
    test('are distinct from each other and from every other key', () {
      const keys = <String>[
        SpKeys.ratingOpens,
        SpKeys.ratingAsks,
        SpKeys.ratingAnswered,
        SpKeys.ratingLastAskedOpen,
      ];

      expect(keys.toSet(), hasLength(keys.length));
      //a collision with a live key silently reinterprets a stored value as
      //something of a different type
      for (final key in keys) {
        expect(key, isNot(SpKeys.telemetryEnabled));
        expect(key, isNot(SpKeys.adsBlockedTotal));
        expect(key, isNot(SpKeys.textZoom));
      }
    });
  });
}
