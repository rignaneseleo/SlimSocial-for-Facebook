import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The two stylesheets every other translation falls back to.
///
/// Only `en-US.json` is ever read at runtime: it is the configured
/// `fallbackLocale`, and the default asset loader builds `<locale>.json`, which
/// no locale ever stringifies to `_`. `_.json` is the Crowdin-era template kept
/// in sync by hand. A label missing from the active locale falls back to
/// en-US, and one missing from en-US too renders as the raw key string.
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
      // A blank value used to crash `capitalize()` outright and still leaves an
      // unlabelled row behind, so presence alone is not enough.
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
      'ads_blocked_count',
      'error_page_offline',
      'hide_ads',
      'hide_messenger_sidebar',
      'hide_people_you_may_know',
      // `hide_stories` is deliberately absent: the fallback-translations group
      // above already asserts it, against both fallback files rather than just
      // en-US, which is the stronger check.
      'hide_reels',
      'retry',
      'sponsored_keyword_fb',
    ]) {
      expect(fallback.keys, contains(key), reason: '$key missing from en-US');
    }
  });

  test('placeholder keys carry as many {} as their call sites pass args', () {
    // `.tr(args:)` fills one `{}` per argument and silently leaves the rest of
    // the string untouched, so a translation that dropped the placeholder
    // renders the sentence with no number in it.
    const placeholders = {
      'ads_blocked_count': 1,
      'Image saved to {}': 1,
      'error_proxy with {}:{}': 2,
    };

    for (final file in _allLangFiles()) {
      final lang = _readLang(file.path);
      placeholders.forEach((key, count) {
        final value = lang[key] as String?;
        if (value == null) return;
        expect(
          '{}'.allMatches(value).length,
          count,
          reason: '$key in ${file.path} does not leave room for $count arg(s)',
        );
      });
    }
  });

  test('every locale defines every key the fallback locale defines', () {
    // easy_localization is configured with `useFallbackTranslations: true`, so a
    // gap here degrades to English rather than to a raw key — but only for as
    // long as en-US itself keeps the key. Crowdin fills these in; this test
    // catches the window between adding a string and the translations landing.
    final fallback = _readLang('assets/lang/en-US.json');

    for (final file in _allLangFiles()) {
      // `_.json` is a hand-kept template that nothing loads at runtime, and it
      // has never carried the full key set.
      if (file.uri.pathSegments.last == '_.json') continue;

      final lang = _readLang(file.path);
      final missing =
          fallback.keys.where((key) => !lang.containsKey(key)).toList();
      expect(missing, isEmpty, reason: '${file.path} is missing $missing');
    }
  });
}
