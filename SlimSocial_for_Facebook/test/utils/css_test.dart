import 'package:flutter/material.dart';
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

  group('resolveCssPlaceholders', () {
    test('substitutes the accent colour', () {
      expect(
        resolveCssPlaceholders('a { color: {accent}; }', accent: '#112233'),
        'a { color: #112233; }',
      );
    });

    test('substitutes every occurrence', () {
      final result = resolveCssPlaceholders(
        'a { color: {accent}; border-color: {accent}; }',
        accent: '#112233',
      );

      expect(result, isNot(contains('{accent}')));
    });

    test('leaves a stylesheet without placeholders untouched', () {
      const css = 'a { color: red; }';

      expect(resolveCssPlaceholders(css, accent: '#112233'), css);
    });
  });

  group('cssColorFromColor', () {
    test('formats a colour as a six-digit hex string', () {
      expect(cssColorFromColor(const Color(0xFF3B5998)), '#3b5998');
    });

    test('drops the alpha channel', () {
      expect(cssColorFromColor(const Color(0x803B5998)), '#3b5998');
    });
  });

  group('post-level toggles target the current layout', () {
    test('add space no longer relies on <article> alone', () {
      // `article` matched zero elements on the live layout under either user
      // agent, so this toggle silently did nothing. Posts are the
      // data-tracking-duration-id children of the feed scroller.
      expect(
        CustomCss.addSpaceBetweenPostsCss.code,
        contains('div[data-type="vscroller"] > div[data-tracking-duration-id]'),
      );
    });

    test('center text no longer relies on the legacy message class', () {
      // `._5rgt._5msi` was the old mobile message body and matches nothing now.
      expect(
        CustomCss.centerTextPostsCss.code,
        contains('div[data-tracking-duration-id]'),
      );
    });

    test('center text does not centre the post container itself', () {
      // Centring the post shifted every video 197px right — half its width —
      // because text-align on an ancestor moves the player's line box. The rule
      // must reach only the text wrappers.
      expect(
        CustomCss.centerTextPostsCss.code,
        contains('div[data-tracking-duration-id] .native-text'),
      );
      expect(
        CustomCss.centerTextPostsCss.code,
        isNot(contains('div[data-tracking-duration-id] {')),
      );
    });

    test('both keep their legacy selector as a fallback', () {
      // Harmless where it matches nothing, and still correct for anyone served
      // the older layout.
      expect(CustomCss.addSpaceBetweenPostsCss.code, contains('article'));
      expect(CustomCss.centerTextPostsCss.code, contains('._5rgt._5msi'));
    });
  });

  group('app install upsell', () {
    test('targets the pinned bottom bar by class, not by its label', () {
      // The label is localised, so matching text would work in one language
      // and silently stop working in every other.
      expect(
        CustomCss.hideAppUpsellCss.code,
        contains('div.fixed-container.bottom'),
      );
      expect(CustomCss.hideAppUpsellCss.code, isNot(contains('Open app')));
    });

    test('is not offered as a user-facing toggle', () {
      // Same treatment as the other chrome removals: structural, not a
      // preference, so it is injected directly rather than via cssList.
      final keys = CustomCss.cssList.map((c) => c.key);

      expect(keys, isNot(contains('hide_app_upsell')));
    });

    test('also hides the header pill on the reels and video pages', () {
      // A second, separate upsell: the bottom bar is `.fixed-container.bottom`,
      // this is a blue pill inside an unsuffixed `.fixed-container` at the top,
      // so the first rule did not reach it. Scoped to a bar so an ordinary blue
      // button in the feed is left alone.
      expect(CustomCss.hideAppUpsellCss.code, contains('.bg-s32'));
      expect(
        CustomCss.hideAppUpsellCss.code,
        contains('div.fixed-container'),
      );
    });

    test('can never hide a container holding a form control', () {
      // Facebook docks the comment composer in the same bottom container as
      // the upsell, so an unguarded rule removed the box you type a comment
      // into. Checking the feed did not catch it: the composer only exists
      // once a post is open.
      final code = CustomCss.hideAppUpsellCss.code;

      expect(code, contains(':not(:has(textarea))'));
      expect(code, contains(':not(:has(input))'));
      expect(code, contains(':not(:has([contenteditable]))'));
    });

    test('does not hide every fixed container', () {
      // A bare `.fixed-container` rule would also catch the top bar and the
      // empty above-bottom spacer that sit alongside the upsell.
      expect(
        CustomCss.hideAppUpsellCss.code,
        isNot(contains('div.fixed-container {')),
      );
    });
  });

  group('media trays', () {
    test('the stories rule leads with a language-independent selector', () {
      // `#MStoriesTray` is an id from the old mobile layout and matched nothing
      // in the recon, so the toggle appeared to do nothing. The replacement
      // keys off `data-srat`, which — unlike an aria-label — is the same in
      // every locale.
      expect(
        CustomCss.hideStoriesCss.code,
        contains('div[data-type="vscroller"] > div[data-srat]'),
        reason: 'stories rule needs a selector for the current layout',
      );
    });

    test('there is a reels stylesheet', () {
      expect(CustomCss.hideReelsCss.key, 'hide_reels');
    });

    test('the reels rule does not rely on hrefs', () {
      // This layout drives navigation through data-action-id and has almost no
      // hrefs; the recon found zero `/reel/` links with reels on screen. A
      // href-based rule silently matches nothing.
      expect(CustomCss.hideReelsCss.code, isNot(contains('href')));
    });

    test('the reels rule tests the attribute value, not its presence', () {
      // Ordinary video posts also carry data-is-reels, with the value "false".
      // Matching on presence alone would hide every video in the feed.
      expect(CustomCss.hideReelsCss.code, contains('[data-is-reels="true"]'));
      expect(CustomCss.hideReelsCss.code, isNot(contains('[data-is-reels]')));
    });

    test('the carousel rule cannot swallow a feed post', () {
      // Feed posts are direct children of the same vscroller as the reels
      // carousel — 16 of 17 were, on the live layout. So the carousel rule is
      // one stray aria-label away from hiding real posts. The :not() makes that
      // impossible rather than merely unlikely.
      expect(
        CustomCss.hideReelsCss.code,
        contains('> div:not([data-tracking-duration-id]):has('),
      );
    });

    test('both trays are offered as settings toggles', () {
      final keys = CustomCss.cssList.map((c) => c.key);

      expect(keys, contains('hide_stories'));
      expect(keys, contains('hide_reels'));
    });

    test('neither rule hides the whole feed', () {
      // A selector that matches an ancestor of the feed would blank the page.
      for (final css in [CustomCss.hideStoriesCss, CustomCss.hideReelsCss]) {
        expect(css.code, isNot(contains('body')), reason: css.key);
        expect(css.code, isNot(contains('#root')), reason: css.key);
      }
    });
  });

  group('theme-aware stylesheets', () {
    test('no bundled stylesheet hardcodes the legacy accent hex', () {
      for (final css in CustomCss.cssList) {
        expect(
          css.code.toLowerCase(),
          isNot(contains('#3b5998')),
          reason: '${css.key} should use the {accent} placeholder',
        );
      }
    });

    test('the floating button uses the placeholder', () {
      expect(CustomCss.fabBtnCss.code, contains('{accent}'));
      expect(
        CustomCss.fabBtnCss.code.toLowerCase(),
        isNot(contains('#3b5998')),
      );
    });
  });
}
