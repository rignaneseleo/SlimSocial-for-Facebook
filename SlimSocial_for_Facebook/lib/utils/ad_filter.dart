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

/// Name of the JavaScript channel the filter reports its tally on.
///
/// The page posts the number of items hidden by each pass, and Dart keeps the
/// running total. Counting in Dart rather than in the page means the figure
/// survives navigations, which reset every global the script defines.
const String kAdCountChannelName = 'SlimAdCount';

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

  return '''
(function () {
  var LABELS = ${jsonEncode(substringLabels)};
  var EXACT_LABELS = ${jsonEncode(exactLabels)};
  var PYMK_LABELS = ${jsonEncode(hidePeopleYouMayKnow ? kPeopleYouMayKnowLabels : const <String>[])};
  var HIDE_SPONSORED = $hideSponsored;
  var MIN_LEN = $kMinSponsoredLabelLength;
  var MAX_LEN = 25;
  var PLACEHOLDER = ${jsonEncode(placeholderText)};
  var memo = null;

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

  function collapse(post) {
    post.classList.add('slim-ad-handled');

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

  window.slimRemoveAds = function () {
    var handled = 0;
    var posts = document.querySelectorAll(${jsonEncode(_postSelector)});
    for (var i = 0; i < posts.length; i++) {
      var post = posts[i];
      if (post.classList.contains('slim-ad-handled')) continue;

      // Already examined and cleared. Without this every pass re-walks every
      // post in the document, so the cost grows as the feed grows and each
      // scroll burst pays for the whole feed again. Only marked once the post
      // has actually rendered some text, so a placeholder that is still filling
      // in gets looked at again on the next pass.
      if (post.classList.contains('slim-ad-checked')) continue;

      // A friend carousel is not an advert, so it is hidden outright rather
      // than collapsed behind the "ad removed" stub.
      if (isPeopleYouMayKnow(post)) {
        post.classList.add('slim-ad-handled');
        post.style.display = 'none';
        handled++;
        continue;
      }

      if (!isSponsoredPost(post)) {
        if (post.querySelector('span')) post.classList.add('slim-ad-checked');
        continue;
      }
      collapse(post);
      handled++;
    }

    // Report only what this pass hid. Dart accumulates, so a reload or an
    // in-page navigation does not restart the count from zero.
    if (handled > 0) {
      try {
        window.$kAdCountChannelName.postMessage(String(handled));
      } catch (e) {}
    }

    return handled;
  };

  window.slimRemoveAds();
})();
''';
}
