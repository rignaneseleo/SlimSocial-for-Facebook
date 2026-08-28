/// Query parameters that describe *who is reading* or *how they got here*
/// rather than what they are looking at.
///
/// Facebook rewrites nearly every link in the feed to carry a few of these, so
/// a url copied out of the app — or handed to a Custom Tab, or shared to
/// another app — otherwise carries the reading session with it. Dropping them
/// is safe in the direction that matters: a Facebook permalink resolves to the
/// same story without any of them, because the story id lives in the path or in
/// `story_fbid`/`id`, never in the tracking blob.
///
/// Only ever add a parameter here that is genuinely *about the reader*. A
/// parameter that turns out to select content is not merely useless to strip,
/// it breaks the link, and the failure looks like Facebook being down rather
/// than like this list being wrong — which is why `story_fbid`, `id`, `v` and
/// `sk` (the feed-order suffix this app itself appends) are all absent.
const List<String> kTrackingParams = [
  // Facebook's own click and referral instrumentation.
  //
  // `ref`, `__cft__`, `__tn__` and `__xts__` are the awkward ones: they are on
  // the shared links people actually paste, and they look load-bearing because
  // they are long and opaque. They are not — they encode the *reading session*
  // (which surface the click came from, which ranking pass produced the item),
  // and the same permalink opens fine with them removed. `__cft__` and
  // `__xts__` additionally arrive indexed, as `__cft__[0]` — sometimes with the
  // brackets percent-escaped — so they are listed here unindexed and matched on
  // the name up to the bracket.
  'fbclid',
  'mibextid',
  'referral_source',
  'referral_story_type',
  'surface_type',
  'comment_tracking',
  'notif_id',
  'notif_t',
  'ref',
  '__cft__',
  '__tn__',
  '__xts__',
  // The set the current mobile site appends, added after a review pointed out
  // that the group above is the *old* vocabulary: a link copied out of the feed
  // today usually carries these instead. `sfnsn` names the surface, `paipv` and
  // `eav` are per-view tokens, and `_rdr` is the redirector's own marker.
  'sfnsn',
  'paipv',
  'eav',
  '_rdr',
  'idorvanity',
  'wtsid',
  'rdid',
  // Generic UTM tags. Not Facebook's; they ride along on outbound links that
  // pages post, and they identify the campaign a click is being attributed to.
  'utm_source',
  'utm_medium',
  'utm_campaign',
  'utm_term',
  'utm_content',
  'utm_id',
  'utm_name',
  'utm_referrer',
  // Ad-network click ids. Each one is a single click's identifier minted by the
  // network, so it is per-reader by construction.
  'gclid',
  'gbraid',
  'wbraid',
  'msclkid',
  'twclid',
  'yclid',
  'igshid',
  'igsh',
  // Email and marketing-automation recipient ids. `mc_eid` in particular is a
  // stable per-subscriber identifier.
  'mc_cid',
  'mc_eid',
  '_hsenc',
  '_hsmi',
  // Referrer echoes: the page telling the destination where the reader came
  // from.
  'ref_src',
  'ref_url',
  'share_id',
];

/// [kTrackingParams] folded to lowercase and de-duplicated, for lookup.
///
/// The list is already lowercase, but matching is case-insensitive because
/// Facebook is not consistent about the case of a parameter it generates, and a
/// future entry typed with a capital would otherwise stop matching anything
/// without failing any test.
final Set<String> _trackingParams =
    kTrackingParams.map((name) => name.toLowerCase()).toSet();

/// Returns [url] with every [kTrackingParams] entry removed from its query.
///
/// A string this function does not fully understand is returned *byte for
/// byte*, and so is a url that had nothing to strip. That is deliberate: the
/// result is fed straight back to the webview, and a url that has been
/// normalised for no reason is a url that can no longer be compared against the
/// one the webview is already showing.
String stripTrackingParams(String url) {
  final uri = Uri.tryParse(url);

  //`tryParse` only rejects the genuinely malformed ("http://["); "not a url at
  //all" parses happily as a relative reference whose `toString` then
  //percent-encodes the spaces. Rebuilding that would silently corrupt a string
  //we were only asked to filter, so both cases — and every scheme-less href the
  //page hands over before the webview resolves it — come back untouched.
  if (uri == null || !uri.hasScheme) return url;

  final all = uri.queryParametersAll;

  final kept = <String, List<String>>{};
  for (final param in all.entries) {
    if (_isTrackingParam(param.key)) continue;
    //`queryParametersAll`, not `queryParameters`: the collapsing form keeps
    //only the last value of a repeated parameter, so `?a=1&a=2` would come out
    //as `?a=2` and this function would be quietly deleting content while
    //claiming to only remove tracking.
    kept[param.key] = param.value;
  }

  //Keys are unique in `queryParametersAll`, so an equal count means no
  //parameter matched. Returning the original string is not just an
  //optimisation: it is the only way to guarantee a url with nothing to strip
  //comes back untouched, `+` and `%20` and a missing `?` included.
  if (kept.length == all.length) return url;

  if (kept.isEmpty) return _withoutQuery(uri);

  //Rebuilding decodes and re-encodes every value, which normalises a few
  //things we do not fight: a space becomes `+` whether it arrived as `+` or as
  //`%20`, and a parameter with an empty value loses its `=` (`?y=` becomes
  //`?y`). Both round-trip to the same query as far as any server is concerned,
  //and this path is only reached once we are already rewriting the url.
  return uri.replace(queryParameters: kept).toString();
}

/// Whether [name] identifies the reader rather than the content.
bool _isTrackingParam(String name) {
  final lower = name.toLowerCase();
  if (_trackingParams.contains(lower)) return true;

  //Facebook emits its blob parameters indexed — `__cft__[0]`, `__xts__[0]` —
  //so an exact-name test misses every real one of them.
  final bracket = lower.indexOf('[');
  if (bracket <= 0) return false;

  return _trackingParams.contains(lower.substring(0, bracket));
}

/// [uri] as text with its query, and only its query, gone.
///
/// Neither `replace(queryParameters: {})` nor `replace(query: '')` can express
/// this: both leave `https://m.facebook.com/story.php?` — a bare trailing `?`
/// — and `replace(query: null)` means "keep the query" and changes nothing.
/// Reassembling through the `Uri` constructor instead is worse, because it
/// forces an authority on a url that has none (`mailto:a@b.com` comes back as
/// `mailto:///a@b.com`).
String _withoutQuery(Uri uri) {
  if (!uri.hasQuery) return uri.toString();

  //The query is the last thing before the fragment, so once the fragment is
  //off, dropping `?` plus the query text is an exact cut. `Uri.query` is the
  //encoded text as it appears in `toString`, so the arithmetic holds even for
  //values carrying percent escapes.
  final head = uri.removeFragment().toString();
  final base = head.substring(0, head.length - uri.query.length - 1);

  //`Uri.fragment` also hands back still-encoded text, so re-appending it is
  //byte-for-byte rather than a second round of encoding.
  return uri.hasFragment ? '$base#${uri.fragment}' : base;
}

/// The `fb:` scheme Facebook's mobile web uses to hand a link to its own app.
const String _appLinkScheme = 'fb';

/// The only `fb:` target this app knows how to serve itself.
const String _fullscreenVideoTarget = 'fullscreen_video';

/// Ids are numeric everywhere Facebook uses them. Anchored and ASCII-only on
/// purpose: the id is about to become a path segment on our own host, and a
/// value that is not plainly a run of digits — an escaped slash, a `..`, an
/// Arabic-Indic digit no Facebook id has ever contained — has no business being
/// interpolated into a url this app then navigates to.
final RegExp _numericId = RegExp(r'^[0-9]+$');

/// The web address that shows what an `fb://` link points at, or null.
///
/// Tapping a video in the feed navigates the webview to
/// `fb://fullscreen_video/<id>`, which no webview can load. Today that reaches
/// `launchInAppUrl` and leaves for a Custom Tab, which either bounces the user
/// into the official Facebook app or fails outright — the single thing someone
/// who installed this app has chosen against. Mapping the shape back onto
/// `https://<host>/reel/<id>/` keeps the video inside the webview.
///
/// [host] is a parameter rather than a read of the preferences so this stays
/// pure and testable, but also because only the caller knows which of the two
/// Facebook layouts is live: the touch site and `mbasic` are different hosts,
/// and sending a reel to the wrong one is a redirect at best.
///
/// Returns null for every shape not recognised, including an `fb://` target
/// this function has never seen and any other scheme. Null means "caller keeps
/// doing whatever it did before", so it has to be what an unknown link gets:
/// guessing a web url for an app link we cannot read would replace a working
/// hand-off with a 404.
Uri? facebookAppLinkTarget(Uri uri, {required String host}) {
  if (uri.scheme != _appLinkScheme) return null;

  //`Uri` lower-cases the scheme and the host while parsing, so both of these
  //comparisons are already case-insensitive.
  if (uri.host != _fullscreenVideoTarget) return null;

  //An empty host builds `https:///reel/<id>/`, which is not a page anything can
  //load, so it is treated as another shape we cannot serve.
  if (host.isEmpty) return null;

  final id = _fullscreenVideoId(uri);
  if (id == null) return null;

  //Built through the constructor, not interpolated into `Uri.parse`: the
  //constructor refuses a host that carries a path of its own, so a mistaken
  //[host] cannot smuggle extra segments in.
  return Uri(scheme: 'https', host: host, path: '/reel/$id/');
}

/// The video id carried by an `fb://fullscreen_video` link, or null.
String? _fullscreenVideoId(Uri uri) {
  //A trailing slash produces an empty last segment — `fb://fullscreen_video/1/`
  //parses to `['1', '']` — which would otherwise read as two segments and be
  //rejected as an unknown shape.
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

  if (segments.length > 1) return null;

  if (segments.length == 1) {
    final segment = segments.single;
    return _numericId.hasMatch(segment) ? segment : null;
  }

  //Some builds put the id in the query instead of the path. `id` is the one
  //observed most; `v` is the spelling the desktop video urls use, and it turns
  //up here too. The path form wins when both are present, since it is the one
  //Facebook's own player reads.
  final param = uri.queryParameters['id'] ?? uri.queryParameters['v'];
  if (param == null) return null;

  return _numericId.hasMatch(param) ? param : null;
}
