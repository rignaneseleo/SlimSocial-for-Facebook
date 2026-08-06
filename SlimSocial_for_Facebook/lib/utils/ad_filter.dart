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
  // Indic
  'प्रायोजित',
  'স্পনসরড',
  'பரிந்துரைக்கப்பட்டது',
  'ప్రాయోజించబడిన',
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

/// Markers Facebook puts on the descendants of a sponsored unit.
///
/// Checked before any text matching: they do not depend on the viewer's
/// language and a single `querySelector` is far cheaper than walking every
/// descendant's text content.
const String _sponsoredMarkerSelector =
    '[data-ft*="is_sponsored"], [data-xt-vimp], a[href*="/ads/about/"], '
    'a[href*="client_token="], a[href*="sponsored"]';

/// Containers that hold a single feed post.
///
/// Measured against the live mobile layout (Task 1 Step 5): 30 matches, while
/// `article` and `[role="article"]` matched nothing at all. `article` was in an
/// earlier draft of this selector and is deliberately gone — it was dead weight
/// rather than a fallback.
const String _postSelector = 'div[data-tracking-duration-id]';

/// Builds the ad-hiding script and installs it as `window.slimRemoveAds`.
///
/// Detection runs cheapest-first and stops at the first hit:
///   1. the post's own `data-ft` attribute
///   2. a descendant carrying one of the sponsored markers
///   3. a short standalone text label, bounded to 4..24 characters
///
/// A matched post is collapsed, not emptied: its children are hidden in place
/// and `data-actual-height` is rewritten so the virtualising scroller keeps
/// working, with the original value stashed so the change can be undone.
String adFilterScript({
  required String placeholderText,
  List<String> extraLabels = const [],
}) {
  // A runtime extra is the app locale's own label. It must not be dropped for
  // being short: in a CJK locale it is exactly the two-character case, which is
  // precisely when it matters most. Short entries go to the exact-match list.
  final all = <String>{
    ...kSponsoredLabels,
    for (final label in extraLabels)
      if (label.trim().length >= 2) label.trim().toLowerCase(),
  };

  final substringLabels =
      all.where((l) => l.length >= kMinSponsoredLabelLength).toList();
  final exactLabels =
      all.where((l) => l.length < kMinSponsoredLabelLength).toList();

  return '''
(function () {
  var LABELS = ${jsonEncode(substringLabels)};
  var EXACT_LABELS = ${jsonEncode(exactLabels)};
  var MIN_LEN = $kMinSponsoredLabelLength;
  var MAX_LEN = 25;
  var PLACEHOLDER = ${jsonEncode(placeholderText)};
  var memo = null;

  function isSponsoredLabel(text) {
    if (!text) return false;
    var lower = text.toLowerCase();

    // CJK labels are two characters, so they are compared against the whole
    // trimmed string. An exact match cannot fire inside prose, which is what
    // makes a two-character label safe to test at all.
    for (var e = 0; e < EXACT_LABELS.length; e++) {
      if (lower === EXACT_LABELS[e]) return true;
    }

    // Everything else is a substring test, bounded so that an ordinary post
    // merely mentioning the word is not hidden along with the real ads.
    if (lower.length < MIN_LEN || lower.length >= MAX_LEN) return false;

    // Once one language has matched, every later post in the same feed is
    // almost certainly the same language, so try that one first.
    if (memo && lower.indexOf(memo) !== -1) return true;
    for (var i = 0; i < LABELS.length; i++) {
      if (lower.indexOf(LABELS[i]) !== -1) {
        memo = LABELS[i];
        return true;
      }
    }
    return false;
  }

  function isSponsoredPost(post) {
    var dataFt = post.getAttribute('data-ft') || '';
    if (dataFt.indexOf('is_sponsored') !== -1) return true;
    if (dataFt.indexOf('should_log_endpoint_info') !== -1) return true;

    if (post.querySelector(${jsonEncode(_sponsoredMarkerSelector)})) return true;

    var candidates = post.querySelectorAll('span, div, a');
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

  function collapse(post) {
    post.classList.add('slim-ad-handled');

    var height = post.getAttribute('data-actual-height');
    if (height !== null) {
      post.setAttribute('data-slim-height-original', height);
      post.setAttribute('data-actual-height', '60');
    }

    // Hide the real content without detaching it: Facebook's own scripts still
    // hold references into this subtree.
    var child = post.firstElementChild;
    while (child) {
      child.style.display = 'none';
      child = child.nextElementSibling;
    }

    var stub = document.createElement('div');
    stub.className = 'slim-ad-placeholder';
    stub.textContent = PLACEHOLDER;
    post.appendChild(stub);
  }

  window.slimRemoveAds = function () {
    var handled = 0;
    var posts = document.querySelectorAll(${jsonEncode(_postSelector)});
    for (var i = 0; i < posts.length; i++) {
      var post = posts[i];
      if (post.classList.contains('slim-ad-handled')) continue;
      if (!isSponsoredPost(post)) continue;
      collapse(post);
      handled++;
    }
    return handled;
  };

  window.slimRemoveAds();
})();
''';
}
