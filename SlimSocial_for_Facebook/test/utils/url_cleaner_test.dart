import 'package:flutter_test/flutter_test.dart';
import 'package:slimsocial_for_facebook/utils/url_cleaner.dart';

void main() {
  group('kTrackingParams', () {
    test('is not empty', () {
      expect(kTrackingParams, isNotEmpty);
    });

    test('is entirely lowercase so matching can be case-insensitive', () {
      for (final param in kTrackingParams) {
        expect(param, param.toLowerCase(), reason: '"$param" is not lowercase');
      }
    });

    test('has no duplicates', () {
      expect(kTrackingParams.toSet().length, kTrackingParams.length);
    });

    test('has no stray surrounding whitespace', () {
      for (final param in kTrackingParams) {
        expect(param, param.trim(), reason: '"$param" has stray whitespace');
      }
    });

    test('stores the blob parameters unindexed', () {
      // Facebook sends them as `__cft__[0]`, but the index is matched off in
      // the lookup — an entry that carried its own `[0]` would only ever match
      // the first index and silently miss `__cft__[1]`.
      for (final param in kTrackingParams) {
        expect(param, isNot(contains('[')), reason: '"$param" is indexed');
      }
    });

    test('covers the Facebook, utm, ad-network and email families', () {
      expect(kTrackingParams, contains('fbclid'));
      expect(kTrackingParams, contains('mibextid'));
      expect(kTrackingParams, contains('__cft__'));
      expect(kTrackingParams, contains('utm_source'));
      expect(kTrackingParams, contains('gclid'));
      expect(kTrackingParams, contains('igshid'));
      expect(kTrackingParams, contains('mc_eid'));
      expect(kTrackingParams, contains('ref_src'));
    });

    test('leaves the content-bearing parameters alone', () {
      // Any of these in the list would turn a working permalink into a 404,
      // and the breakage would read as Facebook being down.
      expect(kTrackingParams, isNot(contains('story_fbid')));
      expect(kTrackingParams, isNot(contains('id')));
      expect(kTrackingParams, isNot(contains('v')));
      expect(kTrackingParams, isNot(contains('sk')));
      expect(kTrackingParams, isNot(contains('fbid')));
    });
  });

  group('stripTrackingParams', () {
    test('removes fbclid from a story permalink', () {
      expect(
        stripTrackingParams(
          'https://m.facebook.com/story.php?story_fbid=99&id=7&fbclid=IwAR1x',
        ),
        'https://m.facebook.com/story.php?story_fbid=99&id=7',
      );
    });

    test('removes every family at once', () {
      expect(
        stripTrackingParams(
          'https://m.facebook.com/watch?v=123&utm_source=n&gclid=g&mc_eid=e'
          '&ref_src=twsrc&igshid=i',
        ),
        'https://m.facebook.com/watch?v=123',
      );
    });

    test("drops Facebook's own click blobs, index and all", () {
      // `__cft__` and `__xts__` arrive indexed. They look load-bearing because
      // they are long and opaque; the permalink resolves without them.
      expect(
        stripTrackingParams(
          'https://m.facebook.com/groups/1/posts/2/?__cft__[0]=AZXabc'
          '&__tn__=R&__xts__[0]=68.ARB&ref=notif',
        ),
        'https://m.facebook.com/groups/1/posts/2/',
      );
    });

    test('drops a blob parameter whose brackets arrived percent-escaped', () {
      expect(
        stripTrackingParams('https://m.facebook.com/x?__cft__%5B0%5D=AZX&a=1'),
        'https://m.facebook.com/x?a=1',
      );
    });

    test('matches the parameter name case-insensitively', () {
      // Facebook is not consistent about the case of a parameter it generates,
      // and a case-sensitive test would leave `FBCLID` on the url.
      expect(
        stripTrackingParams(
          'https://m.facebook.com/x?FBCLID=a&UtM_Source=b&k=1',
        ),
        'https://m.facebook.com/x?k=1',
      );
    });

    test('returns an unparsable string completely unchanged', () {
      // `Uri.parse` accepts this as a relative reference and its `toString`
      // percent-encodes the spaces, which would corrupt a string we were only
      // asked to filter.
      expect(stripTrackingParams('not a url at all'), 'not a url at all');
    });

    test('returns a string Uri.tryParse rejects outright unchanged', () {
      expect(stripTrackingParams('http://['), 'http://[');
    });

    test('leaves a scheme-less relative href alone', () {
      // These are what an in-page link looks like before the webview resolves
      // it, and rewriting one against no base would produce nonsense.
      expect(stripTrackingParams('/story.php?fbclid=a'), '/story.php?fbclid=a');
      expect(
        stripTrackingParams('//m.facebook.com/x?fbclid=a'),
        '//m.facebook.com/x?fbclid=a',
      );
      expect(stripTrackingParams('#comments'), '#comments');
    });

    test('leaves an empty string alone', () {
      expect(stripTrackingParams(''), '');
    });

    test('does not introduce a trailing ? on a url that had no query', () {
      // `Uri.replace` leaves a bare `?` behind, so a rebuild-always
      // implementation turns every clean url into a subtly different string.
      expect(
        stripTrackingParams('https://m.facebook.com/home.php'),
        'https://m.facebook.com/home.php',
      );
    });

    test('returns a query with nothing to strip byte for byte', () {
      // Untouched means untouched: no re-encoding, so the result can still be
      // compared against the url the webview is showing.
      expect(
        stripTrackingParams('https://m.facebook.com/x?a=b+c&d=e%20f&g=%C3%A9'),
        'https://m.facebook.com/x?a=b+c&d=e%20f&g=%C3%A9',
      );
    });

    test('keeps the surviving parameters in their original order', () {
      expect(
        stripTrackingParams('https://m.facebook.com/x?z=1&fbclid=q&a=2&m=3'),
        'https://m.facebook.com/x?z=1&a=2&m=3',
      );
    });

    test('keeps a value that needs percent-encoding', () {
      expect(
        stripTrackingParams(
          'https://m.facebook.com/search?q=%C3%A8%C3%A9&ref=x',
        ),
        'https://m.facebook.com/search?q=%C3%A8%C3%A9',
      );
    });

    test('keeps a literal plus distinct from a space', () {
      // `%2B` is a real `+` in the value and must survive as one, or a search
      // for "c++" silently becomes a search for "c  ".
      expect(
        stripTrackingParams('https://m.facebook.com/search?q=c%2B%2B&fbclid=x'),
        'https://m.facebook.com/search?q=c%2B%2B',
      );
    });

    test('normalises %20 to + once it has to rebuild the query', () {
      // Documenting what `Uri` imposes rather than fighting it: a space is
      // re-encoded as `+` however it arrived. Both forms decode to the same
      // query, and this only happens on a url already being rewritten.
      expect(
        stripTrackingParams('https://m.facebook.com/search?q=a%20b&fbclid=x'),
        'https://m.facebook.com/search?q=a+b',
      );
      expect(
        stripTrackingParams('https://m.facebook.com/search?q=a+b&fbclid=x'),
        'https://m.facebook.com/search?q=a+b',
      );
    });

    test('keeps both values of a repeated parameter', () {
      // `queryParameters` keeps only the last value, so an implementation
      // built on it would answer `?a=2` and delete content while claiming to
      // only remove tracking.
      expect(
        stripTrackingParams('https://m.facebook.com/x?a=1&a=2&fbclid=z'),
        'https://m.facebook.com/x?a=1&a=2',
      );
    });

    test('keeps a repeated parameter untouched when nothing is stripped', () {
      expect(
        stripTrackingParams('https://m.facebook.com/x?a=1&a=2'),
        'https://m.facebook.com/x?a=1&a=2',
      );
    });

    test('removes every occurrence of a repeated tracking parameter', () {
      expect(
        stripTrackingParams('https://m.facebook.com/x?ref=a&ref=b&k=1'),
        'https://m.facebook.com/x?k=1',
      );
    });

    test('preserves the fragment', () {
      expect(
        stripTrackingParams('https://m.facebook.com/x?a=1&fbclid=z#comments'),
        'https://m.facebook.com/x?a=1#comments',
      );
    });

    test('preserves the fragment when the query is emptied', () {
      expect(
        stripTrackingParams('https://m.facebook.com/x?fbclid=z#comments'),
        'https://m.facebook.com/x#comments',
      );
    });

    test('preserves a percent-escaped fragment without double-encoding it', () {
      expect(
        stripTrackingParams('https://m.facebook.com/x?fbclid=z#a%20b'),
        'https://m.facebook.com/x#a%20b',
      );
    });

    test('preserves the path, including a trailing slash', () {
      expect(
        stripTrackingParams(
          'https://m.facebook.com/groups/123/posts/456/?mibextid=abc',
        ),
        'https://m.facebook.com/groups/123/posts/456/',
      );
    });

    test('preserves a non-default port and the userinfo', () {
      // Rebuilding through the `Uri` constructor drops or mangles these; the
      // proxy setting means a port really can show up here.
      expect(
        stripTrackingParams('https://m.facebook.com:8080/x?fbclid=z'),
        'https://m.facebook.com:8080/x',
      );
    });

    test('removes a tracking parameter that has an empty value', () {
      // Facebook emits `?fbclid=` when it has nothing to put in it, and an
      // implementation keyed on the value rather than the name keeps it.
      expect(
        stripTrackingParams('https://m.facebook.com/x?fbclid=&a=1'),
        'https://m.facebook.com/x?a=1',
      );
    });

    test('removes a tracking parameter that has no value at all', () {
      expect(
        stripTrackingParams('https://m.facebook.com/x?fbclid&a=1'),
        'https://m.facebook.com/x?a=1',
      );
    });

    test('drops the ? entirely when the query is emptied', () {
      expect(
        stripTrackingParams('https://m.facebook.com/story.php?fbclid=IwAR1x'),
        'https://m.facebook.com/story.php',
      );
    });

    test(
      'drops the ? when the emptied query was the only one on a bare host',
      () {
        expect(
          stripTrackingParams('https://m.facebook.com?fbclid=z'),
          'https://m.facebook.com',
        );
      },
    );

    test('leaves a bare ? alone rather than rebuilding it away', () {
      // There is nothing to strip, so the string is not ours to normalise.
      expect(
        stripTrackingParams('https://m.facebook.com/x?'),
        'https://m.facebook.com/x?',
      );
    });

    test('does not force an authority onto a url that has none', () {
      // `mailto:` is absolute and parsable, and reassembling it through the
      // `Uri` constructor turns it into `mailto:///dev@example.com`.
      expect(
        stripTrackingParams('mailto:dev@example.com?subject=Hi&utm_source=x'),
        'mailto:dev@example.com?subject=Hi',
      );
    });

    test('does not treat a tracking name inside a value as a parameter', () {
      expect(
        stripTrackingParams(
          'https://m.facebook.com/x?u=http%3A%2F%2Fa.b%3Fref%3D1',
        ),
        'https://m.facebook.com/x?u=http%3A%2F%2Fa.b%3Fref%3D1',
      );
    });

    test(
      'does not strip a parameter that merely starts with a tracked name',
      () {
        // `ref` is in the list; `referrer` and `refid` are not, and a prefix
        // match would take content-bearing parameters with it.
        expect(
          stripTrackingParams(
            'https://m.facebook.com/x?referrer=a&refid=17&ref=b',
          ),
          'https://m.facebook.com/x?referrer=a&refid=17',
        );
      },
    );
  });

  group('facebookAppLinkTarget', () {
    const host = 'touch.facebook.com';

    test('maps fb://fullscreen_video/<id> onto a reel url', () {
      expect(
        facebookAppLinkTarget(
          Uri.parse('fb://fullscreen_video/1234567890'),
          host: host,
        ),
        Uri.parse('https://touch.facebook.com/reel/1234567890/'),
      );
    });

    test('uses the host it is handed, not a hardcoded one', () {
      // The app serves two different Facebook layouts and only the caller
      // knows which one is live; a reel sent to the wrong host is a redirect
      // at best.
      expect(
        facebookAppLinkTarget(
          Uri.parse('fb://fullscreen_video/55'),
          host: 'mbasic.facebook.com',
        ),
        Uri.parse('https://mbasic.facebook.com/reel/55/'),
      );
    });

    test('tolerates a trailing slash on the app link', () {
      // The trailing slash parses to an empty second segment, which would
      // otherwise read as an unknown two-segment shape.
      expect(
        facebookAppLinkTarget(
          Uri.parse('fb://fullscreen_video/321/'),
          host: host,
        ),
        Uri.parse('https://touch.facebook.com/reel/321/'),
      );
    });

    test('accepts the id arriving as ?id=', () {
      expect(
        facebookAppLinkTarget(
          Uri.parse('fb://fullscreen_video/?id=246'),
          host: host,
        ),
        Uri.parse('https://touch.facebook.com/reel/246/'),
      );
    });

    test('accepts the id arriving as ?v=', () {
      expect(
        facebookAppLinkTarget(
          Uri.parse('fb://fullscreen_video?v=808'),
          host: host,
        ),
        Uri.parse('https://touch.facebook.com/reel/808/'),
      );
    });

    test('prefers the path id over a query id', () {
      expect(
        facebookAppLinkTarget(
          Uri.parse('fb://fullscreen_video/111?id=222'),
          host: host,
        ),
        Uri.parse('https://touch.facebook.com/reel/111/'),
      );
    });

    test('is case-insensitive because Uri lower-cases scheme and host', () {
      expect(
        facebookAppLinkTarget(
          Uri.parse('FB://FullScreen_Video/77'),
          host: host,
        ),
        Uri.parse('https://touch.facebook.com/reel/77/'),
      );
    });

    test('returns null for an fb:// target it does not recognise', () {
      // Null means "caller keeps its existing behaviour". Guessing a web url
      // for an app link we cannot read would replace a working hand-off with
      // a 404.
      expect(
        facebookAppLinkTarget(Uri.parse('fb://profile/123'), host: host),
        isNull,
      );
      expect(
        facebookAppLinkTarget(Uri.parse('fb://page/123'), host: host),
        isNull,
      );
    });

    test('returns null for a non-fb scheme', () {
      expect(
        facebookAppLinkTarget(
          Uri.parse('https://m.facebook.com/reel/1/'),
          host: host,
        ),
        isNull,
      );
      expect(
        facebookAppLinkTarget(Uri.parse('fbmessenger://x/1'), host: host),
        isNull,
      );
      expect(
        facebookAppLinkTarget(Uri.parse('intent://x/1'), host: host),
        isNull,
      );
    });

    test(
      'returns null when the target sits in the path instead of the host',
      () {
        // `fb:///fullscreen_video/1` has an empty authority, so this is not the
        // shape we measured and we do not know what it means.
        expect(
          facebookAppLinkTarget(
            Uri.parse('fb:///fullscreen_video/1'),
            host: host,
          ),
          isNull,
        );
      },
    );

    test('returns null when there is no id at all', () {
      expect(
        facebookAppLinkTarget(Uri.parse('fb://fullscreen_video'), host: host),
        isNull,
      );
      expect(
        facebookAppLinkTarget(Uri.parse('fb://fullscreen_video/'), host: host),
        isNull,
      );
    });

    test('returns null for a non-numeric id rather than building a url', () {
      // The id becomes a path segment on our own host, so anything that is not
      // a digit is refused instead of interpolated.
      expect(
        facebookAppLinkTarget(
          Uri.parse('fb://fullscreen_video/abc'),
          host: host,
        ),
        isNull,
      );
      expect(
        facebookAppLinkTarget(
          Uri.parse('fb://fullscreen_video/12ab'),
          host: host,
        ),
        isNull,
      );
      expect(
        facebookAppLinkTarget(
          Uri.parse('fb://fullscreen_video/?id=not-a-number'),
          host: host,
        ),
        isNull,
      );
    });

    test('refuses an id that tries to escape its path segment', () {
      expect(
        facebookAppLinkTarget(
          Uri.parse('fb://fullscreen_video/?id=..%2F..%2Fsettings'),
          host: host,
        ),
        isNull,
      );
      expect(
        facebookAppLinkTarget(
          Uri.parse('fb://fullscreen_video/?id=1%2Fevil'),
          host: host,
        ),
        isNull,
      );
    });

    test('refuses non-ASCII digits', () {
      // They are digits to a human and to `RegExp` under Unicode mode, but not
      // to any Facebook id, and the point of the check is what ends up in the
      // path.
      expect(
        facebookAppLinkTarget(
          Uri.parse('fb://fullscreen_video/%D9%A1%D9%A2%D9%A3'),
          host: host,
        ),
        isNull,
      );
    });

    test('returns null for a path with more segments than we understand', () {
      expect(
        facebookAppLinkTarget(
          Uri.parse('fb://fullscreen_video/123/456'),
          host: host,
        ),
        isNull,
      );
    });

    test('returns null instead of building a host-less url', () {
      expect(
        facebookAppLinkTarget(Uri.parse('fb://fullscreen_video/1'), host: ''),
        isNull,
      );
    });
  });
}
