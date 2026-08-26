/// Surface colours for the dark theme.
///
/// Three tones, ordered light-to-dark the way Facebook's own light palette is
/// ordered, so the visual hierarchy survives the swap: the page wash sits
/// behind cards, cards sit behind raised chrome.
const String kDarkPageColor = '#18191a';
const String kDarkCardColor = '#242526';
const String kDarkRaisedColor = '#3a3b3c';

/// Relative luminance above which a colour counts as a light surface worth
/// darkening. Facebook's brand blue measures 0.17 and its red 0.15, so this
/// floor leaves every accent alone without naming any of them.
const double kLightSurfaceLuminance = 0.5;

/// Luminance bands that pick which dark tone replaces a light one.
///
/// Facebook's card is pure white (1.0) and its page wash is `#f0f2f5` (0.855),
/// so the near-white band maps to the *card* tone and the slightly grey band to
/// the *page* tone. That looks inverted until you notice the light palette is
/// ordered the same way: the lighter surface is the one in front.
const double kCardLuminance = 0.95;
const double kPageLuminance = 0.85;

/// The element id of the generated stylesheet.
const String kDarkSurfaceStyleId = 'slim-dark-surfaces';

/// Builds the dark theme's surface palette from the page's own stylesheet.
///
/// ## Why this cannot be a static stylesheet
///
/// Facebook paints every surface through a generated atomic class — `bg-s4`,
/// `bg-s30` — whose number is assigned per page render. The number does not
/// mean the same colour twice. Measured on one device across two loads of the
/// same feed: `bg-s3` was `rgb(8,102,255)` and then `rgb(255,255,255)`; `bg-s33`
/// was a divider grey on one load and the blue "Join" button on the next.
///
/// A hardcoded map is therefore wrong in both directions at once. It leaks —
/// on one measured load six light classes fell outside the map, `bg-s30` alone
/// covering 84 elements — and it over-reaches, repainting a brand blue as grey
/// because that index happened to be a divider last time. Two shipped attempts
/// at completing the map failed for exactly this reason, and no third attempt
/// can succeed: the key is not stable, so there is nothing to key on.
///
/// ## What this does instead
///
/// It reads the map out of the page. Every `bg-sN` rule Facebook ships is in
/// `document.styleSheets` with its real colour, so the script walks the CSSOM
/// once, keeps the classes whose declared background measures light, and emits
/// an override for those and only those. The index can shuffle freely; the
/// colour it resolves to is read fresh each load.
///
/// Cost is one pass over the rules — 4.5 ms for 517 rules on a Pixel 10 Pro —
/// and the result is a plain stylesheet, so scrolling pays nothing. It walks
/// no elements, which matters: the feed carries ~2700 nodes and the same
/// mistake in the ad filter cost 24 ms on every scroll frame.
///
/// Rules from our own sheets are skipped, so the script never reads back its
/// own output and mistake it for Facebook's palette.
String darkThemeScript() {
  return '''
(function () {
  if (window.slimDarkTheme) { window.slimDarkTheme(); return; }

  var STYLE_ID = '$kDarkSurfaceStyleId';
  var PAGE = '$kDarkPageColor', CARD = '$kDarkCardColor', RAISED = '$kDarkRaisedColor';
  var LIGHT = $kLightSurfaceLuminance, CARD_AT = $kCardLuminance, PAGE_AT = $kPageLuminance;

  // Cumulative. A class is never un-mapped: a later pass reads our own dark
  // override as "not light", and dropping it there would flip the surface back
  // to white on every rebuild.
  var mapped = {};

  function parse(c) {
    var m = String(c).match(/rgba?\\(\\s*([\\d.]+)[,\\s]+([\\d.]+)[,\\s]+([\\d.]+)(?:[,/\\s]+([\\d.%]+))?/);
    if (!m) return null;
    var a = m[4] === undefined ? 1 : parseFloat(m[4]);
    if (!a) return null; // fully transparent paints nothing
    return { r: +m[1], g: +m[2], b: +m[3] };
  }

  function luminance(p) {
    function ch(v) {
      v /= 255;
      return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
    }
    return 0.2126 * ch(p.r) + 0.7152 * ch(p.g) + 0.0722 * ch(p.b);
  }

  function toneFor(L) {
    return L >= CARD_AT ? CARD : (L >= PAGE_AT ? PAGE : RAISED);
  }

  function scan(rules) {
    for (var i = 0; i < rules.length; i++) {
      var rule = rules[i];
      // @media / @supports and friends: recurse, they have no selector.
      if (rule.cssRules && !rule.selectorText) { scan(rule.cssRules); continue; }
      var sel = rule.selectorText;
      // Cheap string test before touching rule.style, which is the slow part.
      if (!sel || sel.indexOf('bg-s') === -1) continue;
      var c = parse(rule.style.backgroundColor || rule.style.background);
      if (!c) continue;
      var L = luminance(c);
      if (L <= LIGHT) continue;
      var tone = toneFor(L);
      var re = /\\.(bg-s\\d+)\\b/g, m;
      while ((m = re.exec(sel)) !== null) mapped[m[1]] = tone;
    }
  }

  function build() {
    var before = Object.keys(mapped).length;
    for (var s = 0; s < document.styleSheets.length; s++) {
      var sheet = document.styleSheets[s];
      var node = sheet.ownerNode;
      if (node && node.id && node.id.lastIndexOf('slim-', 0) === 0) continue;
      try { scan(sheet.cssRules); } catch (e) { /* cross-origin sheet */ }
    }
    var names = Object.keys(mapped);
    if (names.length === before) return names.length; // nothing new; leave the DOM alone
    var parts = [];
    for (var k = 0; k < names.length; k++) {
      var n = names[k];
      // Pseudo-elements only. Facebook paints these surfaces from ::before
      // (and, on the composer row, ::after on top of it) and leaves the
      // element itself transparent on purpose — it is a positioned layer in a
      // stack. Giving the element a background as well turns a transparent
      // layer into an opaque rectangle over whatever sits below it.
      parts.push('.' + n + '::before,.' + n + '::after{background-color:' + mapped[n] + ' !important}');
    }
    var el = document.getElementById(STYLE_ID);
    if (!el) {
      el = document.createElement('style');
      el.id = STYLE_ID;
      (document.head || document.documentElement).appendChild(el);
    }
    el.textContent = parts.join('');
    return names.length;
  }

  window.slimDarkTheme = build;
  build();

  // Facebook streams the rest of its palette in as further <style> nodes after
  // first paint. Watching head for child additions catches them; it is not a
  // subtree observer, so feed mutations never reach it and scrolling stays free.
  try {
    var target = document.head || document.documentElement;
    new MutationObserver(function (records) {
      for (var i = 0; i < records.length; i++) {
        var added = records[i].addedNodes;
        for (var j = 0; j < added.length; j++) {
          var t = added[j].tagName;
          if (t === 'STYLE' || t === 'LINK') { build(); return; }
        }
      }
    }).observe(target, { childList: true });
  } catch (e) { /* observer unavailable; the timed passes below still run */ }

  // A sheet can also be swapped in place rather than appended, which the
  // observer cannot see. Two bounded passes cover that; build() is a no-op
  // when it finds nothing new, so this costs nothing after the palette settles.
  setTimeout(build, 600);
  setTimeout(build, 2500);
})();
''';
}
