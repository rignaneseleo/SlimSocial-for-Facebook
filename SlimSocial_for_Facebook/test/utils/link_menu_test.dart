import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:slimsocial_for_facebook/utils/link_menu.dart';

void main() {
  group('parseLinkMenuMessage', () {
    test('reads a well-formed message', () {
      final link = parseLinkMenuMessage(
        jsonEncode({'href': 'https://example.com/story', 'text': 'A story'}),
      );

      expect(link, isNotNull);
      expect(link!.uri.toString(), 'https://example.com/story');
      expect(link.text, 'A story');
    });

    test('accepts an anchor with no label', () {
      final link = parseLinkMenuMessage(
        jsonEncode({'href': 'https://example.com/', 'text': ''}),
      );

      expect(link?.text, '');
    });

    test('returns null for malformed JSON', () {
      expect(parseLinkMenuMessage('{not json'), isNull);
      expect(parseLinkMenuMessage(''), isNull);
    });

    test('returns null for a payload that is not an object', () {
      expect(parseLinkMenuMessage('"https://example.com"'), isNull);
      expect(parseLinkMenuMessage('[1, 2]'), isNull);
    });

    test('returns null when a field is missing or not a string', () {
      expect(parseLinkMenuMessage(jsonEncode({'text': 'A story'})), isNull);
      expect(
        parseLinkMenuMessage(jsonEncode({'href': 'https://a.com', 'text': 1})),
        isNull,
      );
      expect(
        parseLinkMenuMessage(jsonEncode({'href': 7, 'text': 'A story'})),
        isNull,
      );
    });

    test('rejects a javascript: href', () {
      // The script filters the scheme too, but the page is what runs the
      // script: this side is what decides whether the sheet ever opens.
      expect(
        parseLinkMenuMessage(
          jsonEncode({'href': 'javascript:alert(1)', 'text': 'tap'}),
        ),
        isNull,
      );
    });

    test('rejects an app link the webview cannot load', () {
      expect(
        parseLinkMenuMessage(
          jsonEncode({'href': 'fb://fullscreen_video/1', 'text': 'video'}),
        ),
        isNull,
      );
    });

    test('strips the reading-session parameters off the url', () {
      // The point of the feature is a url worth pasting somewhere else, and
      // the one Facebook rewrites into the feed carries the session with it.
      final link = parseLinkMenuMessage(
        jsonEncode({
          'href': 'https://example.com/a?fbclid=123&id=7',
          'text': 'A story',
        }),
      );

      expect(link?.uri.toString(), 'https://example.com/a?id=7');
    });
  });
}
