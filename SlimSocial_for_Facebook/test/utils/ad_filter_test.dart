import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:slimsocial_for_facebook/utils/ad_filter.dart';

void main() {
  group('kSponsoredLabels', () {
    test('is not empty', () {
      expect(kSponsoredLabels, isNotEmpty);
    });

    test('is entirely lowercase so matching can be case-insensitive', () {
      for (final label in kSponsoredLabels) {
        expect(label, label.toLowerCase(), reason: '"$label" is not lowercase');
      }
    });

    test('has no duplicates', () {
      expect(kSponsoredLabels.toSet().length, kSponsoredLabels.length);
    });

    test('has no stray surrounding whitespace', () {
      for (final label in kSponsoredLabels) {
        expect(label, label.trim(), reason: '"$label" has stray whitespace');
      }
    });

    test('short labels exist and are the CJK ones', () {
      // CJK ad labels are genuinely two characters ("広告", "광고"), so they
      // cannot clear the substring floor. They are not dropped — the filter
      // script matches anything below the floor as a whole string instead,
      // which is safer than a two-character substring test anyway. This asserts
      // the split is real, because an empty short list would silently mean no
      // CJK detection.
      final short =
          kSponsoredLabels.where((l) => l.length < kMinSponsoredLabelLength);

      expect(short, isNotEmpty);
      expect(short, contains('広告'));
      expect(short, contains('광고'));
    });

    test('no label is a single character', () {
      // One character would match far too much even as an exact string.
      for (final label in kSponsoredLabels) {
        expect(label.length, greaterThanOrEqualTo(2), reason: '"$label"');
      }
    });

    test('covers the scripts used across the supported locales', () {
      expect(kSponsoredLabels, contains('sponsored'));
      expect(kSponsoredLabels, contains('sponsorizzato'));
      expect(kSponsoredLabels, contains('gesponsert'));
      expect(kSponsoredLabels, contains('patrocinado'));
      expect(kSponsoredLabels, contains('реклама'));
      expect(kSponsoredLabels, contains('広告'));
      expect(kSponsoredLabels, contains('광고'));
    });

    test('bundles the Indic labels no lang file can supply', () {
      // Punjabi, Gujarati and Kannada have no `assets/lang` entry, so the
      // runtime extra cannot put them back: dropping them from the bundle
      // takes label detection away from those accounts entirely.
      expect(kSponsoredLabels, contains('ਸਰਪ੍ਰਸਤ'));
      expect(kSponsoredLabels, contains('સ્પોન્સર્ડ'));
      expect(kSponsoredLabels, contains('ಪ್ರಾಯೋಜಿತ'));
    });
  });

  final script = adFilterScript(
    placeholderText: 'Ad removed',
    extraLabels: const ['werbung'],
  );

  group('adFilterScript detection tiers', () {
    test('checks the post attribute before anything else', () {
      expect(script, contains('is_sponsored'));
      expect(script, contains('should_log_endpoint_info'));
    });

    test('checks the descendant markers Facebook puts on ad units', () {
      expect(script, contains('data-xt-vimp'));
      expect(script, contains('/ads/about/'));
    });

    test('bounds substring matching so prose mentioning the word is spared', () {
      expect(script, contains('lower.length < MIN_LEN'));
      expect(script, contains('lower.length >= MAX_LEN'));
    });

    test('leaves every bundled label inside the length window', () {
      // Both gates reject at `>= MAX_LEN`, so a label at or above the bound can
      // never match no matter how many locales carry it.
      final maxLen = _maxLen(script);

      for (final label in kSponsoredLabels) {
        expect(
          label.length,
          lessThan(maxLen),
          reason: '"$label" is $maxLen units or longer and can never match',
        );
      }
    });

    test('bounds each label by its own length, not by the longest one', () {
      // The global cap has to clear the longest label bundled, which on its own
      // would let a sentence that long match the shortest one: "sponsored" is 9
      // units, and a 30-unit line of prose containing it is not an advert.
      expect(script, contains('function fits(text, label)'));
      expect(script, contains('text.length < label.length + SLACK'));
      expect(script, contains('if (!fits(lower, LABELS[i])) continue;'));
      expect(script, contains('if (memo && fits(lower, memo)'));

      final shortest = kSponsoredLabels
          .where((l) => l.length >= kMinSponsoredLabelLength)
          .map((l) => l.length)
          .reduce((a, b) => a < b ? a : b);

      // 25 was the fixed cap this replaced, and it was already wide enough to
      // swallow a short sentence. Whatever the longest label drags the global
      // bound up to, the shortest one has to stay well under that.
      expect(shortest + kSponsoredLabelSlack, lessThan(25));
    });

    test('widens the window rather than dropping a long runtime extra', () {
      // 33 UTF-16 units, longer than anything bundled, so the bound can only
      // clear it if it is derived from the labels actually in the script.
      const extra = 'പ്രവര്‍ത്തിച്ചിരിക്കുന്നത് പരസ്യം';
      final withExtra = adFilterScript(
        placeholderText: 'x',
        extraLabels: const [extra],
      );

      expect(_maxLen(withExtra), greaterThan(extra.length));
    });

    test('pins every href marker to a Facebook address', () {
      // This tier runs against the whole post container before any text is
      // looked at, and a hit removes the post without a trace. A bare
      // `a[href*="sponsored"]` therefore deleted an organic post that merely
      // linked to some site's sponsored-content policy.
      final start =
          script.indexOf('post.querySelector(') + 'post.querySelector('.length;
      final selector = jsonDecode(
        script.substring(start, script.indexOf(')', start)),
      ) as String;

      final hrefMarkers =
          selector.split(', ').where((s) => s.contains('href')).toList();

      expect(hrefMarkers, isNotEmpty);
      for (final marker in hrefMarkers) {
        expect(
          marker.contains('[href^="/') || marker.contains('facebook.com/'),
          isTrue,
          reason: '$marker matches an ordinary outbound link',
        );
      }
    });

    test('matches short labels against the whole string, not a substring', () {
      // A two-character CJK label tested as a substring would fire inside
      // ordinary prose; compared whole it cannot.
      expect(script, contains('EXACT_LABELS'));
      expect(script, contains('lower === EXACT_LABELS[e]'));
    });

    test('bundles the CJK labels into the exact-match list', () {
      // Guards the split itself: if these ended up in the substring list they
      // would be unreachable, and CJK ad detection would silently be dead.
      final exact = script.substring(
        script.indexOf('var EXACT_LABELS ='),
        script.indexOf('var MIN_LEN ='),
      );

      expect(exact, contains('広告'));
      expect(exact, contains('광고'));
    });

    test('embeds the bundled labels and the runtime extras', () {
      expect(script, contains('sponsored'));
      expect(script, contains('werbung'));
    });
  });

  group('adFilterScript collapsing', () {
    test('marks handled posts so they are never processed twice', () {
      expect(script, contains('slim-ad-handled'));
    });

    test('preserves the original virtual-scroller height', () {
      expect(script, contains('data-actual-height'));
      expect(script, contains('data-slim-height-original'));
    });

    test('shrinks the box the user actually sees, not just the attribute', () {
      // Posts carry an inline `height:667px`. data-actual-height is metadata
      // for the scroller and changes no layout, so setting it alone leaves an
      // empty container the full size of the advert it replaced.
      expect(script, contains("post.style.height = '0px'"));
      expect(script, contains('data-slim-style-height'));
    });

    test('never overwrites the post subtree', () {
      expect(script, isNot(contains('innerHTML')));
    });

    test('exposes the entry point the observer calls', () {
      expect(script, contains('window.slimRemoveAds'));
    });

    test('shows the placeholder text it was given', () {
      expect(script, contains('Ad removed'));
    });
  });

  group('the label the live layout actually uses', () {
    test('bundles the two-character "ad" label', () {
      // Observed on a real feed: the label node is "Ad" plus two private-use
      // glyphs, in English even on a non-English interface. Nine of 37 posts
      // carried it and none of the 48 translated labels matched any of them.
      expect(kSponsoredLabels, contains('ad'));
    });

    test('keeps "ad" out of the substring list', () {
      // As a substring it would match "Add friend", "Download", "Read more" —
      // most of the feed. It is only ever safe compared whole.
      final substrings = script.substring(
        script.indexOf('var LABELS ='),
        script.indexOf('var EXACT_LABELS ='),
      );

      expect(substrings, isNot(contains('"ad"')));
    });

    test('strips the private-use glyphs fused into the label', () {
      // Without this the label node reads as the word plus two glyphs from
      // a private-use font, compares equal to nothing, and silently disables
      // the entire exact-match tier.
      expect(script, contains(r'\uE000-\uF8FF'));
      expect(script, contains(r'\uDB80-\uDBFF'));
      expect(script, contains('function clean('));
    });
  });

  group('scroll cost', () {
    test('walks only spans, not every div and anchor', () {
      // Measured on a live 55-post feed: 'span, div, a' materialises 3929 nodes
      // in 5.1ms; 'span' finds the same labels in 724 nodes and 0.5ms. The
      // advert label is the second span in the post, so div and a were pure
      // cost on every pass — and a pass runs on every debounced mutation while
      // scrolling.
      expect(script, contains("querySelectorAll('span')"));
      expect(script, isNot(contains("querySelectorAll('span, div, a')")));
    });

    test('does not re-examine posts it has already cleared', () {
      // Without this every pass re-walks the whole document, so the cost grows
      // with the feed and each scroll burst pays for every post again.
      expect(script, contains('slim-ad-checked'));
    });

    test('only marks a post cleared once it has stopped hydrating', () {
      // A post still filling in must be looked at again, or a late-rendered
      // label would be missed permanently. Facebook renders the spans first and
      // streams the text in after, so neither a span existing nor the first
      // words arriving proves the label is up — and the class is never removed,
      // so marking too early hides the advert forever.
      expect(script, contains('if (isSettled(post)) post.classList.add'));
      expect(script, contains("(els[i].textContent || '').trim().length > 0"));
      expect(
        script,
        isNot(contains("if (post.querySelector('span')) post.classList.add")),
      );
    });

    test('settles a post on a span count that stopped moving', () {
      // The count is what makes a late label buy another look: text arriving
      // changes it, so the post cannot retire on the pass before its chip lands.
      // Comparing against the stored count also retires a post that never fills
      // in, so the skip list still bounds the work on a long feed.
      expect(script, contains("post.getAttribute('data-slim-spans')"));
      expect(script, contains("post.setAttribute('data-slim-spans', rendered)"));
      expect(script, contains('return seen !== null && +seen === rendered;'));
    });
  });

  group('people you may know', () {
    test('is off unless asked for', () {
      final off = adFilterScript(placeholderText: 'x');

      expect(off, contains('var PYMK_LABELS = []'));
    });

    test('embeds the headings when switched on', () {
      final on = adFilterScript(
        placeholderText: 'x',
        hidePeopleYouMayKnow: true,
      );

      expect(on, contains('people you may know'));
      expect(on, contains('persone che potresti conoscere'));
    });

    test('gives the carousel the same scroller bookkeeping as an advert', () {
      // Setting display:none on its own leaves data-actual-height and the
      // inline height untouched, so the virtualising scroller keeps a
      // screen-tall slot reserved for a carousel that occupies nothing.
      final branch = _pymkBranch(script);

      expect(script, contains('isPeopleYouMayKnow'));
      expect(branch, contains('collapse(post)'));
      expect(branch, isNot(contains("post.style.display = 'none'")));
    });

    test('keeps the carousel out of the advert tally', () {
      // The number is shown as the description of the "hide ads" tile, so a
      // hidden carousel must not inflate it while that switch is off.
      expect(_pymkBranch(script), isNot(contains('ads++')));
      expect(script, contains('postMessage(String(ads))'));
      expect(script, isNot(contains('postMessage(String(handled))')));
    });

    test('can run with sponsored hiding switched off', () {
      // The two settings are independent; turning ads back on must not be a
      // precondition for hiding the friend carousel.
      final pymkOnly = adFilterScript(
        placeholderText: 'x',
        hideSponsored: false,
        hidePeopleYouMayKnow: true,
      );

      expect(pymkOnly, contains('var HIDE_SPONSORED = false'));
      expect(pymkOnly, contains('people you may know'));
      expect(pymkOnly, contains('if (!HIDE_SPONSORED) return false;'));
    });
  });

  group('adFilterScript label handling', () {
    test('drops a runtime extra that duplicates a bundled label', () {
      final withDuplicate = adFilterScript(
        placeholderText: 'x',
        extraLabels: const ['Sponsored'],
      );
      final bundled = adFilterScript(placeholderText: 'x');

      // The encoded array must be identical: no duplicate entry was added.
      expect(withDuplicate, bundled);
    });

    test('routes a short runtime extra into the exact-match list', () {
      // This is the CJK app-locale case. Dropping it for being short would
      // remove ad detection in exactly the locales that need it, so it must
      // survive — as an exact match rather than a substring.
      final script = adFilterScript(
        placeholderText: 'x',
        extraLabels: const ['广告'],
      );
      final exact = script.substring(
        script.indexOf('var EXACT_LABELS ='),
        script.indexOf('var MIN_LEN ='),
      );
      final substrings = script.substring(
        script.indexOf('var LABELS ='),
        script.indexOf('var EXACT_LABELS ='),
      );

      expect(exact, contains('广告'));
      expect(substrings, isNot(contains('广告')));
    });

    test('still ignores a runtime extra of a single character', () {
      final withOneChar = adFilterScript(
        placeholderText: 'x',
        extraLabels: const ['a'],
      );
      final bundled = adFilterScript(placeholderText: 'x');

      expect(withOneChar, bundled);
    });
  });
}

int _maxLen(String script) => int.parse(
      RegExp(r'var MAX_LEN = (\d+);').firstMatch(script)!.group(1)!,
    );

/// The body of the "people you may know" branch of the filter's main loop.
String _pymkBranch(String script) => script.substring(
      script.indexOf('if (isPeopleYouMayKnow(post))'),
      script.indexOf('if (!isSponsoredPost(post))'),
    );
