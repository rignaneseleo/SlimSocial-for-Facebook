import 'dart:convert';

/// Shortest label that may be matched as a *substring*.
///
/// A short substring appears all over Facebook's own chrome, so testing for one
/// inside a longer string produces false positives. Labels below this length are
/// not discarded: the filter script compares them against the candidate's whole
/// trimmed text instead, which cannot fire mid-sentence. CJK labels ("広告",
/// "광고") are genuinely two characters, so without that second path there would
/// be no ad detection at all in Chinese, Japanese or Korean.
const int kMinSponsoredLabelLength = 4;

/// How much longer than a label the string carrying it may be before it stops
/// looking like a label at all.
///
/// Facebook fuses two private-use glyphs into the live label and sprinkles bidi
/// marks through bylines; `clean` strips both, but the raw-text gate sees them,
/// so the allowance covers those four units plus the separator and punctuation a
/// byline puts around the word.
const int kSponsoredLabelSlack = 8;

/// Labels Facebook uses to mark a sponsored post, lowercase, one or more per
/// supported locale.
///
/// The label is rendered in the language of the *Facebook account*, which is
/// often not the language the app is running in, and a single feed can mix
/// several — so every known variant is bundled rather than just the active
/// locale's.
///
/// Values come from the `sponsored_keyword_fb` entries in `assets/lang/*.json`
/// plus the variants below. Matching is case-insensitive, and is a substring
/// test guarded by a length window for entries at or above
/// [kMinSponsoredLabelLength] and a whole-string comparison below it. A variant
/// that is wrong for some locale is inert rather than harmful. Still, prefer
/// deleting a doubtful label over guessing at one: every entry widens the
/// false-positive surface.
const List<String> kSponsoredLabels = [
  // The label the current mobile layout actually uses. Observed on a live feed
  // as the text node "Ad\u{F078B}\u{F17E1}" — the word plus two private-use
  // icon glyphs — and rendered in English even when the interface is not. Two
  // characters, so it is matched against the whole trimmed label and never as a
  // substring, which would fire on "Add friend", "Download" and half the feed.
  'ad',
  // Latin script
  'gesponsert',
  'gesponsord',
  'hirdetés',
  'patrocinado',
  'publicidad',
  'rėmėjas',
  'sponsede',
  'sponset',
  'sponsora',
  'sponsored',
  'sponsoreeritud',
  'sponsoreret',
  'sponsorisé',
  'sponsorisée',
  'sponsorizat',
  'sponsorizzato',
  'sponsorlu',
  'sponsoroidut',
  'sponsoroitu',
  'sponsorowane',
  'sponsrad',
  'sponsrat',
  'sponzorirano',
  'sponzorisano',
  'sponzorované',
  'sponzorováno',
  'szponzorált',
  'tài trợ',
  // Cyrillic
  'реклама',
  'спонсорирано',
  'спонсоровано',
  // Hebrew, Arabic, Persian, Urdu
  'ממומן',
  'تعاون',
  'حمایت شده',
  'رعاية',
  'ممول',
  // Indic. Punjabi, Gujarati and Kannada ship no `assets/lang` file, so the
  // runtime extra cannot supply them and this bundle is their only source.
  'प्रायोजित',
  'স্পনসরড',
  'ਸਰਪ੍ਰਸਤ',
  'સ્પોન્સર્ડ',
  'பரிந்துரைக்கப்பட்டது',
  'ప్రాయోజించబడిన',
  'ಪ್ರಾಯೋಜಿತ',
  'പ്രവര്‍ത്തിച്ചിരിക്കുന്നത്',
  // Thai
  'โฆษณา',
  // CJK — two characters, so matched as whole strings, not substrings
  '広告',
  'スポンサー',
  '赞助',
  '贊助',
  '광고',
  '스폰서',
];

/// Name of the JavaScript channel the filter reports its tally on.
///
/// The page posts the number of items hidden by each pass, and Dart keeps the
/// running total. Counting in Dart rather than in the page means the figure
/// survives navigations, which reset every global the script defines.
const String kAdCountChannelName = 'SlimAdCount';

/// Name of the JavaScript channel the filter reports its own health on.
///
/// Separate from [kAdCountChannelName] because the two payloads have nothing in
/// common and the tally is parsed as a bare integer: a diagnostic posted there
/// would be dropped as garbage, and an integer posted here would be forwarded
/// as an unknown signal.
const String kDiagnosticsChannelName = 'SlimDiag';

/// The post-container selector matched nothing on a page that was a feed.
///
/// The one signal that catches the failure this app cannot otherwise see:
/// Facebook rewrites the markup, [kPostSelector] stops matching, the filter
/// hides nothing, and nothing crashes — adverts simply come back.
const String kDiagNoPostsMatched = 'injection.no_posts_matched';

/// The post-container selector matched at least one post.
///
/// The denominator [kDiagNoPostsMatched] never had. On its own a count of
/// failures says nothing: six reports is indistinguishable from six-out-of-six
/// and six-out-of-six-thousand.
///
/// Raised once per process, like the failure signal, but sent from only 1 in
/// [kDiagSampleOneIn] of those processes, so the break rate is
/// `no_posts_matched / (no_posts_matched + 50 * posts_matched)`.
/// Sampled because the Sentry plan counts every event against one monthly
/// quota, and a success that fires for nearly every user would spend that
/// quota on the half of the picture nobody has to read event by event. A
/// failure is never sampled.
const String kDiagPostsMatched = 'injection.posts_matched';

/// How many processes raise a signal for each one that reports it.
///
/// A kind that is absent reports in full, which is every failure signal. Only
/// a success counted in the thousands belongs here.
const Map<String, int> kDiagSampleOneIn = {kDiagPostsMatched: 50};

/// A pass of the injected filter threw.
const String kDiagScriptThrew = 'injection.script_threw';

/// The user's own script threw.
///
/// Reported without any detail, and deliberately absent from
/// [kDiagnosticFields] so it can only ever be raised from Dart: the page must
/// not be able to claim the user's script failed, and the exception itself
/// quotes source we do not collect.
const String kDiagUserScriptThrew = 'injection.user_script_threw';

/// The observer found no filter to drive.
///
/// On Android a page exception does not come back through `runJavaScript`, so
/// a filter that failed to install is invisible from Dart. The observer runs
/// afterwards and is the only thing positioned to notice.
const String kDiagFilterMissing = 'injection.filter_missing';

/// Health signals the page may report, and the only fields each may carry.
///
/// Any script on the page can post on a channel the app registers, so what
/// arrives is treated as hostile input rather than as our own script talking to
/// us: a kind that is not a key here is dropped, and so is a field that is not
/// listed for its kind. That keeps a page that has noticed the channel from
/// using the app as a way out for its own text.
const Map<String, Set<String>> kDiagnosticFields = {
  kDiagNoPostsMatched: {'page', 'selector', 'dom_size'},
  kDiagPostsMatched: <String>{},
  kDiagScriptThrew: {'error'},
  kDiagFilterMissing: <String>{},
};

/// Exception types [kDiagScriptThrew] may name.
///
/// The type is all that travels. An exception's *message* is free text the page
/// gets to author — a thrown string, an overridden `toString`, a `TypeError`
/// quoting the expression that failed — and the app has no way to tell a fault
/// describing itself from a page writing into the report. Which of these five
/// threw is enough to tell a stale selector from a broken DOM API, and anything
/// outside the list arrives as [kDiagnosticOtherValue].
const Set<String> kDiagnosticErrorNames = {
  'TypeError',
  'ReferenceError',
  'RangeError',
  'SyntaxError',
  'Error',
};

/// What an unrecognised string field is reported as.
const String kDiagnosticOtherValue = 'other';

/// The only field a diagnostic may carry as a number.
///
/// Every other field is a string drawn from [kDiagnosticValues]. Without this
/// split, a page script could send any declared field as an integer and have it
/// pass unchecked: bounded, but still room to spell something out a byte at a
/// time over repeated loads.
const Set<String> kDiagnosticIntFields = {'dom_size'};

/// The complete set of values each string field may carry.
///
/// Every one of them is a constant this file put into the script, so no string
/// arriving on the channel has to be trusted: it is either one of these or it
/// is the page talking, and the page's own words never leave the device. The
/// numeric fields are bounded by [kDiagnosticIntLimit] instead.
const Map<String, Set<String>> kDiagnosticValues = {
  'error': kDiagnosticErrorNames,
  'page': {'feed'},
  'selector': {kPostSelector},
};

/// Largest number a diagnostic field may carry.
///
/// The one numeric field is a page size already rounded to hundreds by the
/// script. A larger number is not a bigger page, it is a channel with room to
/// spell something out in.
const int kDiagnosticIntLimit = 100000;

/// A health signal that arrived on [kDiagnosticsChannelName] and survived every
/// check, ready to be reported.
class Diagnostic {
  const Diagnostic(this.kind, this.data);

  /// A slug from [kDiagnosticFields], never a name the page chose.
  final String kind;

  /// Fields from [kDiagnosticFields], carrying values from
  /// [kDiagnosticValues] or numbers within [kDiagnosticIntLimit].
  final Map<String, Object?> data;
}

/// Reads a message posted on [kDiagnosticsChannelName], or returns null when it
/// is not a signal this app will forward.
///
/// The channel is registered into the page's own script world, so anything on
/// facebook.com can post to it and every part of what arrives is hostile input.
/// The page therefore chooses none of what leaves: the kind must be one of
/// [kDiagnosticFields]'s, the fields must be the ones listed for it, and each
/// value must be a constant this file itself put into the script — a string
/// that is not becomes [kDiagnosticOtherValue] rather than travelling. Nothing
/// the page authored ever reaches the payload.
///
/// Rejection is silent by design. Callers must describe a rejected message
/// rather than quote it: `debugPrint` output is collected as a breadcrumb on
/// whatever is reported next, so a log line that reproduces the payload hands
/// the page a second way off the device.
Diagnostic? parseDiagnostic(String message) {
  Object? decoded;
  try {
    decoded = jsonDecode(message);
  } on Object catch (_) {
    return null;
  }
  if (decoded is! Map) return null;

  final kind = decoded['kind'];
  final fields = kind is String ? kDiagnosticFields[kind] : null;
  if (kind is! String || fields == null) return null;

  final payload = decoded['data'];
  final data = <String, Object?>{};
  if (payload is Map) {
    for (final field in fields) {
      final value = payload[field];
      if (kDiagnosticIntFields.contains(field)) {
        //a page size the script already rounded to hundreds, so a number
        //outside that range is not a bigger page — it is room to spell
        //something out in
        if (value is! int || value < 0 || value > kDiagnosticIntLimit) continue;
        data[field] = value;
      } else if (value is String) {
        final allowed = kDiagnosticValues[field] ?? const <String>{};
        data[field] =
            allowed.contains(value) ? value : kDiagnosticOtherValue;
      }
    }
  }
  return Diagnostic(kind, data);
}

/// When, after a load, the feed is checked for rendered posts.
///
/// Three attempts rather than one. A single 8 s shot cannot tell a stale
/// selector from a low-end phone that simply had not painted yet — and the
/// majority of this app's users are on exactly those devices. Only a page that
/// still has no posts at 25 s is reported.
const List<int> kFeedHealthDelaysMs = [8000, 15000, 25000];

/// How many `div`s the page must hold before its post count means anything.
///
/// An interstitial, a checkpoint, a half-loaded page: all have no posts, and
/// none of them says a thing about the selector. A rendered feed is in the
/// hundreds, so this only has to clear the pages that never really arrived.
const int kFeedHealthMinDivs = 150;

/// Paths that are the news feed and nothing else.
///
/// Deliberately just these two. Zero posts is the *normal* state of a photo
/// view, a group, a profile, Marketplace and every settings page, so anything
/// wider than an exact match on the two addresses the app itself opens turns
/// this signal into noise that would drown the one case it exists for.
const List<String> kFeedPaths = ['/', '/home.php'];

/// Hosts whose layout [kPostSelector] was measured against.
///
/// Matched exactly, and deliberately just the one the app opens by default.
/// Basic mode loads `mbasic.facebook.com`, and the basic layout carries no
/// `data-tracking-duration-id` anywhere: zero matched posts there is the
/// permanent and correct answer, so a host test wide enough to include it would
/// report a stale selector once per launch for every basic-mode user, forever —
/// keeping the issue open so that the real breakage this signal exists for
/// arrives as a counter moving rather than as something new. A desktop layout,
/// which a custom desktop user agent gets served, is the same story.
///
/// Failing the other way costs only the signal: if Facebook ever moves the
/// touch layout to another host, nothing is reported until this list is
/// updated, and nothing else in the filter depends on it.
const List<String> kFeedHosts = ['touch.facebook.com'];

/// Markers Facebook puts on the descendants of a sponsored unit.
///
/// Checked before any text matching: they do not depend on the viewer's
/// language and a single `querySelector` is far cheaper than walking every
/// descendant's text content.
///
/// Every href marker is pinned to a Facebook address — a relative path, or the
/// host written out — because this tier is tested against the whole post
/// container and a match takes the post out of the feed without a trace. A bare
/// `a[href*="sponsored"]` used to be here and matched any outbound link whose
/// URL merely contained the word, so an organic post linking to a site's own
/// sponsored-content policy disappeared with no way for the reader to find it.
const String _sponsoredMarkerSelector =
    '[data-ft*="is_sponsored"], [data-xt-vimp], a[href^="/ads/about/"], '
    'a[href*="facebook.com/ads/about/"], a[href^="/"][href*="client_token="]';

/// Containers that hold a single feed post.
///
/// Measured against the live mobile layout (Task 1 Step 5): 30 matches, while
/// `article` and `[role="article"]` matched nothing at all. `article` was in an
/// earlier draft of this selector and is deliberately gone — it was dead weight
/// rather than a fallback.
///
/// Public because it is also the only value the `selector` diagnostic field may
/// carry, and [kDiagnosticValues] has to know it to say so.
const String kPostSelector = 'div[data-tracking-duration-id]';

/// Headings that introduce a "People You May Know" carousel.
///
/// Matched against a whole trimmed heading, not as a substring, so a post that
/// merely says the phrase is left alone.
///
/// The current layout renders this chrome in English even when the interface is
/// another language — the same thing it does with the "Ad" label — so the
/// English entry does most of the work and the rest are insurance.
const List<String> kPeopleYouMayKnowLabels = [
  'people you may know',
  'persone che potresti conoscere',
  'personas que quizá conozcas',
  'personnes que vous pourriez connaître',
  'personen, die du kennen könntest',
  'pessoas que talvez você conheça',
  'mensen die je misschien kent',
  'osoby, które możesz znać',
  'люди, которых вы можете знать',
];

/// Builds the feed filter and installs it as `window.slimRemoveAds`.
///
/// Advert detection runs cheapest-first and stops at the first hit:
///   1. the post's own `data-ft` attribute
///   2. a descendant carrying one of the sponsored markers
///   3. a short standalone text label
///
/// In practice only the third fires: the recon found no `data-ft` or
/// `data-xt-vimp` anywhere on the served markup. The first two are kept as
/// forward compatibility.
///
/// A matched post is taken out of layout entirely — display, inline height and
/// `data-actual-height` all zeroed — with the originals stashed in
/// `data-slim-*` attributes so the change can be undone. It leaves no
/// placeholder: the running total reported over [kAdCountChannelName] is how
/// the app shows the filter is working.
///
/// Collapsing a post above the viewport takes the height it gave up off the
/// scroll offset in the same turn, so the feed does not slide under a reader who
/// is scrolling while the pass runs.
///
/// The script also reports on its own health over [kDiagnosticsChannelName]:
/// the selectors here match markup Facebook rewrites without warning, and when
/// they stop matching nothing throws and nothing crashes. Those signals carry
/// counts and this file's own selector strings — never anything read out of the
/// page.
String adFilterScript({
  required String placeholderText,
  List<String> extraLabels = const [],
  bool hideSponsored = true,
  bool hidePeopleYouMayKnow = false,
}) {
  // A runtime extra is the app locale's own label. It must not be dropped for
  // being short: in a CJK locale it is exactly the two-character case, which is
  // precisely when it matters most. Short entries go to the exact-match list.
  // With sponsored hiding off the label sets are emptied rather than the script
  // being skipped, because "People you may know" may still want the same walk.
  final all = <String>{
    if (hideSponsored) ...[
      ...kSponsoredLabels,
      for (final label in extraLabels)
        if (label.trim().length >= 2) label.trim().toLowerCase(),
    ],
  };

  final substringLabels =
      all.where((l) => l.length >= kMinSponsoredLabelLength).toList();
  final exactLabels =
      all.where((l) => l.length < kMinSponsoredLabelLength).toList();

  // Cheap upper bound on the length of a string worth testing at all, derived
  // rather than fixed because a label longer than the bound is rejected by the
  // very gates meant to protect it — that is how the 26-unit Malayalam entry
  // became unreachable under a hard-coded 25. It only decides what reaches the
  // matcher; each label carries its own tighter bound there.
  final maxLength = all.fold<int>(
        kMinSponsoredLabelLength,
        (longest, l) => l.length > longest ? l.length : longest,
      ) +
      kSponsoredLabelSlack;

  return '''
(function () {
  var LABELS = ${jsonEncode(substringLabels)};
  var EXACT_LABELS = ${jsonEncode(exactLabels)};
  var PYMK_LABELS = ${jsonEncode(hidePeopleYouMayKnow ? kPeopleYouMayKnowLabels : const <String>[])};
  var HIDE_SPONSORED = $hideSponsored;
  var MIN_LEN = $kMinSponsoredLabelLength;
  var MAX_LEN = $maxLength;
  var SLACK = $kSponsoredLabelSlack;
  var PLACEHOLDER = ${jsonEncode(placeholderText)};
  var POST_SELECTOR = ${jsonEncode(kPostSelector)};
  var FEED_PATHS = ${jsonEncode(kFeedPaths)};
  var FEED_HOSTS = ${jsonEncode(kFeedHosts)};
  var ERROR_NAMES = ${jsonEncode(kDiagnosticErrorNames.toList())};
  var OTHER = ${jsonEncode(kDiagnosticOtherValue)};
  var HEALTH_DELAYS_MS = ${jsonEncode(kFeedHealthDelaysMs)};
  var MIN_DIVS = $kFeedHealthMinDivs;
  var memo = null;
  var reported = {};
  var sawPosts = false;

  // Every diagnostic goes through here, and every one of them is reported at
  // most once per page load. The filter runs on every debounced mutation, so a
  // condition that holds — a stale selector, a pass that throws on each call —
  // holds on all of them: without this gate one broken page load would post
  // thousands of identical messages while the user scrolls.
  function report(kind, data) {
    if (reported[kind]) return;
    reported[kind] = true;
    try {
      window.$kDiagnosticsChannelName.postMessage(
        JSON.stringify({ kind: kind, data: data })
      );
    } catch (e) {}
  }

  // Only the exception's type travels, and only if it is one this build knows.
  // The message is free text the page gets to author — a thrown string, an
  // overridden toString, a TypeError quoting the expression that failed — and
  // nothing here can tell a fault describing itself from the page writing into
  // the report. Which type threw is enough to triage; the words are not needed.
  function describe(e) {
    var name = '';
    try {
      if (e && e.name) name = String(e.name);
    } catch (ignored) {}
    for (var i = 0; i < ERROR_NAMES.length; i++) {
      if (name === ERROR_NAMES[i]) return { error: name };
    }
    return { error: OTHER };
  }

  function isFeedPage() {
    try {
      // The host, not merely the domain: POST_SELECTOR describes the touch
      // layout only. On the basic layout it matches nothing by design, so a
      // wider test would report a stale selector on every launch of every
      // basic-mode install and bury the breakage it exists to catch.
      if (FEED_HOSTS.indexOf(String(location.hostname || '')) === -1) {
        return false;
      }
      if (FEED_PATHS.indexOf(location.pathname) === -1) return false;

      // Signed out, Facebook serves the login form at the feed's own address.
      // No posts there is correct, not a stale selector — and without this the
      // signal would fire on every launch of every signed-out install, which is
      // the one population guaranteed to see it.
      if (document.querySelector('input[type="password"], input[name="pass"]')) {
        return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  // Zero posts is the normal state of most of Facebook and of the first
  // seconds of any load, so the check runs once, late, and only where a feed
  // was genuinely expected — on both sides of the wait, since the page can
  // navigate in place while it runs.
  function checkFeedHealth(isFinal) {
    // Earlier attempts exist only to give a slow device a chance to paint and
    // set sawPosts. Reporting from one of them is the false positive the
    // schedule exists to remove, so only the last attempt may speak.
    if (!isFinal) return;
    if (!isFeedPage()) return;
    if (document.readyState !== 'complete') return;

    var divs = document.getElementsByTagName('div').length;
    if (divs < MIN_DIVS) return;

    // Both signals leave from here, past the same gates, so the pair describes
    // one population and the ratio between them means something. A numerator
    // counted against a different denominator would not.
    if (sawPosts) {
      report(${jsonEncode(kDiagPostsMatched)}, {});
      return;
    }

    report(${jsonEncode(kDiagNoPostsMatched)}, {
      page: 'feed',
      selector: POST_SELECTOR,
      // Bucketed. The number is only ever read as "did the page render", and a
      // rounded one cannot be matched back to a particular page or person.
      dom_size: Math.floor(divs / 100) * 100
    });
  }

  // Facebook fuses the label with icon glyphs from a private-use font, so the
  // node reads "Ad\\uF078B\\uF17E1" rather than "Ad", and bidi marks are
  // sprinkled through bylines. Without stripping both, no label ever compares
  // equal to anything and the exact-match tier is dead on arrival.
  function clean(text) {
    return text
      .replace(/[\\uE000-\\uF8FF]/g, '')
      .replace(/[\\uDB80-\\uDBFF][\\uDC00-\\uDFFF]/g, '')
      .replace(/[\\u200E\\u200F\\u202A-\\u202E\\u2066-\\u2069]/g, '')
      .trim();
  }

  // A label may only be sought in a string it could plausibly be the label of.
  // The slack is what a byline adds around it — the advertiser's name, a
  // separator, the sponsored chip's own punctuation.
  function fits(text, label) {
    return text.length < label.length + SLACK;
  }

  function isSponsoredLabel(text) {
    if (!text) return false;
    var lower = clean(text).toLowerCase();
    if (!lower) return false;

    // CJK labels are two characters, so they are compared against the whole
    // trimmed string. An exact match cannot fire inside prose, which is what
    // makes a two-character label safe to test at all.
    for (var e = 0; e < EXACT_LABELS.length; e++) {
      if (lower === EXACT_LABELS[e]) return true;
    }

    // Everything else is a substring test, bounded so that an ordinary post
    // merely mentioning the word is not hidden along with the real ads. The
    // bound is per label, not global: a single cap wide enough for the longest
    // label would let a sentence of that length match the shortest one.
    if (lower.length < MIN_LEN || lower.length >= MAX_LEN) return false;

    // Once one language has matched, every later post in the same feed is
    // almost certainly the same language, so try that one first.
    if (memo && fits(lower, memo) && lower.indexOf(memo) !== -1) return true;
    for (var i = 0; i < LABELS.length; i++) {
      if (!fits(lower, LABELS[i])) continue;
      if (lower.indexOf(LABELS[i]) !== -1) {
        memo = LABELS[i];
        return true;
      }
    }
    return false;
  }

  function isSponsoredPost(post) {
    // Emptying the label lists is not enough on its own: the attribute tiers
    // below do not consult them, so they would still hide adverts with the
    // setting switched off.
    if (!HIDE_SPONSORED) return false;

    var dataFt = post.getAttribute('data-ft') || '';
    if (dataFt.indexOf('is_sponsored') !== -1) return true;
    if (dataFt.indexOf('should_log_endpoint_info') !== -1) return true;

    if (post.querySelector(${jsonEncode(_sponsoredMarkerSelector)})) return true;

    // `span` only. Measured on a 55-post feed: 'span, div, a' materialises 3929
    // nodes in 5.1ms, 'span' finds the same labels in 724 nodes and 0.5ms — and
    // the advert label is the second span in the post, so div and a were pure
    // waste on every pass.
    var candidates = post.querySelectorAll('span');
    for (var i = 0; i < candidates.length; i++) {
      var text = (candidates[i].textContent || '').trim();
      // Skip empty nodes and anything long enough to be post body rather than a
      // label. The lower bound lives in isSponsoredLabel, which applies it only
      // to substring matching: a two-character CJK label has to reach it.
      if (text.length === 0 || text.length >= MAX_LEN) continue;
      if (isSponsoredLabel(text)) return true;
    }
    return false;
  }

  // Facebook renders a post's spans empty and streams the text in over several
  // frames, so neither an empty post nor a half-filled one is evidence that the
  // label has arrived: a post whose byline is up but whose sponsored chip lands
  // a frame later would be retired before it ever looked like an advert.
  //
  // A post is settled once the count of spans holding text stops moving between
  // passes. A label arriving late changes the count and buys another look; a
  // post that never fills in — media only — matches itself on the second pass
  // and retires, so the skip list still bounds the work on a long feed.
  function isSettled(post) {
    var els = post.querySelectorAll('span');
    var rendered = 0;
    for (var i = 0; i < els.length; i++) {
      if ((els[i].textContent || '').trim().length > 0) rendered++;
    }
    var seen = post.getAttribute('data-slim-spans');
    post.setAttribute('data-slim-spans', rendered);
    return seen !== null && +seen === rendered;
  }

  // Which element actually scrolls has to be found rather than assumed: the
  // touch layout renders the feed inside a div[data-type="vscroller"] that
  // scrolls on its own, while the app also scrolls the document itself — the
  // screens save and restore position through `getScrollPosition` and
  // `scrollTo`, which are the document's. An ancestor only qualifies if it is
  // both allowed to scroll and genuinely overflowing: an `overflow-y: auto` box
  // that fits its content moves nothing, and correcting its offset would throw
  // the correction away while the real scroller keeps the jump.
  function scrollerFor(post) {
    var node = post.parentElement;
    while (node && node !== document.body && node !== document.documentElement) {
      var overflowY = '';
      try {
        overflowY = window.getComputedStyle(node).overflowY;
      } catch (e) {}
      var scrollable =
        overflowY === 'auto' || overflowY === 'scroll' || overflowY === 'overlay';
      if (scrollable && node.scrollHeight > node.clientHeight) {
        return { el: node, win: null };
      }
      node = node.parentElement;
    }
    // The document scroller reports its offset on the window, not on itself.
    return {
      el: document.scrollingElement || document.documentElement,
      win: window
    };
  }

  function collapse(post) {
    post.classList.add('slim-ad-handled');

    // Taking a post out of layout above the viewport used to slide the whole
    // feed up under the reader's thumb. That is the common case rather than the
    // corner one: the filter re-runs as posts stream in below and the observer
    // fires while the reader scrolls, so the advert being retired has usually
    // been scrolled past already — and a sponsored post is several hundred
    // pixels leaving layout at once, which lands the reader mid-way through a
    // different post. Measured here, given back to the offset after the hide.
    var anchor = null;
    try {
      var scroller = scrollerFor(post);
      var viewportTop = scroller.win
        ? 0
        : scroller.el.getBoundingClientRect().top;
      // Two of the three positions need nothing done. A post below the fold
      // takes its height out of a region the reader cannot see. A post still on
      // screen is the one being looked at, and there is no offset that both
      // removes it and leaves the view still. Only a post entirely above the
      // viewport shortens the run of content the offset is measured against,
      // and that is the one that drags the page.
      if (post.getBoundingClientRect().bottom <= viewportTop) {
        // Both numbers are read now, before anything is hidden. The offset
        // matters as much as the height: Android WebView ships Chromium's
        // scroll anchoring switched on (`overflow-anchor` defaults to `auto`,
        // and nothing here sets it otherwise), so the engine may move the
        // offset by itself the moment layout is recomputed. Reading the offset
        // afterwards and subtracting from *that* counted the engine's own
        // correction a second time and threw the feed a whole advert further up
        // than it started — measured in Chromium 148 on both scroller kinds,
        // and again, without anchoring, whenever the reader sat near the end of
        // the feed and the engine clamped the offset to the shorter document.
        anchor = {
          scroller: scroller,
          height: scroller.el.scrollHeight,
          offset: scroller.win ? scroller.win.scrollY : scroller.el.scrollTop
        };
      }
    } catch (e) {}

    // The post is removed from layout below, so it occupies nothing. Telling
    // the virtualising scroller it is still 60px tall leaves its model
    // disagreeing with the page by that much for every advert hidden.
    var height = post.getAttribute('data-actual-height');
    if (height !== null) {
      post.setAttribute('data-slim-height-original', height);
      post.setAttribute('data-actual-height', '0');
    }

    // data-actual-height is only what the virtualising scroller reads. The box
    // the user sees is sized by an inline `height:667px` on the post itself, so
    // without shrinking that too the advert is replaced by an empty container
    // of exactly the same size — a large blank gap instead of an advert.
    if (post.style.height) {
      post.setAttribute('data-slim-style-height', post.style.height);
      post.style.height = '0px';
    }
    post.style.minHeight = '0';
    post.style.overflow = 'hidden';

    // Hide the real content without detaching it: Facebook's own scripts still
    // hold references into this subtree.
    var child = post.firstElementChild;
    while (child) {
      child.style.display = 'none';
      child = child.nextElementSibling;
    }

    // The advert leaves no trace. An earlier version left a labelled strip
    // here, but a band of grey every few posts is its own kind of clutter, and
    // the running total the app reports is a better way to show the filter is
    // working than a placeholder in the feed.
    post.style.display = 'none';

    // Hiding the advert is the job; not jumping is only the improvement — so
    // the restore is guarded on its own, and a scroller that refuses to be
    // measured or written still loses its advert.
    try {
      if (anchor) {
        // Asking for scrollHeight here forces the layout the hide just
        // invalidated. That is deliberate, and it has to happen in this same
        // synchronous block: a correction deferred to a later frame is a
        // correction the reader watches happen.
        var lost = anchor.height - anchor.scroller.el.scrollHeight;
        if (lost > 0) {
          var win = anchor.scroller.win;
          // Written as an absolute position derived from the pre-hide offset,
          // never as a delta applied to whatever the offset reads now. The
          // content above the viewport got `lost` shorter, so this is where the
          // offset has to land for the view to hold still — and stating it
          // absolutely means it lands there whether or not the engine already
          // moved the offset on its own. See the note on scroll anchoring where
          // the anchor is taken.
          var next = anchor.offset - lost;
          // A scroller can shed more height than there was offset above it —
          // the feed's first advert, with the reader barely past it — and a
          // negative offset bounces on one engine and is ignored on the next.
          if (next < 0) next = 0;
          if (win) {
            // `scroll-behavior: smooth` anywhere up the tree would turn the
            // two-argument form into an animation, which is the jump this is
            // meant to prevent, arriving slowly. The object form can say
            // otherwise; older WebViews that reject it fall back.
            try {
              win.scrollTo({ top: next, left: win.scrollX, behavior: 'instant' });
            } catch (e) {
              win.scrollTo(win.scrollX, next);
            }
          } else {
            anchor.scroller.el.scrollTop = next;
          }
        }
      }
    } catch (e) {}
  }

  function isPeopleYouMayKnow(post) {
    if (!PYMK_LABELS.length) return false;
    var els = post.querySelectorAll('span');
    for (var i = 0; i < els.length; i++) {
      if (els[i].children.length) continue;
      var t = clean(els[i].textContent || '').toLowerCase();
      if (!t || t.length > 40) continue;
      if (PYMK_LABELS.indexOf(t) !== -1) return true;
    }
    return false;
  }

  function runPass() {
    var handled = 0;
    var ads = 0;
    var posts = document.querySelectorAll(POST_SELECTOR);

    // One post seen at any point in this page's life is enough to say the
    // selector still matches the layout, whatever a later pass finds: the feed
    // empties itself as the scroller recycles nodes.
    if (posts.length > 0) sawPosts = true;

    for (var i = 0; i < posts.length; i++) {
      var post = posts[i];
      if (post.classList.contains('slim-ad-handled')) continue;

      // Already examined and cleared. Without this every pass re-walks every
      // post in the document, so the cost grows as the feed grows and each
      // scroll burst pays for the whole feed again. Only marked once the post
      // has stopped hydrating, so one still filling in gets looked at again.
      if (post.classList.contains('slim-ad-checked')) continue;

      // A friend carousel is not an advert, but it is taken out of the page the
      // same way: the scroller's bookkeeping, and the scroll correction for the
      // height that disappears, are about the hole left behind rather than about
      // why the post went.
      if (isPeopleYouMayKnow(post)) {
        collapse(post);
        handled++;
        continue;
      }

      if (!isSponsoredPost(post)) {
        if (isSettled(post)) post.classList.add('slim-ad-checked');
        continue;
      }
      collapse(post);
      handled++;
      ads++;
    }

    // Report only the adverts this pass hid: the tally is shown as the ad
    // filter's own count, so a hidden friend carousel must not swell a number
    // the user reads next to a switch that may well be off. Dart accumulates,
    // so a reload or an in-page navigation does not restart from zero.
    if (ads > 0) {
      try {
        window.$kAdCountChannelName.postMessage(String(ads));
      } catch (e) {}
    }

    return handled;
  }

  window.slimRemoveAds = function () {
    // A throw used to end the pass in silence — the observer's own try/catch
    // swallowed it — so the adverts came back and nothing said why. Reported
    // once, then swallowed on purpose: a pass that fails on this mutation may
    // well succeed on the next, and taking the observer down guarantees it
    // never gets the chance.
    try {
      return runPass();
    } catch (e) {
      report(${jsonEncode(kDiagScriptThrew)}, describe(e));
      return 0;
    }
  };

  window.slimRemoveAds();

  if (isFeedPage()) {
    try {
      var lastDelay = HEALTH_DELAYS_MS.length - 1;
      for (var d = 0; d < HEALTH_DELAYS_MS.length; d++) {
        // Only the last attempt reports. The earlier ones exist so that a feed
        // which paints late clears sawPosts before anything is claimed.
        (function (isFinal) {
          setTimeout(function () {
            checkFeedHealth(isFinal);
          }, HEALTH_DELAYS_MS[d]);
        })(d === lastDelay);
      }
    } catch (e) {}
  }
})();
''';
}
