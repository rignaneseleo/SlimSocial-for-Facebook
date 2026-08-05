import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The two stylesheets every other translation falls back to.
///
/// `_.json` is the catch-all easy_localization reads when a locale has no file
/// of its own, so a label missing from both of these renders as an empty string
/// in every language.
const List<String> _fallbackLangFiles = [
  'assets/lang/_.json',
  'assets/lang/en-US.json',
];

Map<String, dynamic> _readLang(String path) {
  final contents = File(path).readAsStringSync();
  return jsonDecode(contents) as Map<String, dynamic>;
}

void main() {
  group('fallback translations', () {
    test('are valid JSON', () {
      for (final path in _fallbackLangFiles) {
        expect(() => _readLang(path), returnsNormally, reason: path);
      }
    });

    test('carry every label the settings screen asks for', () {
      // A missing key resolves to an empty string, which used to crash
      // `capitalize()` outright and still leaves an unlabelled row behind.
      const required = [
        'text_zoom',
        'text_zoom_desc',
        'dark_theme',
        'fixed_bar',
        'hide_stories',
        'center_text',
        'add_space',
        'enable_messenger',
        'permissions',
        'advanced',
        'style',
      ];

      for (final path in _fallbackLangFiles) {
        final lang = _readLang(path);
        for (final key in required) {
          expect(lang.containsKey(key), isTrue, reason: '$key missing in $path');
          expect(lang[key], isNotEmpty, reason: '$key is blank in $path');
        }
      }
    });
  });
}
