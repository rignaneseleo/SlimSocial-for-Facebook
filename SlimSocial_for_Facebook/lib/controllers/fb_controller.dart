import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slimsocial_for_facebook/consts.dart';
import 'package:slimsocial_for_facebook/main.dart';

class PrefController {
  static String getHomePage() {
    var initialURl = kTouchFacebookHomeUrl;

    if (sp.getBool(SpKeys.useMbasic) ?? false) {
      initialURl = kFacebookHomeBasicUrl;
    }

    if (sp.getBool(SpKeys.recentFirst) ?? false) {
      return initialURl + suffixRecentFirst;
    }

    return initialURl + suffixDefault;
  }

  static String getUserAgent() {
    final customUserAgent = _getOverride(SpKeys.customUserAgent);
    if (customUserAgent != null) {
      debugPrint("Using custom user agent: $customUserAgent");
      return customUserAgent;
    }

    if (sp.getBool(SpKeys.useMbasic) ?? false) return kOperaMiniUserAgent;

    return kFirefoxUserAgent;
  }

  static String? getUserCustomCss() {
    final customCss = _getOverride(SpKeys.customCss);
    if (customCss != null) debugPrint("Using custom css: $customCss");
    return customCss;
  }

  static String? getUserCustomJs() {
    final customJs = _getOverride(SpKeys.customJs);
    if (customJs != null) debugPrint("Using custom js: $customJs");
    return customJs;
  }

  /// Returns the value stored under [spKey], but only when its companion
  /// `<spKey>_enabled` switch is on and the value is not blank.
  static String? _getOverride(String spKey) {
    if (!(sp.getBool(SpKeys.enabled(spKey)) ?? false)) return null;

    final value = sp.getString(spKey);
    if (value == null || value.isEmpty) return null;

    return value;
  }
}

class webViewUriState extends StateNotifier<Uri> {
  webViewUriState(this.ref) : super(Uri.parse(kTouchFacebookHomeUrl));

  final Ref ref;

  void updateUrl(String _url) => state = Uri.parse(_url);
}
