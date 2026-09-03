const String kFacebookHomeUrl = 'https://facebook.com/home.php';
const String kTouchFacebookHomeUrl = 'https://touch.facebook.com/home.php';
const String kFacebookHomeBasicUrl = 'https://mbasic.facebook.com/home.php';

/// Messenger's own site. Nothing loads it any more — see [kMessengerInboxUrl]
/// — and it is kept only as the name of a host the app knows about.
const String kMessengerUrl = 'https://www.messenger.com';

/// Facebook's own Messenger inbox. What the Messenger screen loads.
///
/// messenger.com has its own cookies, so it asks for a second sign-in even
/// while facebook.com is logged in — the app's most reported complaint (#326,
/// #300, #257). This address is the same inbox on the session the feed is
/// already using: measured on a device with the desktop agent it renders the
/// chats list, the compose button and the threads, with no login form.
const String kMessengerInboxUrl = 'https://www.facebook.com/messages/';

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
//
//Facebook picks which layout to serve from the user agent, so these strings
//decide what every injected selector in this app has to match. A desktop agent
//gets the desktop layout, which is heavier, harder to restyle, and in some
//regions served in a variant that renders badly on a phone.
//
//Facebook serves a "browser not supported" notice and a degraded page to
//agents it considers outdated, so if it ever rejects one of these, bump its
//version numbers together with a device check on the feed — see the plan notes.

/// Firefox for Android. Gets Facebook's touch layout.
///
/// This exact string is a known-good production value: it is what serves the
/// mobile feed correctly in the regions where a desktop agent gets a broken
/// layout. The age of the version is not the point — the layout Facebook
/// returns for it is — so do not "modernise" it without re-checking the feed.
const String kMobileUserAgent =
    "Mozilla/5.0 (Android 10; Mobile; rv:70.0) Gecko/70.0 Firefox/70.0";

/// Desktop Firefox on Windows. The Messenger screen's agent, and the feed's
/// "Desktop site" option.
///
/// Facebook serves the desktop site for this string: in-page chat and the
/// share menu work, and the page is heavier. On the feed it is the Settings
/// "Desktop site" option, not the default — the default is [kMobileUserAgent]
/// so injected selectors keep matching the touch layout.
///
/// The Messenger screen has no choice about it. [kMessengerInboxUrl] only
/// ships its full markup to a desktop agent, and the agent has to be a current
/// one: on the 2018 desktop Chrome string this replaced, Facebook adds a "Your
/// browser is no longer supported" banner to the inbox.
const String kFirefoxUserAgent =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:147.0) Gecko/20100101 Firefox/147.0";

/// Opera Mini. Used only by basic mode, which targets `mbasic.facebook.com`.
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

/// Which surface a user agent is being requested for.
///
/// Facebook varies the markup it serves by user agent, so one string for the
/// whole app means one of the two surfaces always gets the wrong layout.
enum UserAgentRole {
  /// The main feed and everything reached from it.
  feed,

  /// The Messenger webview.
  messenger,
}

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
const String kFDroidStoreUrl =
    "https://f-droid.org/packages/it.rignanese.leo.slimfacebook/";

/// Where donations go when in-app billing is not available: a non-Play
/// install, or the F-Droid build, which has no billing compiled in at all.
/// Same address as the `funding:` entry in pubspec.yaml.
const String kPayPalDonationUrl = "https://www.paypal.me/LeonardoRignanese";

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
  static const String hidePeopleYouMayKnow = "hide_people_you_may_know";

  /// Running total of feed items the filter has hidden, across all time.
  static const String adsBlockedTotal = "ads_blocked_total";
  static const String recentFirst = "recent_first";
  static const String useMbasic = "use_mbasic";

  /// When true, the feed uses the 119 desktop Firefox user agent.
  /// Unset or false keeps the mobile default. Messenger ignores this key.
  static const String useDesktopSite = "use_desktop_site";

  /// Whether crash and health reporting may send anything. Unset means on.
  static const String telemetryEnabled = "telemetry_enabled";

  /// Cold starts counted since install, from 1. Drives the rating prompt.
  static const String ratingOpens = "rating_opens";

  /// How many times the rating prompt has been shown, ever.
  static const String ratingAsks = "rating_asks";

  /// Set once the user picks a star rating. Unset means never answered.
  static const String ratingAnswered = "rating_answered";

  /// The open number the prompt last appeared on, so a feed that reloads
  /// cannot produce a second prompt in one launch.
  static const String ratingLastAskedOpen = "rating_last_asked_open";

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
