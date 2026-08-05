const String kFacebookHomeUrl = 'https://facebook.com/home.php';
const String kTouchFacebookHomeUrl = 'https://touch.facebook.com/home.php';
const String kFacebookHomeBasicUrl = 'https://mbasic.facebook.com/home.php';
const String kMessengerUrl = 'https://www.messenger.com';

const List<String> kPermittedHostnamesFb = [
  "facebook.com",
  //"fbcdn.net", //removed so it downloads pics via the browser
  "fb.com",
  "fb.me",
];
const List<String> kPermittedHostnamesMessenger = [
  "messenger.com",
  "m.me",
];

//suffix for the feed
const String suffixRecentFirst = "?sk=h_chr";
const String suffixDefault = "?sk=h_nor";

//user agent for the webview
//keep this reasonably recent: Facebook serves a "browser not supported"
//notice (and a degraded page) to user agents it considers outdated
const String kFirefoxUserAgent =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:147.0) Gecko/20100101 Firefox/147.0";
const String kIpadUserAgent =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36";
const String kOperaMiniUserAgent =
    "Opera/9.80 (Android; Opera Mini/69.0.2254/191.303; U; en) Presto/2.12.423 Version/12.16";

//text scaling applied to the webview, as a percentage
//
//Android multiplies the page text by the system font scale, and Facebook's
//layout overflows instead of reflowing when it grows: text ends up clipped or
//running off the screen. Pinning the scale would take large-text accessibility
//away from the people who rely on it, so the value is a setting and is only
//clamped to a range the page survives.
const int kMinTextZoom = 80;
const int kMaxTextZoom = 150;
const int kDefaultTextZoom = 100;

const String kEmailToDevUrl =
    "mailto:dev.rignaneseleo+slimsocial@gmail.com?subject=SlimSocial%20for%20Facebook%20feedback";
const String kGithubIssuesUrl =
    "https://github.com/rignaneseleo/SlimSocial-for-Facebook/issues";
const String kDevEmail = "dev.rignaneseleo+slimsocial@gmail.com";
const String kTwitterProfileUrl = "https://twitter.com/leorigna";
const String kGithubProjectUrl =
    "https://github.com/rignaneseleo/SlimSocial-for-Facebook";
const String kPlayStoreUrl =
    "https://play.google.com/store/apps/details?id=it.rignanese.leo.slimfacebook";

/// Keys used to store settings in [SharedPreferences].
///
/// These literals live on the user's device: renaming a *value* here silently
/// resets that setting for everyone who already has the app installed. Rename
/// the constant if you must, never the string.
///
/// They are centralised because they used to be typed out by hand at every call
/// site, and a single mismatch (`photo_permission` in the settings screen vs
/// `photos_permission` in the webviews) left the gallery toggle permanently
/// stuck in the off position.
class SpKeys {
  const SpKeys._();

  static const String gpsPermission = "gps_permission";
  static const String cameraPermission = "camera_permission";
  static const String photosPermission = "photos_permission";

  static const String textZoom = "text_zoom";

  static const String enableMessenger = "enable_messenger";
  static const String hideAds = "hide_ads";
  static const String recentFirst = "recent_first";
  static const String useMbasic = "use_mbasic";

  static const String customUserAgent = "custom_useragent";
  static const String customCss = "custom_css";
  static const String customJs = "custom_js";
  static const String customProxy = "custom_proxy";

  /// Companion key holding whether the `custom_*` override above is active.
  static String enabled(String key) => "${key}_enabled";

  /// Companion keys for [customProxy].
  static String get customProxyIp => "${customProxy}_ip";
  static String get customProxyPort => "${customProxy}_port";
}
