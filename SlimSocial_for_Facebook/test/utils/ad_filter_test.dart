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
}
