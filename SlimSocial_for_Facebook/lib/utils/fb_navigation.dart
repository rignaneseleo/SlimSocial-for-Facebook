import 'package:slimsocial_for_facebook/consts.dart';

/// First path segments of Facebook's sign-in and account-verification flow.
///
/// One entry per *first* segment, matched exactly rather than as a prefix, so
/// `/login/checkpoint/` matches on `login` while a page merely starting with
/// those letters — `/loginhelp`, a page named `securityreview` — does not.
///
/// `login.php` and `checkpoint` are the two the flow actually starts from; the
/// rest are the branches it can take once it has decided the sign-in needs
/// confirming.
const Set<String> _kAuthFirstSegments = {
  'authenticate',
  'checkpoint',
  'confirmemail.php',
  'login',
  'login.php',
  'recover',
  'security',
  'two_factor',
};

/// Two-segment prefixes of the same flow.
///
/// These lead with a segment that is emphatically *not* authentication on its
/// own — `/privacy/` and `/dialog/` are ordinary pages, and `/unified/` fronts
/// several unrelated surfaces — so matching them needs the second segment too.
const List<List<String>> _kAuthSegmentPairs = [
  ['unified', 'login_via'],
  ['privacy', 'consent'],
  ['dialog', 'oauth'],
  ['x', 'oauth'],
];

/// Whether [uri] belongs to Facebook's own sign-in flow rather than being a
/// page the reader asked to see.
///
/// ## Why this has to exist
///
/// Messenger authenticates against `facebook.com`, not `messenger.com`. Signing
/// in on the Messenger screen therefore navigates *out* of the Messenger host
/// and into a checkpoint page — the one that asks for a login code — and only
/// comes back once the code has been accepted.
///
/// The Messenger screen sends any `facebook.com` address to the feed, because
/// that is what a Facebook link tapped inside a conversation should do. Sign-in
/// looked exactly like such a link, so the screen closed itself half way
/// through authenticating: the code prompt arrived in the feed's webview, which
/// had no idea what to do with it, and Messenger could not be signed into at
/// all.
///
/// Measured on a device, the flow walks `/checkpoint/start/`, `/checkpoint/`,
/// `/login/checkpoint/` and `/unified/login_via/app/` — hence both tiers of
/// matching above.
///
/// Deliberately narrow. Anything not recognised here keeps the old behaviour of
/// handing the address to the feed, which is the right answer for every
/// ordinary Facebook link and the safe answer for one this does not know about:
/// a missed auth path costs a failed sign-in, while a content page wrongly kept
/// here would strand the reader on a page the Messenger screen cannot navigate
/// away from.
bool isFacebookAuthUrl(Uri uri) {
  //`pathSegments` yields a trailing empty string for a path ending in `/`, and
  //an empty list for `/` itself, so the empties go before anything is compared.
  final segments = uri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .map((segment) => segment.toLowerCase())
      .toList();

  if (segments.isEmpty) return false;

  if (_kAuthFirstSegments.contains(segments.first)) return true;

  for (final pair in _kAuthSegmentPairs) {
    if (segments.length >= 2 &&
        segments[0] == pair[0] &&
        segments[1] == pair[1]) {
      return true;
    }
  }

  return false;
}

/// What the Messenger webview should do with [uri].
///
/// Facebook.com addresses used to close this screen and hand the URL to the
/// feed. That crashed when there was nothing to pop
/// (SLIMSOCIAL-A, `StateError: No element`) and painted a black page when the
/// feed's mobile webview tried to render a desktop Messenger profile (#337).
/// Auth, profiles, and every other facebook.com page now stay here.
enum MessengerNavAction {
  /// Load [uri] in the Messenger webview.
  stay,

  /// Open [uri] outside the app (custom tab / external browser).
  openExternal,
}

/// Decides [MessengerNavAction] for a navigation that started on Messenger.
MessengerNavAction messengerNavigationFor(Uri uri) {
  for (final host in kPermittedHostnamesMessenger) {
    if (uri.host.endsWith(host)) return MessengerNavAction.stay;
  }

  for (final host in kPermittedHostnamesFb) {
    if (uri.host.endsWith(host)) return MessengerNavAction.stay;
  }

  // Auth URLs are facebook.com, so the loop above already keeps them. This
  // call is the belt: a future host that still serves the login flow is
  // treated as Messenger's own, not as an external page.
  if (isFacebookAuthUrl(uri)) return MessengerNavAction.stay;

  return MessengerNavAction.openExternal;
}

/// Hosts an `fb-messenger://` link uses when it names one conversation.
///
/// Anything else the scheme carries — `threads`, `compose`, a host this does
/// not know — opens the inbox rather than a guessed conversation.
const Set<String> _kMessengerThreadHosts = {
  'thread',
  'user',
  'user-thread',
};

/// Where the Messenger screen should open for [uri], or null when [uri] is not
/// a Messenger address at all.
///
/// ## The chat icon is not a link
///
/// Measured on a device on 2026-09-03: tapping the chat icon in Facebook's
/// mobile top bar does not navigate to `/messages/`. The page asks for
/// `fb-messenger://threads?…&entry_point=jewel&…` and the document url never
/// changes. That is why matching `/messages/` alone did not fix #338 — nothing
/// matched, the request fell through to the Custom Tab, which cannot open a
/// custom scheme, and the feed was left on a "Get the Messenger app" page.
/// The request does reach the navigation delegate, so it is caught here.
///
/// ## Everything lands on facebook.com, not messenger.com
///
/// messenger.com keeps its own cookies and asks for a second sign-in even
/// while facebook.com is logged in (#326, #300, #257). [kMessengerInboxUrl] is
/// the same inbox on the session the feed already has, so messenger.com and
/// `m.me` links are mapped onto it too.
///
/// A conversation id survives every form, because `/messages/t/<id>` takes the
/// same ids messenger.com does. The older `/messages/read/?tid=cid.c.A:B` form
/// does not translate, so it opens the inbox rather than a wrong thread.
///
/// Basic mode is left alone: `mbasic.facebook.com/messages/` still renders a
/// usable inbox on its own, and the whole point of that mode is not loading
/// the heavier surfaces.
Uri? messengerScreenTargetFor(Uri uri) {
  final segments =
      uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
  final host = uri.host.toLowerCase();

  if (uri.scheme == 'fb-messenger') {
    if (_kMessengerThreadHosts.contains(host) && segments.isNotEmpty) {
      return _messengerThread(segments.first);
    }
    return _messengerInbox();
  }

  //an m.me link is a page's short link, and the name in it is what the thread
  //is addressed by
  if (host == 'm.me') {
    if (segments.length == 1) return _messengerThread(segments.first);
    return _messengerInbox();
  }

  if (host == 'messenger.com' || host.endsWith('.messenger.com')) {
    if (segments.length >= 2 && segments.first.toLowerCase() == 't') {
      return _messengerThread(segments[1]);
    }
    return _messengerInbox();
  }

  if (host == 'mbasic.facebook.com') return null;

  final isFacebook = kPermittedHostnamesFb
      .any((other) => host == other || host.endsWith('.$other'));
  if (!isFacebook) return null;

  if (segments.isEmpty || segments.first.toLowerCase() != 'messages') {
    return null;
  }

  if (segments.length >= 3 && segments[1].toLowerCase() == 't') {
    return _messengerThread(segments[2]);
  }

  return _messengerInbox();
}

Uri _messengerInbox() => Uri.parse(kMessengerInboxUrl);

//[kMessengerInboxUrl] ends in a slash, so the thread id appends directly
Uri _messengerThread(String id) => Uri.parse('${kMessengerInboxUrl}t/$id');

/// Hosts that serve the same Facebook feed.
///
/// The home page setting names one of them — `touch.facebook.com` by default,
/// `mbasic.facebook.com` in basic mode — while a link tapped inside the feed
/// can land the webview on any of the others. Treating them as one host is
/// what stops a plain `facebook.com/home.php` from being read as a page the
/// reader navigated to.
const Set<String> _kHomeFeedHostFamily = {
  'facebook.com',
  'www.facebook.com',
  'm.facebook.com',
  'touch.facebook.com',
};

/// Paths that render the feed itself.
///
/// The query is not compared: the feed carries `?sk=h_chr` or `?sk=h_nor`
/// depending on the "most recent first" setting, and both are the same page.
const Set<String> _kHomeFeedPaths = {
  '',
  '/',
  '/home.php',
};

/// Whether [current] is the feed named by [home].
bool isHomeFeed(Uri current, Uri home) {
  final currentHost = current.host.toLowerCase();
  final homeHost = home.host.toLowerCase();

  final sameHost = currentHost == homeHost ||
      (_kHomeFeedHostFamily.contains(currentHost) &&
          _kHomeFeedHostFamily.contains(homeHost));
  if (!sameHost) return false;

  return _kHomeFeedPaths.contains(current.path);
}

/// What the system Back button should do.
enum BackAction {
  /// Step back through the webview's own history.
  goBack,

  /// Load the feed. There is no history to step back through, but the reader
  /// is not on the feed either.
  goHome,

  /// Leave the app.
  exit,
}

/// Decides [BackAction] for a Back press on the feed screen (#222).
///
/// Facebook's mobile site often replaces the current history entry instead of
/// pushing a new one, so a post, group or profile opened from the feed can
/// leave `canGoBack()` false. Back then closed the app from a page the reader
/// had clearly navigated into, which is what #222 reports. Loading the feed
/// instead gives that press somewhere to go; a second press, now on the feed,
/// still exits.
///
/// The sign-in flow is the exception. It is not the feed, but sending it home
/// would bounce a signed-out reader between the login form and the redirect
/// back to it, so Back there keeps closing the app.
BackAction backActionFor({
  required bool canGoBack,
  required Uri? current,
  required Uri home,
}) {
  if (canGoBack) return BackAction.goBack;

  //a url that could not be read says nothing about where the reader is, so the
  //old behaviour stands rather than a guessed navigation
  if (current == null) return BackAction.exit;

  if (isHomeFeed(current, home)) return BackAction.exit;
  if (isFacebookAuthUrl(current)) return BackAction.exit;

  return BackAction.goHome;
}
