import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../consts.dart';
import '../main.dart';

class PrefController {
  static String getHomePage() {
    String initialURl = kTouchFacebookHomeUrl;

    if (sp.getBool("use_mbasic") ?? false) initialURl = kFacebookHomeBasicUrl;

    if (sp.getBool("recent_first") ?? false)
      return initialURl + suffixRecentFirst;

    return initialURl + suffixDefault;
  }

  static String getUserAgent() {
    String spKeyEnabled = "custom_useragent_enabled";
    if (sp.getBool(spKeyEnabled) ?? false) {
      var customUserAgent = sp.getString("custom_useragent");
      if (customUserAgent?.isNotEmpty ?? false) {
        print("Using custom user agent: $customUserAgent");
        return customUserAgent!;
      }
    }

    if (sp.getBool("use_mbasic") ?? false) return kOperaMiniUserAgent;

    return kFirefoxUserAgent;
  }

  static String? getUserCustomCss() {
    String spKeyEnabled = "custom_css_enabled";
    if (sp.getBool(spKeyEnabled) ?? false) {
      var customCss = sp.getString("custom_css");
      if (customCss?.isNotEmpty ?? false) {
        print("Using custom css: $customCss");
        return customCss!;
      }
    }

    return null;
  }

  static String? getUserCustomJs() {
    String spKeyEnabled = "custom_js_enabled";
    if (sp.getBool(spKeyEnabled) ?? false) {
      var customJs = sp.getString("custom_js");
      if (customJs?.isNotEmpty ?? false) {
        print("Using custom js: $customJs");
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
