import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slimsocial_for_facebook/main.dart';
import 'package:slimsocial_for_facebook/utils/css.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sp = await SharedPreferences.getInstance();
  });

  group('MyCss normalisation', () {
    test('collapses the source formatting onto a single line', () {
      final css = MyCss(
        key: 'k',
        description: 'd',
        code: '''
article {
    margin-top: 50px !important;
}
''',
      );

      expect(css.code, 'article { margin-top: 50px !important; }');
    });

    test('keeps a space between the tokens of a compound value', () {
      // Stripping whitespace entirely produced `border:1pxsolid#333`, which
      // the browser drops, taking the whole dark theme down with it.
      final css = MyCss(
        key: 'k',
        description: 'd',
        code: '.a { border: 1px solid #333 !important; }',
      );

      expect(css.code, contains('1px solid #333'));
    });

    test('keeps multi-part shorthand values intact', () {
      final css = MyCss(
        key: 'k',
        description: 'd',
        code: '.a { box-shadow: 0 3px 6px rgba(0, 0, 0, 0.16); }',
      );

      expect(css.code, contains('0 3px 6px rgba(0, 0, 0, 0.16)'));
    });

    test('leaves quotes untouched so they can be encoded later', () {
      final css = MyCss(
        key: 'k',
        description: 'd',
        code: "[aria-label='Next'] { display: none; }",
      );

      expect(css.code, "[aria-label='Next'] { display: none; }");
    });

    test('every bundled stylesheet is collapsed to one line', () {
      for (final css in CustomCss.cssList) {
        expect(css.code, isNot(contains('\n')), reason: css.key);
        expect(css.code, isNot(contains('  ')), reason: css.key);
      }
    });

    test('the dark theme keeps the spaces inside its border values', () {
      // `border: 1px solid #dddfe2` was being flattened to `1pxsolid#dddfe2`,
      // so the browser threw the declaration away.
      expect(CustomCss.darkThemeCss.code, contains('1px solid'));
    });
  });

  group('MyCss.isEnabled', () {
    test('falls back to defaultEnabled when nothing is stored', () {
      expect(
        MyCss(key: 'a', description: 'd', code: '', defaultEnabled: true)
            .isEnabled(),
        isTrue,
      );
      expect(
        MyCss(key: 'b', description: 'd', code: '').isEnabled(),
        isFalse,
      );
    });

    test('reads back what setEnabled stored', () async {
      final css = MyCss(key: 'c', description: 'd', code: '');

      css.setEnabled(true);
      await Future<void>.delayed(Duration.zero);

      expect(css.isEnabled(), isTrue);
    });
  });
}
