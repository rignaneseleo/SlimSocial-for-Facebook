import 'package:flutter_test/flutter_test.dart';
import 'package:slimsocial_for_facebook/consts.dart';
import 'package:slimsocial_for_facebook/utils/user_agent.dart';

void main() {
  group('sanitizeUserAgent', () {
    test('returns an ordinary user agent unchanged', () {
      expect(sanitizeUserAgent(kMobileUserAgent), kMobileUserAgent);
      expect(sanitizeUserAgent(kFirefoxUserAgent), kFirefoxUserAgent);
    });

    test('drops a trailing newline', () {
      expect(sanitizeUserAgent('Mozilla/5.0 (X11)\n'), 'Mozilla/5.0 (X11)');
    });

    test('turns an inner newline into one space', () {
      expect(
        sanitizeUserAgent('Mozilla/5.0\n(Linux; Android 14)'),
        'Mozilla/5.0 (Linux; Android 14)',
      );
    });

    test('turns CR LF into one space', () {
      expect(
        sanitizeUserAgent('Mozilla/5.0 \r\n (Linux)\r\n'),
        'Mozilla/5.0 (Linux)',
      );
    });

    test('turns a tab into one space', () {
      expect(sanitizeUserAgent('Mozilla/5.0\t(Linux)'), 'Mozilla/5.0 (Linux)');
    });

    test('turns NUL, DEL and the line separator into spaces', () {
      String sep(int code) => 'a${String.fromCharCode(code)}b';
      expect(sanitizeUserAgent(sep(0x00)), 'a b');
      expect(sanitizeUserAgent(sep(0x7F)), 'a b');
      expect(sanitizeUserAgent(sep(0x2028)), 'a b');
    });

    test('trims surrounding spaces', () {
      expect(sanitizeUserAgent('  my-agent  '), 'my-agent');
    });

    test('returns null when only whitespace is left', () {
      expect(sanitizeUserAgent(''), isNull);
      expect(sanitizeUserAgent('   '), isNull);
      expect(sanitizeUserAgent('\r\n\t \n'), isNull);
      expect(sanitizeUserAgent(null), isNull);
    });
  });
}
