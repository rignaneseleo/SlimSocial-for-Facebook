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

  /// Returns the user agent to use for [role].
  ///
  /// Messenger is pinned to [kDesktopUserAgent]. A custom string or the
  /// desktop-site / basic-mode switches would otherwise send it a mobile
  /// agent, and Facebook answers that with the native-app interstitial.
  ///
  /// For the feed: a custom agent wins, then basic mode, then the desktop-site
  /// setting, then the mobile default.
  static String getUserAgent({UserAgentRole role = UserAgentRole.feed}) {
    if (role == UserAgentRole.messenger) return kDesktopUserAgent;

    final customUserAgent = _getOverride(SpKeys.customUserAgent);
    if (customUserAgent != null) {
      debugPrint("Using custom user agent: $customUserAgent");
      return customUserAgent;
    }

    if (sp.getBool(SpKeys.useMbasic) ?? false) return kOperaMiniUserAgent;

    if (sp.getBool(SpKeys.useDesktopSite) ?? false) return kFirefoxUserAgent;

    return kMobileUserAgent;
  }

  /// Text scaling for the webview, as a percentage of the page's own size.
  ///
  /// Clamped on the way out as well as on the way in, so a value written by an
  /// older build (or a corrupted preference) can never render the page
  /// unreadable.
  static int getTextZoom() =>
      _clampTextZoom(sp.getInt(SpKeys.textZoom) ?? kDefaultTextZoom);

  static Future<void> setTextZoom(int textZoom) =>
      sp.setInt(SpKeys.textZoom, _clampTextZoom(textZoom));

  /// How many feed items the filter has hidden, across every session.
  static int getAdsBlockedTotal() => sp.getInt(SpKeys.adsBlockedTotal) ?? 0;

  /// Adds [count] to the running total and returns the new value.
  ///
  /// Negative and zero counts are ignored: the page is the source of this
  /// number and nothing there should be able to walk the total backwards.
  static Future<int> addAdsBlocked(int count) async {
    if (count <= 0) return getAdsBlockedTotal();

    final total = getAdsBlockedTotal() + count;
    await sp.setInt(SpKeys.adsBlockedTotal, total);
    return total;
  }

  static int _clampTextZoom(int textZoom) {
    if (textZoom < kMinTextZoom) return kMinTextZoom;
    if (textZoom > kMaxTextZoom) return kMaxTextZoom;
    return textZoom;
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
