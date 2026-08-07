import 'package:flutter_test/flutter_test.dart';
import 'package:slimsocial_for_facebook/utils/dark_theme.dart';

void main() {
  final script = darkThemeScript();

  group('the palette is read from the page, never hardcoded', () {
    test('names no individual surface class', () {
      // The whole point. `bg-s33` was a divider grey on one load of the feed
      // and the blue "Join" button on the next, so any numbered class in here
      // would repaint something it should not on some page. The script may
      // mention the `bg-s` prefix — it has to match on something — but never a
      // specific index.
      expect(script, contains('bg-s'));
      expect(
        RegExp(r'bg-s\d').hasMatch(script),
        isFalse,
        reason: 'a numbered class means the map is hardcoded again',
      );
    });

    test('reads the colours out of the stylesheets', () {
      expect(script, contains('document.styleSheets'));
      expect(script, contains('cssRules'));
    });

    test('skips our own sheets so it cannot read back its own output', () {
      // Every sheet the app injects is id'd `slim-…`. Without this the second
      // pass would read the dark colours this script just wrote and treat them
      // as Facebook's palette.
      expect(script, contains("node.id.lastIndexOf('slim-', 0) === 0"));
    });

    test('survives a stylesheet it is not allowed to read', () {
      // A cross-origin sheet throws on .cssRules. One such sheet must not take
      // the whole theme down with it.
      expect(script, contains('try { scan(sheet.cssRules); } catch'));
    });

    test('looks inside @media and @supports groups', () {
      // Those rules have no selectorText of their own; without the recursion
      // every surface declared inside one would be missed.
      expect(script, contains('if (rule.cssRules && !rule.selectorText)'));
    });
  });

  group('only light surfaces are touched', () {
    test('applies a luminance floor', () {
      expect(script, contains('if (L <= LIGHT) continue;'));
      expect(script, contains('var LIGHT = $kLightSurfaceLuminance'));
    });

    test('the floor clears every brand colour', () {
      // Measured from the served stylesheet: brand blue rgb(8,102,255) is 0.17
      // and the red badge rgb(221,35,52) is 0.15. Leaving them alone is what
      // keeps the "Join" button blue.
      expect(kLightSurfaceLuminance, greaterThan(0.2));
    });

    test('a fully transparent declaration paints nothing and is skipped', () {
      // `.bg-s1::before` is declared rgba(0,0,0,0). Treating alpha 0 as a
      // colour would map it by its rgb triple and paint a box that Facebook
      // deliberately left invisible.
      expect(script, contains('if (!a) return null;'));
    });
  });

  group('tone banding', () {
    test('keeps the three tones ordered light to dark', () {
      expect(kCardLuminance, greaterThan(kPageLuminance));
      expect(kPageLuminance, greaterThan(kLightSurfaceLuminance));
    });

    test('near-white maps to the card tone, not the page tone', () {
      // Facebook's card is pure white and its page wash is #f0f2f5 (0.855), so
      // the lighter source surface is the one in front. Getting this backwards
      // puts the page colour on the cards and flattens the feed.
      expect(script, contains('L >= CARD_AT ? CARD : (L >= PAGE_AT ? PAGE : RAISED)'));
      expect(kCardLuminance, greaterThan(0.9));
    });

    test('every tone is actually dark', () {
      for (final tone in [kDarkPageColor, kDarkCardColor, kDarkRaisedColor]) {
        expect(tone, matches(RegExp(r'^#[0-9a-f]{6}$')), reason: tone);
        final r = int.parse(tone.substring(1, 3), radix: 16);
        expect(r, lessThan(0x60), reason: '$tone is not dark');
      }
    });
  });

  group('scroll cost', () {
    test('walks no elements', () {
      // The ad filter already taught this lesson: a per-mutation DOM walk over
      // ~2700 feed nodes cost 24 ms a pass against a 16.7 ms frame budget. The
      // CSSOM has 517 rules and is walked once.
      expect(script, isNot(contains('querySelectorAll')));
      expect(script, isNot(contains('getComputedStyle')));
    });

    test('the observer is not a subtree observer', () {
      // Watching the subtree would fire on every feed mutation, which is
      // exactly the cost this design exists to avoid. Head child additions are
      // rare and are all we need.
      expect(script, contains('{ childList: true }'));
      expect(script, isNot(contains('subtree: true')));
    });

    test('a rebuild that finds nothing new does not touch the DOM', () {
      // The timed passes and the observer can both fire after the palette has
      // settled; rewriting the stylesheet then would invalidate style for the
      // whole document for no reason.
      expect(script, contains('if (names.length === before) return names.length;'));
    });

    test('tests the selector as a string before reading rule.style', () {
      // rule.style is the expensive getter; the string test drops ~96% of the
      // rules before paying for it.
      expect(script, contains("sel.indexOf('bg-s') === -1"));
    });
  });

  group('rebuilding is safe', () {
    test('the map is cumulative', () {
      // A later pass sees our own override and reads the class as "not light".
      // If a rebuild started from an empty map the class would be dropped and
      // the surface would flip back to white, so the map must be assigned
      // exactly once — at declaration, outside build().
      expect('mapped = {}'.allMatches(script).length, 1);
      expect(script, contains('var mapped = {};'));
    });

    test('re-running the script reuses the existing builder', () {
      // runJs() fires on every page load, and a second observer per load would
      // multiply the work for nothing.
      expect(script, contains('if (window.slimDarkTheme)'));
      expect(script, contains('window.slimDarkTheme = build;'));
    });

    test('reuses its own style element rather than stacking new ones', () {
      expect(script, contains("document.getElementById(STYLE_ID)"));
      expect(script, contains("el.id = STYLE_ID;"));
    });
  });

  group('the generated rules', () {
    test('cover both pseudo-elements', () {
      // Surfaces paint through ::before, and the composer row paints through
      // ::after on top of it — overriding only ::before left one white band
      // across an otherwise dark page.
      expect(script, contains("'::before,.' + n + '::after{"));
    });

    test('leave the element itself transparent', () {
      // These are positioned layers in a stack and Facebook keeps them
      // transparent deliberately. Painting the element as well turns a
      // see-through layer into an opaque rectangle over the content below it,
      // which reads as a grey block where posts should be.
      expect(script, isNot(contains("'.' + n + ',")));
    });

    test('are important, because Facebook declares its own', () {
      expect(script, contains('!important'));
    });
  });
}
