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
