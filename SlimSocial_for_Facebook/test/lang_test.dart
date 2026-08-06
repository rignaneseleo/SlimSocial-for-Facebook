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

List<File> _allLangFiles() {
  return Directory('assets/lang')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
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

  group('every locale file', () {
    // Checking only the two fallbacks is not enough: ru-RU.json once shipped
    // with a missing comma, so jsonDecode threw and every Russian user silently
    // got English instead. One test per file, so a future break names the file
    // that broke.
    final files = _allLangFiles();

    test('there are localisation files to check', () {
      expect(files, isNotEmpty);
    });

    for (final file in files) {
      test('${file.uri.pathSegments.last} is valid JSON', () {
        expect(
          () => jsonDecode(file.readAsStringSync()),
          returnsNormally,
          reason: '${file.path} does not parse, so that locale silently falls '
              'back to English',
        );
      });
    }
  });

  test('the fallback locale defines the keys the webview features ask for', () {
    // Checked against en-US only, not `_.json`: en-US is the configured
    // fallbackLocale, and several of these have never existed in `_.json`.
    final fallback = _readLang('assets/lang/en-US.json');

    for (final key in const [
      'ad_removed',
      'hide_ads',
      'hide_messenger_sidebar',
      'sponsored_keyword_fb',
    ]) {
      expect(fallback.keys, contains(key), reason: '$key missing from en-US');
    }
  });
}
