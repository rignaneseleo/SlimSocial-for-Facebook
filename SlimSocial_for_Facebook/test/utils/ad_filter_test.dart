import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:slimsocial_for_facebook/utils/ad_filter.dart';

void main() {
  group('kSponsoredLabels', () {
    test('is not empty', () {
      expect(kSponsoredLabels, isNotEmpty);
    });

    test('is entirely lowercase so matching can be case-insensitive', () {
      for (final label in kSponsoredLabels) {
        expect(label, label.toLowerCase(), reason: '"$label" is not lowercase');
      }
    });

    test('has no duplicates', () {
      expect(kSponsoredLabels.toSet().length, kSponsoredLabels.length);
    });

    test('has no stray surrounding whitespace', () {
      for (final label in kSponsoredLabels) {
        expect(label, label.trim(), reason: '"$label" has stray whitespace');
      }
    });

    test('short labels exist and are the CJK ones', () {
      // CJK ad labels are genuinely two characters ("広告", "광고"), so they
      // cannot clear the substring floor. They are not dropped — the filter
      // script matches anything below the floor as a whole string instead,
      // which is safer than a two-character substring test anyway. This asserts
      // the split is real, because an empty short list would silently mean no
      // CJK detection.
      final short =
          kSponsoredLabels.where((l) => l.length < kMinSponsoredLabelLength);

      expect(short, isNotEmpty);
      expect(short, contains('広告'));
      expect(short, contains('광고'));
    });

    test('no label is a single character', () {
      // One character would match far too much even as an exact string.
      for (final label in kSponsoredLabels) {
        expect(label.length, greaterThanOrEqualTo(2), reason: '"$label"');
      }
    });

    test('covers the scripts used across the supported locales', () {
      expect(kSponsoredLabels, contains('sponsored'));
      expect(kSponsoredLabels, contains('sponsorizzato'));
      expect(kSponsoredLabels, contains('gesponsert'));
      expect(kSponsoredLabels, contains('patrocinado'));
      expect(kSponsoredLabels, contains('реклама'));
      expect(kSponsoredLabels, contains('広告'));
      expect(kSponsoredLabels, contains('광고'));
    });

    test('bundles the Indic labels no lang file can supply', () {
      // Punjabi, Gujarati and Kannada have no `assets/lang` entry, so the
      // runtime extra cannot put them back: dropping them from the bundle
      // takes label detection away from those accounts entirely.
      expect(kSponsoredLabels, contains('ਸਰਪ੍ਰਸਤ'));
      expect(kSponsoredLabels, contains('સ્પોન્સર્ડ'));
      expect(kSponsoredLabels, contains('ಪ್ರಾಯೋಜಿತ'));
    });
  });

  final script = adFilterScript(
    placeholderText: 'Ad removed',
    extraLabels: const ['werbung'],
  );

  group('adFilterScript detection tiers', () {
    test('checks the post attribute before anything else', () {
      expect(script, contains('is_sponsored'));
      expect(script, contains('should_log_endpoint_info'));
    });

    test('checks the descendant markers Facebook puts on ad units', () {
      expect(script, contains('data-xt-vimp'));
      expect(script, contains('/ads/about/'));
    });

    test('bounds substring matching so prose mentioning the word is spared', () {
      expect(script, contains('lower.length < MIN_LEN'));
      expect(script, contains('lower.length >= MAX_LEN'));
    });

    test('leaves every bundled label inside the length window', () {
      // Both gates reject at `>= MAX_LEN`, so a label at or above the bound can
      // never match no matter how many locales carry it.
      final maxLen = _maxLen(script);

      for (final label in kSponsoredLabels) {
        expect(
          label.length,
          lessThan(maxLen),
          reason: '"$label" is $maxLen units or longer and can never match',
        );
      }
    });

    test('bounds each label by its own length, not by the longest one', () {
      // The global cap has to clear the longest label bundled, which on its own
      // would let a sentence that long match the shortest one: "sponsored" is 9
      // units, and a 30-unit line of prose containing it is not an advert.
      expect(script, contains('function fits(text, label)'));
      expect(script, contains('text.length < label.length + SLACK'));
      expect(script, contains('if (!fits(lower, LABELS[i])) continue;'));
      expect(script, contains('if (memo && fits(lower, memo)'));

      final shortest = kSponsoredLabels
          .where((l) => l.length >= kMinSponsoredLabelLength)
          .map((l) => l.length)
          .reduce((a, b) => a < b ? a : b);

      // 25 was the fixed cap this replaced, and it was already wide enough to
      // swallow a short sentence. Whatever the longest label drags the global
      // bound up to, the shortest one has to stay well under that.
      expect(shortest + kSponsoredLabelSlack, lessThan(25));
    });

    test('widens the window rather than dropping a long runtime extra', () {
      // 33 UTF-16 units, longer than anything bundled, so the bound can only
      // clear it if it is derived from the labels actually in the script.
      const extra = 'പ്രവര്‍ത്തിച്ചിരിക്കുന്നത് പരസ്യം';
      final withExtra = adFilterScript(
        placeholderText: 'x',
        extraLabels: const [extra],
      );

      expect(_maxLen(withExtra), greaterThan(extra.length));
    });

    test('pins every href marker to a Facebook address', () {
      // This tier runs against the whole post container before any text is
      // looked at, and a hit removes the post without a trace. A bare
      // `a[href*="sponsored"]` therefore deleted an organic post that merely
      // linked to some site's sponsored-content policy.
      final start =
          script.indexOf('post.querySelector(') + 'post.querySelector('.length;
      final selector = jsonDecode(
        script.substring(start, script.indexOf(')', start)),
      ) as String;

      final hrefMarkers =
          selector.split(', ').where((s) => s.contains('href')).toList();

      expect(hrefMarkers, isNotEmpty);
      for (final marker in hrefMarkers) {
        expect(
          marker.contains('[href^="/') || marker.contains('facebook.com/'),
          isTrue,
          reason: '$marker matches an ordinary outbound link',
        );
      }
    });

    test('matches short labels against the whole string, not a substring', () {
      // A two-character CJK label tested as a substring would fire inside
      // ordinary prose; compared whole it cannot.
      expect(script, contains('EXACT_LABELS'));
      expect(script, contains('lower === EXACT_LABELS[e]'));
    });

    test('bundles the CJK labels into the exact-match list', () {
      // Guards the split itself: if these ended up in the substring list they
      // would be unreachable, and CJK ad detection would silently be dead.
      final exact = script.substring(
        script.indexOf('var EXACT_LABELS ='),
        script.indexOf('var MIN_LEN ='),
      );

      expect(exact, contains('広告'));
      expect(exact, contains('광고'));
    });

    test('embeds the bundled labels and the runtime extras', () {
      expect(script, contains('sponsored'));
      expect(script, contains('werbung'));
    });
  });

  group('adFilterScript collapsing', () {
    test('marks handled posts so they are never processed twice', () {
      expect(script, contains('slim-ad-handled'));
    });

    test('preserves the original virtual-scroller height', () {
      expect(script, contains('data-actual-height'));
      expect(script, contains('data-slim-height-original'));
    });

    test('shrinks the box the user actually sees, not just the attribute', () {
      // Posts carry an inline `height:667px`. data-actual-height is metadata
      // for the scroller and changes no layout, so setting it alone leaves an
      // empty container the full size of the advert it replaced.
      expect(script, contains("post.style.height = '0px'"));
      expect(script, contains('data-slim-style-height'));
    });

    test('never overwrites the post subtree', () {
      expect(script, isNot(contains('innerHTML')));
    });

    test('exposes the entry point the observer calls', () {
      expect(script, contains('window.slimRemoveAds'));
    });

    test('shows the placeholder text it was given', () {
      expect(script, contains('Ad removed'));
    });
  });

  group('a collapse that does not move the feed', () {
    final collapse = _functionBody(script, 'function collapse(post)');
    final resolve = _functionBody(script, 'function scrollerFor(post)');

    test('reads the offset off whichever element actually scrolls', () {
      // The touch layout scrolls the feed inside div[data-type="vscroller"],
      // and the app scrolls the document itself as well — the screens' saved
      // position goes through the document scroller — so a fixed choice of
      // either one is wrong half the time.
      expect(collapse, contains('scrollerFor(post)'));
      expect(resolve, contains('node = node.parentElement;'));
      expect(resolve, contains('window.getComputedStyle(node).overflowY'));
    });

    test('accepts every overflow value that scrolls, and only if it does', () {
      for (final value in const ['auto', 'scroll', 'overlay']) {
        expect(resolve, contains("overflowY === '$value'"), reason: value);
      }

      // An `overflow-y: auto` box that fits its content scrolls nothing, so
      // correcting its offset discards the correction and leaves the jump on
      // whichever ancestor is really moving.
      expect(resolve, contains('node.scrollHeight > node.clientHeight'));
    });

    test('falls back to the document scroller', () {
      expect(
        resolve,
        contains('document.scrollingElement || document.documentElement'),
      );
      // The document's offset is read off the window rather than off the
      // element, which is why the fallback has to say which one it is.
      expect(resolve, contains('win: window'));
      expect(
        collapse,
        contains('scroller.win ? scroller.win.scrollY : scroller.el.scrollTop'),
      );
    });

    test('corrects only for a post that was entirely above the viewport', () {
      // Below the fold the height leaves a region the reader cannot see, and a
      // post still on screen is the one being looked at — no offset both
      // removes it and holds the view still. Both must reach the hide with no
      // anchor taken.
      expect(collapse, contains('var anchor = null;'));
      expect(
        collapse,
        contains('post.getBoundingClientRect().bottom <= viewportTop'),
      );
      expect(collapse, contains('if (anchor) {'));
    });

    test('takes the vanished height off the offset in the same turn', () {
      // Asking for scrollHeight forces the layout the hide invalidated, inside
      // the same synchronous block. A correction deferred to a later frame is
      // one the reader watches happen.
      expect(
        collapse,
        contains('anchor.height - anchor.scroller.el.scrollHeight'),
      );
      expect(collapse, isNot(contains('requestAnimationFrame')));
      expect(collapse, isNot(contains('setTimeout')));
    });

    test('measures the offset before the hide, not after it', () {
      // The regression this exists to prevent: Android WebView has Chromium's
      // scroll anchoring on by default, so the engine can move the offset
      // itself as soon as the forced layout runs. Reading the offset after the
      // hide and subtracting from that applied the correction twice and threw
      // the feed a whole advert too far up. So the offset is captured into the
      // anchor alongside the height, and the write is absolute.
      final anchorAssignment = collapse.substring(
        collapse.indexOf('anchor = {'),
        collapse.indexOf('};', collapse.indexOf('anchor = {')),
      );
      expect(anchorAssignment, contains('offset:'));
      expect(collapse, contains('var next = anchor.offset - lost;'));
      // Nothing may re-read the live offset on the restore path: that is the
      // shape of the bug.
      final restore = collapse.substring(collapse.indexOf('if (anchor) {'));
      expect(restore, isNot(contains('.scrollY')));
      expect(restore, isNot(contains('.scrollTop;')));
    });

    test('writes the corrected offset without animating it', () {
      // `scroll-behavior: smooth` up the tree would turn the two-argument
      // scrollTo into an animation, which is the jump arriving slowly rather
      // than not at all. Older WebViews that reject the object form fall back.
      expect(collapse, contains("behavior: 'instant'"));
      expect(collapse, contains('win.scrollTo(win.scrollX, next);'));
    });

    test('clamps the corrected offset at zero', () {
      // A scroller can shed more height than there was offset above it, and a
      // negative offset is a bounce on one engine and ignored on the next.
      expect(collapse, contains('if (next < 0) next = 0;'));
    });

    test('never lets the restore stop the advert being hidden', () {
      // Hiding the advert is the job and not jumping is the improvement, so
      // every line of the measure-and-restore is guarded and none of the hide
      // is: a scroller that cannot be measured still loses its advert.
      final guarded = _guardedBlocks(collapse);

      // Three now: the measure, the restore, and the object-form scrollTo whose
      // own fallback sits inside the restore.
      expect(guarded, hasLength(3));
      expect(guarded.first, contains('post.getBoundingClientRect().bottom'));

      final restore = guarded.firstWhere(
        (block) => block.contains('var next = anchor.offset - lost;'),
      );
      expect(restore, contains("behavior: 'instant'"));
      expect(restore, contains('anchor.scroller.el.scrollTop = next;'));
      expect(restore, endsWith('catch (e) {}'));

      for (final block in guarded) {
        expect(block, isNot(contains('slim-ad-handled')));
        expect(block, isNot(contains("post.style.height = '0px'")));
        expect(block, isNot(contains("post.style.display = 'none'")));
      }
    });

    test('covers the friend carousel without a branch of its own', () {
      // Both ways out of the loop hide the post by calling collapse, so the
      // correction is not something the carousel can be missing.
      final loop = _functionBody(script, 'function runPass()');

      expect(_pymkBranch(script), contains('collapse(post)'));
      expect(loop, isNot(contains('scrollerFor')));
      expect(loop, isNot(contains('scrollTop')));
    });
  });

  group('the label the live layout actually uses', () {
    test('bundles the two-character "ad" label', () {
      // Observed on a real feed: the label node is "Ad" plus two private-use
      // glyphs, in English even on a non-English interface. Nine of 37 posts
      // carried it and none of the 48 translated labels matched any of them.
      expect(kSponsoredLabels, contains('ad'));
    });

    test('keeps "ad" out of the substring list', () {
      // As a substring it would match "Add friend", "Download", "Read more" —
      // most of the feed. It is only ever safe compared whole.
      final substrings = script.substring(
        script.indexOf('var LABELS ='),
        script.indexOf('var EXACT_LABELS ='),
      );

      expect(substrings, isNot(contains('"ad"')));
    });

    test('strips the private-use glyphs fused into the label', () {
      // Without this the label node reads as the word plus two glyphs from
      // a private-use font, compares equal to nothing, and silently disables
      // the entire exact-match tier.
      expect(script, contains(r'\uE000-\uF8FF'));
      expect(script, contains(r'\uDB80-\uDBFF'));
      expect(script, contains('function clean('));
    });
  });

  group('scroll cost', () {
    test('walks only spans, not every div and anchor', () {
      // Measured on a live 55-post feed: 'span, div, a' materialises 3929 nodes
      // in 5.1ms; 'span' finds the same labels in 724 nodes and 0.5ms. The
      // advert label is the second span in the post, so div and a were pure
      // cost on every pass — and a pass runs on every debounced mutation while
      // scrolling.
      expect(script, contains("querySelectorAll('span')"));
      expect(script, isNot(contains("querySelectorAll('span, div, a')")));
    });

    test('does not re-examine posts it has already cleared', () {
      // Without this every pass re-walks the whole document, so the cost grows
      // with the feed and each scroll burst pays for every post again.
      expect(script, contains('slim-ad-checked'));
    });

    test('only marks a post cleared once it has stopped hydrating', () {
      // A post still filling in must be looked at again, or a late-rendered
      // label would be missed permanently. Facebook renders the spans first and
      // streams the text in after, so neither a span existing nor the first
      // words arriving proves the label is up — and the class is never removed,
      // so marking too early hides the advert forever.
      expect(script, contains('if (isSettled(post)) post.classList.add'));
      expect(script, contains("(els[i].textContent || '').trim().length > 0"));
      expect(
        script,
        isNot(contains("if (post.querySelector('span')) post.classList.add")),
      );
    });

    test('settles a post on a span count that stopped moving', () {
      // The count is what makes a late label buy another look: text arriving
      // changes it, so the post cannot retire on the pass before its chip lands.
      // Comparing against the stored count also retires a post that never fills
      // in, so the skip list still bounds the work on a long feed.
      expect(script, contains("post.getAttribute('data-slim-spans')"));
      expect(script, contains("post.setAttribute('data-slim-spans', rendered)"));
      expect(script, contains('return seen !== null && +seen === rendered;'));
    });
  });

  group('people you may know', () {
    test('is off unless asked for', () {
      final off = adFilterScript(placeholderText: 'x');

      expect(off, contains('var PYMK_LABELS = []'));
    });

    test('embeds the headings when switched on', () {
      final on = adFilterScript(
        placeholderText: 'x',
        hidePeopleYouMayKnow: true,
      );

      expect(on, contains('people you may know'));
      expect(on, contains('persone che potresti conoscere'));
    });

    test('gives the carousel the same scroller bookkeeping as an advert', () {
      // Setting display:none on its own leaves data-actual-height and the
      // inline height untouched, so the virtualising scroller keeps a
      // screen-tall slot reserved for a carousel that occupies nothing.
      final branch = _pymkBranch(script);

      expect(script, contains('isPeopleYouMayKnow'));
      expect(branch, contains('collapse(post)'));
      expect(branch, isNot(contains("post.style.display = 'none'")));
    });

    test('keeps the carousel out of the advert tally', () {
      // The number is shown as the description of the "hide ads" tile, so a
      // hidden carousel must not inflate it while that switch is off.
      expect(_pymkBranch(script), isNot(contains('ads++')));
      expect(script, contains('postMessage(String(ads))'));
      expect(script, isNot(contains('postMessage(String(handled))')));
    });

    test('can run with sponsored hiding switched off', () {
      // The two settings are independent; turning ads back on must not be a
      // precondition for hiding the friend carousel.
      final pymkOnly = adFilterScript(
        placeholderText: 'x',
        hideSponsored: false,
        hidePeopleYouMayKnow: true,
      );

      expect(pymkOnly, contains('var HIDE_SPONSORED = false'));
      expect(pymkOnly, contains('people you may know'));
      expect(pymkOnly, contains('if (!HIDE_SPONSORED) return false;'));
    });
  });

  group('injection health', () {
    final health = adFilterScript(placeholderText: 'x');

    test('posts diagnostics on a channel of their own', () {
      // The tally channel parses its payload as a bare integer, so a
      // diagnostic sent there is dropped as garbage and vice versa.
      expect(_diagnosticChannels(health), [kDiagnosticsChannelName]);
      expect(kDiagnosticsChannelName, isNot(kAdCountChannelName));
    });

    test('funnels every diagnostic through the throttle', () {
      // The gate is only worth anything if nothing can post around it: the
      // filter runs on every debounced mutation, so a single unthrottled call
      // site is thousands of messages per broken scroll.
      final body = _functionBody(health, 'function report(kind, data)');

      expect(body, contains('if (reported[kind]) return;'));
      expect(body, contains('reported[kind] = true;'));
      expect(
        RegExp('window.$kDiagnosticsChannelName.postMessage')
            .allMatches(health)
            .length,
        1,
        reason: 'a diagnostic is posted outside report()',
      );
    });

    test('reports only kinds the Dart side will accept', () {
      // A kind the allowlist does not know is dropped on arrival, so an
      // unlisted one is a signal that silently never reaches anybody.
      final kinds = _reportedKinds(health);

      expect(kinds, contains(kDiagNoPostsMatched));
      expect(kinds, contains(kDiagScriptThrew));
      for (final kind in kinds) {
        expect(kDiagnosticFields, contains(kind));
      }
    });

    test('sends only the fields declared for the kind it reports', () {
      // Same trap in the other direction: a field added here but not to
      // kDiagnosticFields is stripped before it leaves the app.
      final stale = _objectKeys(_functionBody(health, 'function checkFeedHealth(isFinal)'));
      final threw = _objectKeys(_functionBody(health, 'function describe(e)'));

      final staleFields = kDiagnosticFields[kDiagNoPostsMatched]!;
      final threwFields = kDiagnosticFields[kDiagScriptThrew]!;

      expect(stale, isNotEmpty);
      expect(stale, everyElement(isIn(staleFields)));
      expect(threw, isNotEmpty);
      expect(threw, everyElement(isIn(threwFields)));
    });

    test('never reads anything out of the page into a payload', () {
      // Post text, the address bar and the cookie jar all identify the person
      // reading the feed. Counts and this file's own selectors do not.
      for (final source in const [
        'textContent',
        'innerText',
        'innerHTML',
        'location.href',
        'location.search',
        'document.title',
        'document.cookie',
      ]) {
        expect(
          _functionBody(health, 'function checkFeedHealth(isFinal)'),
          isNot(contains(source)),
        );
        expect(_functionBody(health, 'function describe(e)'), isNot(contains(source)));
      }
    });

    test('never sends the words an exception came with', () {
      // The message is free text the page authors: a thrown string, an
      // overridden toString, a TypeError quoting the expression that failed.
      // Nothing here can tell those apart from the page writing a report of
      // its own, so the message does not travel and is not even read.
      final describe = _functionBody(health, 'function describe(e)');

      expect(_objectKeys(describe).toSet(), {'error'});
      expect(describe, isNot(contains('message')));
      expect(kDiagnosticFields[kDiagScriptThrew], {'error'});
    });

    test('reduces the exception type to one of a handful of names', () {
      // The type is the whole payload now, so it cannot be free text either:
      // `e.name` is whatever the page assigned it.
      final describe = _functionBody(health, 'function describe(e)');
      final names = jsonDecode(
        RegExp(r'var ERROR_NAMES = (\[.*?\]);').firstMatch(health)!.group(1)!,
      ) as List<Object?>;

      expect(names.toSet(), kDiagnosticErrorNames);
      expect(names, contains('TypeError'));
      expect(describe, contains('if (name === ERROR_NAMES[i]) return { error: name };'));
      expect(describe, contains('return { error: OTHER };'));
      expect(
        jsonDecode(RegExp('var OTHER = (".*?");').firstMatch(health)!.group(1)!),
        kDiagnosticOtherValue,
      );
    });

    test('lets the Dart side check every string it may be sent', () {
      // The channel is reachable by any script on the page, so the values are
      // checked again on arrival — which only works if each one is a constant
      // this file already knows.
      for (final kind in _reportedKinds(health)) {
        for (final field in kDiagnosticFields[kind]!) {
          if (field == 'dom_size') continue;
          expect(
            kDiagnosticValues,
            contains(field),
            reason: '$field can carry a string nothing validates',
          );
        }
      }
      expect(kDiagnosticValues['error'], kDiagnosticErrorNames);
      expect(kDiagnosticValues['selector'], {kPostSelector});
      expect(kDiagnosticErrorNames, isNot(contains(kDiagnosticOtherValue)));
    });

    test('rounds the page size it reports', () {
      // Only ever read as "did the page render at all", so an exact count is
      // detail nobody needs and a fingerprint nobody should have.
      expect(
        _functionBody(health, 'function checkFeedHealth(isFinal)'),
        contains('Math.floor(divs / 100) * 100'),
      );
    });
  });

  group('the stale-selector signal', () {
    final health = adFilterScript(placeholderText: 'x');

    test('only fires where a feed was genuinely expected', () {
      // Zero posts is the normal state of a photo view, a group, Marketplace
      // and every settings page. Reporting from those is not a weaker signal,
      // it is noise that buries the one case this exists for.
      final body = _functionBody(health, 'function checkFeedHealth(isFinal)');

      expect(body, contains('if (sawPosts) {'));
      expect(body, contains('if (!isFeedPage()) return;'));
      expect(body, contains("if (document.readyState !== 'complete') return;"));
      expect(body, contains('if (divs < MIN_DIVS) return;'));
    });

    test("treats only the feed's own addresses as a feed", () {
      final paths = jsonDecode(
        RegExp(r'var FEED_PATHS = (\[.*?\]);').firstMatch(health)!.group(1)!,
      ) as List<Object?>;

      expect(paths, kFeedPaths);
      expect(paths, contains('/'));
      for (final other in const ['/watch', '/marketplace', '/groups', '/messages']) {
        expect(paths, isNot(contains(other)));
      }
    });

    test('stays quiet for a signed-out install', () {
      // Facebook serves the login form at the feed's own address, so without
      // this the signal fires on every launch of every signed-out install —
      // the one population certain to see it.
      final body = _functionBody(health, 'function isFeedPage()');

      expect(body, contains('input[type="password"], input[name="pass"]'));
      expect(body, contains('return false;'));
    });

    test('runs only on the layout the selector was measured against', () {
      // Basic mode loads mbasic.facebook.com, whose markup has no
      // data-tracking-duration-id at all: zero matched posts there is correct
      // and permanent, so a domain-wide test would report a stale selector on
      // every launch of every basic-mode install and never stop.
      final body = _functionBody(health, 'function isFeedPage()');
      final hosts = jsonDecode(
        RegExp(r'var FEED_HOSTS = (\[.*?\]);').firstMatch(health)!.group(1)!,
      ) as List<Object?>;

      expect(hosts, kFeedHosts);
      expect(hosts, contains('touch.facebook.com'));
      expect(
        body,
        contains("FEED_HOSTS.indexOf(String(location.hostname || '')) === -1"),
      );
      // A suffix test on the domain is exactly what let the basic layout in.
      expect(body, isNot(contains("'.facebook.com'")));
    });

    test('reports nothing at all from a layout it cannot read', () {
      for (final other in const [
        'mbasic.facebook.com',
        'm.facebook.com',
        'www.facebook.com',
        'facebook.com',
        'business.facebook.com',
        'facebook.com.example.net',
      ]) {
        expect(kFeedHosts, isNot(contains(other)));
      }
    });

    test('is the only thing the host gate decides', () {
      // A narrow gate is safe precisely because losing it costs the signal and
      // nothing else: the filter itself must never consult it.
      expect(RegExp('isFeedPage').allMatches(health).length, 3);
      expect(
        _functionBody(health, 'function runPass()'),
        isNot(contains('isFeedPage')),
      );
      expect(
        _functionBody(health, 'function isSponsoredPost(post)'),
        isNot(contains('isFeedPage')),
      );
    });

    test('waits for the feed to arrive before judging it', () {
      // The first pass runs at page-finished, when a feed legitimately holds
      // no posts yet, so every check is late. A low-end phone can still be
      // painting at the first one, which is why there is more than one.
      final delays = RegExp(r'var HEALTH_DELAYS_MS = \[([\d,\s]+)\];')
          .firstMatch(health)!
          .group(1)!
          .split(',')
          .map((d) => int.parse(d.trim()))
          .toList();

      expect(delays, kFeedHealthDelaysMs);
      expect(delays.first, greaterThanOrEqualTo(5000));
      expect(delays, orderedEquals(List.of(delays)..sort()));
      expect(delays.length, greaterThan(1));
    });

    test('only the last attempt is allowed to report', () {
      // Every earlier attempt exists so a slow device can set sawPosts first.
      // If one of them could report, the extra attempts would be pointless —
      // the Dart-side throttle keeps only the first event per process, so an
      // early false positive would be the one that survived.
      expect(health, contains('function checkFeedHealth(isFinal)'));
      expect(health, contains('if (!isFinal) return;'));
      expect(health, contains('d === lastDelay'));

      // The guard has to sit before the report, not after it.
      final body = _functionBody(health, 'function checkFeedHealth(isFinal)');
      expect(
        body.indexOf('if (!isFinal) return;'),
        lessThan(body.indexOf('report(')),
      );
    });

    test('a rendered feed reports the denominator', () {
      // no_posts_matched on its own is a numerator with nothing under it: six
      // events reads the same whether it is six-in-six or six-in-six-thousand.
      final body = _functionBody(health, 'function checkFeedHealth(isFinal)');
      expect(body, contains(kDiagPostsMatched));

      // Both signals have to leave from behind the same gates, or the ratio
      // describes two different populations and means nothing.
      final gateAt = body.indexOf('if (divs < MIN_DIVS) return;');
      expect(gateAt, greaterThan(0));
      expect(body.indexOf(kDiagPostsMatched), greaterThan(gateAt));
      expect(body.indexOf(kDiagNoPostsMatched), greaterThan(gateAt));
    });

    test('the filter itself still never consults the telemetry gate', () {
      // Restating the invariant from the host-gate test at the point where it
      // was actually broken once: an earlier version of the denominator called
      // isFeedPage() from inside runPass(), which would have let a fault in the
      // signal take the ad filter down with it.
      expect(
        _functionBody(health, 'function runPass()'),
        isNot(contains(kDiagPostsMatched)),
      );
    });

    test('one matched post anywhere in the page clears it', () {
      // The scroller recycles nodes, so a later empty pass says nothing about
      // the selector — only that nothing is on screen right now.
      expect(health, contains('if (posts.length > 0) sawPosts = true;'));
      expect(health, contains('var posts = document.querySelectorAll(POST_SELECTOR);'));
    });

    test('names the selector that went stale', () {
      // Which selector broke is the whole point: the payload has to say it,
      // and it is a constant from this file, not anything off the page.
      final selector = jsonDecode(
        RegExp('var POST_SELECTOR = (".*?");').firstMatch(health)!.group(1)!,
      ) as String;

      expect(selector, contains('data-tracking-duration-id'));
      expect(
        _functionBody(health, 'function checkFeedHealth(isFinal)'),
        contains('selector: POST_SELECTOR'),
      );
    });
  });

  group('a filter pass that throws', () {
    final health = adFilterScript(placeholderText: 'x');

    test('is reported instead of ending the pass in silence', () {
      final wrapper = _functionBody(health, 'window.slimRemoveAds = function ()');

      expect(wrapper, contains('return runPass();'));
      expect(wrapper, contains('catch (e) {'));
      expect(wrapper, contains('report(${jsonEncode(kDiagScriptThrew)}, describe(e));'));
    });

    test('keeps the observer alive afterwards', () {
      // Re-throwing would take the observer's next mutation down with it, and
      // a pass that failed on this mutation may well succeed on the next.
      final wrapper = _functionBody(health, 'window.slimRemoveAds = function ()');

      expect(wrapper, contains('return 0;'));
      expect(wrapper, isNot(contains('throw e')));
      expect(wrapper, isNot(contains('throw;')));
    });
  });

  group('a message arriving on the diagnostics channel', () {
    // The channel is registered into the page's own script world, so every
    // test here is the case of a script on facebook.com posting to it directly
    // rather than of our own filter reporting.
    String post(String kind, Map<String, Object?> data) =>
        jsonEncode({'kind': kind, 'data': data});

    test('carries a known signal through', () {
      final parsed = parseDiagnostic(
        post(kDiagNoPostsMatched, {
          'page': 'feed',
          'selector': kPostSelector,
          'dom_size': 400,
        }),
      );

      expect(parsed, isNotNull);
      expect(parsed!.kind, kDiagNoPostsMatched);
      expect(parsed.data, {
        'page': 'feed',
        'selector': kPostSelector,
        'dom_size': 400,
      });
    });

    test('drops a signal the page named itself', () {
      expect(parseDiagnostic(post('page.says.hello', {})), isNull);
      expect(parseDiagnostic(post('injection', {})), isNull);
      expect(
        parseDiagnostic(jsonEncode({'kind': 42, 'data': <String, Object?>{}})),
        isNull,
      );
      expect(parseDiagnostic(jsonEncode([kDiagScriptThrew])), isNull);
      expect(parseDiagnostic('not json at all'), isNull);
      expect(parseDiagnostic(''), isNull);
    });

    test('never lets a string field arrive as a number', () {
      // Bounded, but a number in a field that is meant to be one of our own
      // constants is still the page choosing what leaves the device, one value
      // per page load. Only the field declared numeric may carry one.
      final parsed = parseDiagnostic(
        post(kDiagNoPostsMatched, {
          'page': 1234,
          'selector': 99,
          'dom_size': 300,
        }),
      );

      expect(parsed, isNotNull);
      expect(parsed!.data.containsKey('page'), isFalse);
      expect(parsed.data.containsKey('selector'), isFalse);
      expect(parsed.data['dom_size'], 300);
    });

    test('never lets the numeric field arrive as a string', () {
      final parsed = parseDiagnostic(
        post(kDiagNoPostsMatched, {'dom_size': 'four hundred'}),
      );

      expect(parsed, isNotNull);
      expect(parsed!.data.containsKey('dom_size'), isFalse);
    });

    test('cannot be told the user\'s own script failed', () {
      // Raised from Dart only. The page must not be able to claim it, because
      // the app treats that signal as one it may report without detail.
      expect(parseDiagnostic(post(kDiagUserScriptThrew, {})), isNull);
    });

    test('never forwards a string the page wrote', () {
      // The whole reason the free-text fields are gone: a script that has
      // noticed the channel would otherwise use it to post whatever it liked
      // off the device under a signal name the app does forward.
      const secret = 'user@example.com read a post about being ill';
      final parsed = parseDiagnostic(
        post(kDiagNoPostsMatched, {
          'page': secret,
          'selector': secret,
          'dom_size': 200,
        }),
      );

      expect(parsed!.data['page'], kDiagnosticOtherValue);
      expect(parsed.data['selector'], kDiagnosticOtherValue);
      expect(parsed.data.values, isNot(contains(secret)));
      expect(jsonEncode(parsed.data), isNot(contains('example.com')));
    });

    test('reduces an exception name to the allowlist', () {
      for (final name in kDiagnosticErrorNames) {
        expect(
          parseDiagnostic(post(kDiagScriptThrew, {'error': name}))!.data,
          {'error': name},
        );
      }

      for (final hostile in const [
        'https://facebook.com/story.php?id=1',
        'CustomError: the page speaking',
        'typeerror',
        '',
      ]) {
        expect(
          parseDiagnostic(post(kDiagScriptThrew, {'error': hostile}))!.data,
          {'error': kDiagnosticOtherValue},
        );
      }
    });

    test('drops the message field the payload used to carry', () {
      final parsed = parseDiagnostic(
        post(kDiagScriptThrew, {
          'error': 'TypeError',
          'message': 'a is not a function at /friends/1234',
        }),
      );

      expect(parsed!.data.keys, ['error']);
      expect(parsed.data, isNot(contains('message')));
    });

    test('drops a field that is not listed for the signal', () {
      final parsed = parseDiagnostic(
        post(kDiagFilterMissing, {'page': 'feed', 'note': 'anything'}),
      );

      expect(parsed!.data, isEmpty);
    });

    test('drops a number wide enough to spell something out', () {
      for (final value in const [-1, kDiagnosticIntLimit + 1, 1 << 52]) {
        expect(
          parseDiagnostic(post(kDiagNoPostsMatched, {'dom_size': value}))!.data,
          isEmpty,
        );
      }
      expect(
        parseDiagnostic(post(kDiagNoPostsMatched, {'dom_size': 1.5}))!.data,
        isEmpty,
      );
    });

    test('survives a payload of the wrong shape entirely', () {
      expect(parseDiagnostic(jsonEncode({'kind': kDiagScriptThrew})), isNotNull);
      expect(
        parseDiagnostic(
          jsonEncode({'kind': kDiagScriptThrew, 'data': 'a string'}),
        )!
            .data,
        isEmpty,
      );
      expect(
        parseDiagnostic(
          jsonEncode({
            'kind': kDiagScriptThrew,
            'data': <String, Object?>{'error': null},
          }),
        )!
            .data,
        isEmpty,
      );
    });
  });

  group('adFilterScript label handling', () {
    test('drops a runtime extra that duplicates a bundled label', () {
      final withDuplicate = adFilterScript(
        placeholderText: 'x',
        extraLabels: const ['Sponsored'],
      );
      final bundled = adFilterScript(placeholderText: 'x');

      // The encoded array must be identical: no duplicate entry was added.
      expect(withDuplicate, bundled);
    });

    test('routes a short runtime extra into the exact-match list', () {
      // This is the CJK app-locale case. Dropping it for being short would
      // remove ad detection in exactly the locales that need it, so it must
      // survive — as an exact match rather than a substring.
      final script = adFilterScript(
        placeholderText: 'x',
        extraLabels: const ['广告'],
      );
      final exact = script.substring(
        script.indexOf('var EXACT_LABELS ='),
        script.indexOf('var MIN_LEN ='),
      );
      final substrings = script.substring(
        script.indexOf('var LABELS ='),
        script.indexOf('var EXACT_LABELS ='),
      );

      expect(exact, contains('广告'));
      expect(substrings, isNot(contains('广告')));
    });

    test('still ignores a runtime extra of a single character', () {
      final withOneChar = adFilterScript(
        placeholderText: 'x',
        extraLabels: const ['a'],
      );
      final bundled = adFilterScript(placeholderText: 'x');

      expect(withOneChar, bundled);
    });
  });
}

int _maxLen(String script) => int.parse(
      RegExp(r'var MAX_LEN = (\d+);').firstMatch(script)!.group(1)!,
    );

/// The body of the "people you may know" branch of the filter's main loop.
String _pymkBranch(String script) => script.substring(
      script.indexOf('if (isPeopleYouMayKnow(post))'),
      script.indexOf('if (!isSponsoredPost(post))'),
    );

/// Every `try { … } catch (…) { … }` region in [body], braces included.
///
/// The catch is part of the region on purpose: a `try` whose failure path is
/// somewhere else swallows nothing, and what these tests assert is which lines
/// a failure cannot take down with it.
List<String> _guardedBlocks(String body) => RegExp(r'try\s*\{')
    .allMatches(body)
    .map((m) => body.substring(m.start, _blockEnd(body, _blockEnd(body, m.start)) + 1))
    .toList();

/// The index of the closing brace of the first `{ … }` block at or after [from].
int _blockEnd(String body, int from) {
  final open = body.indexOf('{', from);
  var depth = 0;
  for (var i = open; i < body.length; i++) {
    if (body[i] == '{') depth++;
    if (body[i] == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  throw StateError('unbalanced braces after offset $from');
}

/// The body of a JavaScript function in [script], braces included.
String _functionBody(String script, String header) {
  final start = script.indexOf(header);
  if (start == -1) throw StateError('no "$header" in the generated script');

  final open = script.indexOf('{', start);
  var depth = 0;
  for (var i = open; i < script.length; i++) {
    if (script[i] == '{') depth++;
    if (script[i] == '}') {
      depth--;
      if (depth == 0) return script.substring(open, i + 1);
    }
  }
  throw StateError('unbalanced braces after "$header"');
}

/// The channel names the script posts diagnostics on.
List<String> _diagnosticChannels(String script) => RegExp(
      r'window\.(\w+)\.postMessage\(\s*JSON\.stringify',
    ).allMatches(script).map((m) => m.group(1)!).toSet().toList();

/// The signal slugs the script can report.
List<String> _reportedKinds(String script) =>
    RegExp(r'report\(("(?:[^"\\]|\\.)*")').allMatches(script).map((m) {
      return jsonDecode(m.group(1)!) as String;
    }).toList();

/// The keys of every object literal in [body].
List<String> _objectKeys(String body) => RegExp(r'(?:\{|,)\s*(\w+):')
    .allMatches(body)
    .map((m) => m.group(1)!)
    .toList();
