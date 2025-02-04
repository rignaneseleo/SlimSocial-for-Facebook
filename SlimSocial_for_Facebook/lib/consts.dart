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

//key for the shared preferences

const String spKeyUseMbasic = "use_mbasic";
const String spKeyRecentFirst = "recent_first";
const String spKeyCustomProxy = "custom_proxy";
const String spKeyCustomUserAgent = "custom_useragent";
const String spKeyCustomCss = "custom_css";
const String spKeyCustomJs = "custom_js";

// key enabled for the shared preferences
const String spKeyUserAgentEnabled = "custom_useragent_enabled";
const String spKeyCustomCssEnabled = "custom_css_enabled";
const String spKeyCustomJsEnabled = "custom_js_enabled";
const String spKeyCustomProxyEnabled = "custom_proxy_enabled";


//suffix for the feed
const String suffixRecentFirst = "?sk=h_chr";
const String suffixDefault = "?sk=h_nor";

//user agent for the webview
const String kFirefoxUserAgent =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:124.0) Gecko/20100101 Firefox/124.0";
const String kIpadUserAgent =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36";
const String kOperaMiniUserAgent =
    "Opera/9.80 (Android; Opera Mini/69.0.2254/191.303; U; en) Presto/2.12.423 Version/12.16";

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

final Map<double, String> priceToProductId = {
      10.0: 'subscription_10_euro',
      15.0: 'subscription_15_euro',
      20.0: 'subscription_20_euro',
      25.0: 'subscription_25_euro',
    };
