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

  group('kFirefoxUserAgent', () {
    test('is recent enough that Facebook does not flag it as outdated', () {
      final match =
          RegExp(r'Firefox/(\d+)\.0$').firstMatch(kFirefoxUserAgent);

      expect(match, isNotNull, reason: 'unexpected user agent shape');
      expect(int.parse(match!.group(1)!), greaterThanOrEqualTo(140));
    });

    test('advertises the same version in rv: and Firefox/', () {
      final rv = RegExp(r'rv:(\d+)\.0').firstMatch(kFirefoxUserAgent);
      final firefox = RegExp(r'Firefox/(\d+)\.0').firstMatch(kFirefoxUserAgent);

      expect(rv!.group(1), firefox!.group(1));
    });
  });
}
