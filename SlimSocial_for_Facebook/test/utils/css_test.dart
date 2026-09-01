import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slimsocial_for_facebook/main.dart';
import 'package:slimsocial_for_facebook/utils/css.dart';

void main() {
  group('messenger conversation list height', () {
    final code = CustomCss.messengerListHeightCss.code;

    test('ships switched on', () {
      expect(CustomCss.messengerListHeightCss.isEnabled(), isTrue);
    });

    test('is not a settings toggle', () {
      // Structural, like hideAppUpsellCss: cssList drives the settings screen.
      expect(CustomCss.cssList, isNot(contains(CustomCss.messengerListHeightCss)));
    });

    test('never touches overflow', () {
      // The regression this exists to prevent. Messenger's own scroller is a
      // descendant of the list and already carries `overflow-y: auto`;
      // overriding overflow up the chain took the scroller away from the
      // virtualised list and scrolling stopped entirely. Measured on a device.
      expect(code, isNot(contains('overflow')));
    });

    test('sizes the chain to content, not to the parent', () {
      // `height: 100%` made every ancestor take its parent's full height and
      // the content ran past the viewport with nothing to scroll it.
      expect(code, contains('height: auto !important'));
      expect(code, isNot(contains('height: 100%')));
    });

    test('lets each ancestor of the list grow', () {
      expect(code, contains('flex-grow: 1 !important'));
      expect(code, contains('min-height: 0 !important'));
      expect(code, contains('max-height: none !important'));
    });

    test('keeps the :has() selectors in a rule of their own', () {
      // An unsupported selector invalidates the whole list it sits in, so on a
      // WebView older than Chromium 105 this must cost the fix and nothing
      // else — the same guard hideStoriesCss documents.
      final rules = code.split('}').where((r) => r.trim().isNotEmpty).toList();
      final hasRules = rules.where((r) => r.contains(':has(')).toList();
      expect(hasRules, hasLength(1));
      expect(hasRules.single, isNot(contains('[role="grid"] {')));
    });

    test('targets the list by role rather than by a generated class', () {
      // The lesson from adaptMessengerPageCss, whose hash-class selectors now
      // match nothing at all: role attributes outlive Facebook's build hashes.
      expect(code, contains('[role="grid"]'));
      expect(code, isNot(matches(RegExp(r'\.x[0-9a-z]{5,}'))));
    });
  });

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

    test('never keys off a generated surface class', () {
      // The header pill was matched with `.bg-s32`, but the bg-sN number is
      // assigned per page render: on most loads it was not the pill at all but
      // some other chrome inside a fixed container, which then disappeared.
      // This rule is injected unconditionally, so there is no toggle to undo
      // it with.
      expect(
        RegExp(r'bg-s\d').hasMatch(CustomCss.hideAppUpsellCss.code),
        isFalse,
        reason: 'the bg-sN number means something different on every render',
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

    test('unlocks page scroll if the install overlay is left behind', () {
      // Hiding the bottom bar alone left a dimmer that locked scrolling on
      // some devices (#339). Restoring overflow lets the feed move even when
      // Facebook's modal chrome is incomplete.
      expect(
        CustomCss.hideAppUpsellCss.code,
        contains('overflow: auto !important'),
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

    test('the stories rule cannot swallow a feed post', () {
      // Same trap as the reels carousel: posts are direct children of the same
      // vscroller, and "Share to your story" — or the "story" inside "History"
      // — is one aria-label away from hiding one whole.
      for (final selector in CustomCss.hideStoriesCss.code
          .split(RegExp(r',|\{'))
          .where((s) => s.contains(':has('))) {
        expect(
          selector,
          contains(':not([data-tracking-duration-id]):has('),
          reason: selector,
        );
      }
    });

    test('the legacy fallbacks do not share a rule with :has()', () {
      // One unsupported selector invalidates the whole selector list, so on a
      // WebView without :has() the `#MStoriesTray` fallback would be dropped
      // along with it — and that fallback exists for exactly those devices.
      final legacyRule = CustomCss.hideStoriesCss.code
          .split('}')
          .firstWhere((rule) => rule.contains('#MStoriesTray'));

      expect(legacyRule, isNot(contains(':has(')));
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

  group('dark theme', () {
    test('no longer hardcodes a surface class', () {
      // Two shipped attempts failed here. The bg-sN number is generated per
      // page render, so a static map both misses light surfaces and repaints
      // brand colours; darkThemeScript() derives it from the page instead.
      expect(
        RegExp(r'bg-s\d').hasMatch(CustomCss.darkThemeCss.code),
        isFalse,
        reason: 'surfaces belong in dark_theme.dart, keyed on measured colour',
      );
    });

    test('still paints the page itself dark', () {
      // The derived sheet covers Facebook's surfaces; the document underneath
      // them is ours to set, and a white one shows through every gap.
      expect(CustomCss.darkThemeCss.code, contains('html, body'));
      expect(CustomCss.darkThemeCss.code, contains('#18191a'));
    });

    test('makes every wrapped text run legible before refining any of it', () {
      // The catch-all is the safety net: Facebook inlines text colour, so an
      // unrecognised token would otherwise stay near-black on a dark card. It
      // has to come first, because the token rules that follow rely on source
      // order to win.
      final code = CustomCss.darkThemeCss.code;
      final catchAll = code.indexOf('.native-text, .native-text *');
      final firstToken = code.indexOf('[style*="color:#');

      expect(catchAll, isNonNegative);
      expect(firstToken, greaterThan(catchAll));
    });

    test('matches the colour declaration, not a bare hex', () {
      // A style attribute holds background-color too. `[style*="#ffffff"]`
      // would match an element with a white background and set its text white
      // as well, hiding the text inside its own box.
      final tokens = RegExp(r'\[style\*="([^"]+)"\]')
          .allMatches(CustomCss.darkThemeCss.code)
          .map((m) => m.group(1)!);

      expect(tokens, isNotEmpty);
      for (final t in tokens) {
        expect(t, startsWith('color:'), reason: '"$t" could match a background');
      }
    });

    test('leaves the brand colours reading as brand colours', () {
      // Links and the green badge carry meaning; flattening them to body text
      // is a regression even though it is perfectly legible.
      expect(CustomCss.darkThemeCss.code, contains('#4599ff'));
      expect(CustomCss.darkThemeCss.code, contains('#45bd62'));
    });

    test('no longer colours the font-size classes', () {
      // `.f1`/`.f4` set font-size and line-height — the served stylesheet
      // declares no colour on them at all. Colouring them was aiming at the
      // wrong hook and missed every run whose class was not in the list.
      expect(CustomCss.darkThemeCss.code, isNot(contains('span.f1')));
      expect(CustomCss.darkThemeCss.code, isNot(contains('span.f5')));
    });
  });

  group('selectable post content', () {
    test('ships switched on', () {
      // Nothing toggles it, so the default is the only setting it will ever
      // have.
      expect(CustomCss.selectableContentCss.key, 'selectable_content');
      expect(CustomCss.selectableContentCss.isEnabled(), isTrue);
    });

    test('is not offered as a user-facing toggle', () {
      // Same treatment as the other structural fixes: a reader who cannot copy
      // a phone number out of a post is looking at a bug, not at a preference
      // they forgot to switch on.
      final keys = CustomCss.cssList.map((c) => c.key);

      expect(keys, isNot(contains('selectable_content')));
    });

    test('sets user-select both prefixed and unprefixed', () {
      // The unprefixed property is what current Chromium honours; the older
      // Android WebViews this app still runs on only ever knew the -webkit-
      // one, and shipping one of the two leaves half the fleet unable to
      // select.
      final code = CustomCss.selectableContentCss.code;

      expect(code, contains('-webkit-user-select: text'));
      expect(
        RegExp(r'[;{]\s*user-select:\s*text').hasMatch(code),
        isTrue,
        reason: 'the unprefixed property is missing: $code',
      );
    });

    test('re-enables pointer events on post images', () {
      // pointer-events: none on feed images is what makes a long press on a
      // photo do nothing at all, so the browser never gets as far as offering
      // to save or share it.
      final code = CustomCss.selectableContentCss.code;

      expect(code, contains('div[data-tracking-duration-id] img'));
      expect(code, contains('pointer-events: auto !important'));
    });

    test('scopes every selector to the post container', () {
      // A document-wide rule here is not a bigger fix, it is a different bug:
      // every mis-tap on the app's own chrome becomes a text selection with
      // handles to dismiss. One escaped selector is enough to cause that, so
      // each one is checked rather than the stylesheet as a whole.
      final rules = CustomCss.selectableContentCss.code
          .split('}')
          .where((rule) => rule.contains('{'));

      expect(rules, isNotEmpty);
      for (final rule in rules) {
        for (final selector in rule.split('{').first.split(',')) {
          expect(
            selector,
            contains('div[data-tracking-duration-id]'),
            reason: selector,
          );
        }
      }
    });

    test('survives the whitespace collapsing intact', () {
      // MyCss collapses the authored formatting, and stripping whitespace
      // outright — which an earlier version of that collapse did — would fuse
      // `-webkit-user-select:text!important` to the declaration after it and
      // cost both.
      final code = CustomCss.selectableContentCss.code;

      expect(code, isNot(contains('\n')));
      expect(code, isNot(contains('  ')));
      expect(
        code,
        'div[data-tracking-duration-id] .native-text, '
        'div[data-tracking-duration-id] .native-text * '
        '{ -webkit-user-select: text !important; '
        'user-select: text !important; } '
        'div[data-tracking-duration-id] img '
        '{ pointer-events: auto !important; }',
      );
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
