import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slimsocial_for_facebook/consts.dart';
import 'package:slimsocial_for_facebook/main.dart';

class PrefController {
  static String getHomePage() {
    var initialURl = kTouchFacebookHomeUrl;

    if (sp.getBool("use_mbasic") ?? false) initialURl = kFacebookHomeBasicUrl;

    if (sp.getBool("recent_first") ?? false) {
      return initialURl + suffixRecentFirst;
    }

    return initialURl + suffixDefault;
  }

  static String getUserAgent() {
    const spKeyEnabled = "custom_useragent_enabled";
    if (sp.getBool(spKeyEnabled) ?? false) {
      final customUserAgent = sp.getString("custom_useragent");
      if (customUserAgent?.isNotEmpty ?? false) {
        debugPrint("Using custom user agent: $customUserAgent");
        return customUserAgent!;
      }
    }

    if (sp.getBool("use_mbasic") ?? false) return kOperaMiniUserAgent;

    return kFirefoxUserAgent;
  }

  static String? getUserCustomCss() {
    const spKeyEnabled = "custom_css_enabled";
    if (sp.getBool(spKeyEnabled) ?? false) {
      final customCss = sp.getString("custom_css");
      if (customCss?.isNotEmpty ?? false) {
        debugPrint("Using custom css: $customCss");
        return customCss!;
      }
    }

    return null;
  }

  static String? getUserCustomJs() {
    const spKeyEnabled = "custom_js_enabled";
    if (sp.getBool(spKeyEnabled) ?? false) {
      final customJs = sp.getString("custom_js");
      if (customJs?.isNotEmpty ?? false) {
        debugPrint("Using custom js: $customJs");
        return customJs!;
      }
    }

    return null;
  }
}

class webViewUriState extends StateNotifier<Uri> {
  webViewUriState(this.ref) : super(Uri.parse(kTouchFacebookHomeUrl));

  final Ref ref;

  void updateUrl(String _url) => state = Uri.parse(_url);
}
