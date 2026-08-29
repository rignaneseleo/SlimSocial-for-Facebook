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
      expect(kMobileUserAgent, contains('Firefox/'));
    });

    test('is pinned to the exact string known to serve the touch layout', () {
      // Do not "modernise" this. The version numbers are load-bearing: this
      // precise agent is what Facebook serves the mobile feed to across the
      // regions where a desktop agent gets a broken layout. A newer Firefox
      // is not automatically safer — it is untested against that behaviour.
      // If Facebook ever rejects it as outdated (Task 10 Step 1 checks), bump
      // `Gecko/` and `Firefox/` together and re-run the recon, in one commit.
      expect(
        kMobileUserAgent,
        'Mozilla/5.0 (Android 10; Mobile; rv:70.0) Gecko/70.0 Firefox/70.0',
      );
    });
  });

  group('kDesktopUserAgent', () {
    test('is a desktop agent, which is what Messenger needs', () {
      expect(kDesktopUserAgent, contains('Macintosh'));
      expect(kDesktopUserAgent, isNot(contains('Mobile')));
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
