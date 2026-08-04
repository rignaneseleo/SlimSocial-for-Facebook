import 'package:flutter_test/flutter_test.dart';
import 'package:slimsocial_for_facebook/utils/utils.dart';

void main() {
  group('capitalize', () {
    test('upper-cases the first letter and lower-cases the rest', () {
      expect('settings'.capitalize(), 'Settings');
      expect('SETTINGS'.capitalize(), 'Settings');
    });

    test('returns an empty string instead of throwing', () {
      // A missing translation resolves to '', and indexing it used to throw a
      // RangeError while the settings screen was being built.
      expect(''.capitalize(), '');
    });

    test('handles a single character', () {
      expect('a'.capitalize(), 'A');
    });
  });

  group('isNullOrEmpty', () {
    test('treats null, empty and blank as empty', () {
      expect(null.isNullOrEmpty(), isTrue);
      expect(''.isNullOrEmpty(), isTrue);
      expect('   '.isNullOrEmpty(), isTrue);
    });

    test('treats real content as not empty', () {
      expect('a'.isNullOrEmpty(), isFalse);
    });
  });
}
