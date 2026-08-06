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

    test('hides the carousel rather than collapsing it as an advert', () {
      // It is not an advert, so it gets no "ad removed" stub.
      expect(script, contains('isPeopleYouMayKnow'));
      expect(script, contains("post.style.display = 'none'"));
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
