import 'package:flutter_test/flutter_test.dart';
import 'package:slimsocial_for_facebook/utils/webview_permissions.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  group('isWebViewPermissionSupported', () {
    test('accepts a camera-only request', () {
      expect(
        isWebViewPermissionSupported({WebViewPermissionResourceType.camera}),
        isTrue,
      );
    });

    test('refuses the microphone: no toggle and no RECORD_AUDIO', () {
      expect(
        isWebViewPermissionSupported(
          {WebViewPermissionResourceType.microphone},
        ),
        isFalse,
      );
    });

    test('refuses a request that bundles the microphone in', () {
      expect(
        isWebViewPermissionSupported({
          WebViewPermissionResourceType.camera,
          WebViewPermissionResourceType.microphone,
        }),
        isFalse,
      );
    });

    test('refuses an empty request rather than granting it', () {
      expect(isWebViewPermissionSupported({}), isFalse);
    });
  });
}
