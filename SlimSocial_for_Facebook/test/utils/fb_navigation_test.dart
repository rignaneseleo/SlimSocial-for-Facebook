import 'package:flutter_test/flutter_test.dart';
import 'package:slimsocial_for_facebook/utils/fb_navigation.dart';

bool isAuth(String url) => isFacebookAuthUrl(Uri.parse(url));

void main() {
  group('isFacebookAuthUrl keeps the observed sign-in flow', () {
    // These four are the exact addresses the Messenger sign-in walked through
    // on a device, in order, on 2026-08-28. Each one used to close the Messenger
    // screen and reappear in the feed, which is why signing in could not be
    // completed. They are listed individually rather than as a loop so a
    // regression names the step that broke.
    test('checkpoint start', () {
      expect(isAuth('https://m.facebook.com/checkpoint/start/'), isTrue);
    });

    test('checkpoint itself', () {
      expect(isAuth('https://m.facebook.com/checkpoint/'), isTrue);
    });

    test('checkpoint reached under login', () {
      expect(isAuth('https://m.facebook.com/login/checkpoint/'), isTrue);
    });

    test('the app login handoff', () {
      expect(isAuth('https://m.facebook.com/unified/login_via/app/'), isTrue);
    });
  });

  group('isFacebookAuthUrl recognises the rest of the flow', () {
    test('the classic login form', () {
      expect(isAuth('https://m.facebook.com/login.php?next=%2F'), isTrue);
      expect(isAuth('https://m.facebook.com/login'), isTrue);
      expect(
        isAuth('https://www.facebook.com/login/device-based/regular/login/'),
        isTrue,
      );
    });

    test('two-factor and recovery', () {
      expect(isAuth('https://m.facebook.com/two_factor/authenticate/'), isTrue);
      expect(isAuth('https://m.facebook.com/authenticate/'), isTrue);
      expect(isAuth('https://m.facebook.com/recover/initiate/'), isTrue);
      expect(isAuth('https://m.facebook.com/security/'), isTrue);
      expect(isAuth('https://m.facebook.com/confirmemail.php'), isTrue);
    });

    test('the consent and oauth interstitials', () {
      expect(isAuth('https://m.facebook.com/privacy/consent/gdp/'), isTrue);
      expect(isAuth('https://www.facebook.com/dialog/oauth?client_id=1'), isTrue);
      expect(isAuth('https://www.facebook.com/x/oauth/'), isTrue);
    });

    test('a path ending without a trailing slash matches too', () {
      // pathSegments hands back a trailing empty string for `/checkpoint/` and
      // nothing extra for `/checkpoint` — both have to reach the same answer,
      // and the empty-segment filter is what makes that true.
      expect(isAuth('https://m.facebook.com/checkpoint'), isTrue);
      expect(isAuth('https://m.facebook.com/checkpoint/'), isTrue);
    });

    test('matching ignores case', () {
      expect(isAuth('https://m.facebook.com/CheckPoint/Start/'), isTrue);
    });

    test('a query string or fragment is not part of the decision', () {
      expect(
        isAuth('https://m.facebook.com/checkpoint/?next=https%3A%2F%2Fx'),
        isTrue,
      );
      expect(isAuth('https://m.facebook.com/checkpoint/#step2'), isTrue);
    });
  });

  group('isFacebookAuthUrl leaves ordinary pages to the feed', () {
    test('the feed itself', () {
      expect(isAuth('https://touch.facebook.com/home.php'), isFalse);
      expect(isAuth('https://touch.facebook.com/'), isFalse);
      // `/` yields no segments at all, which must not be read as a match.
      expect(isAuth('https://touch.facebook.com'), isFalse);
    });

    test('content a reader taps out of a conversation', () {
      expect(isAuth('https://m.facebook.com/DIYCraftsAmerica/videos/123/'), isFalse);
      expect(isAuth('https://m.facebook.com/groups/12345'), isFalse);
      expect(isAuth('https://m.facebook.com/marketplace/'), isFalse);
      expect(isAuth('https://m.facebook.com/photo.php?fbid=1'), isFalse);
      expect(isAuth('https://m.facebook.com/notifications.php'), isFalse);
      expect(isAuth('https://m.facebook.com/messages/'), isFalse);
    });

    test('a first segment that merely begins with an auth word', () {
      // The whole reason the first tier matches segments rather than prefixes:
      // a profile or page whose name starts with "login" is not a login page.
      expect(isAuth('https://m.facebook.com/loginhelp/'), isFalse);
      expect(isAuth('https://m.facebook.com/securityreview/'), isFalse);
      expect(isAuth('https://m.facebook.com/checkpoints/'), isFalse);
    });

    test('a two-segment prefix with only its first segment present', () {
      // `/privacy/` and `/dialog/` are ordinary pages on their own — that is
      // why they need the second segment to count.
      expect(isAuth('https://m.facebook.com/privacy/policy/'), isFalse);
      expect(isAuth('https://m.facebook.com/privacy/'), isFalse);
      expect(isAuth('https://m.facebook.com/unified/'), isFalse);
      expect(isAuth('https://m.facebook.com/unified/something_else/'), isFalse);
      expect(isAuth('https://m.facebook.com/dialog/share'), isFalse);
      expect(isAuth('https://m.facebook.com/x/'), isFalse);
    });

    test('a relative or hostless uri does not throw', () {
      expect(isFacebookAuthUrl(Uri.parse('/checkpoint/')), isTrue);
      expect(isFacebookAuthUrl(Uri.parse('')), isFalse);
      expect(isFacebookAuthUrl(Uri.parse('about:blank')), isFalse);
    });
  });

  group('messengerNavigationFor', () {
    MessengerNavAction nav(String url) =>
        messengerNavigationFor(Uri.parse(url));

    test('keeps messenger.com in the Messenger webview', () {
      expect(nav('https://www.messenger.com/t/123'), MessengerNavAction.stay);
      expect(nav('https://m.me/123'), MessengerNavAction.stay);
    });

    test('keeps facebook.com in the Messenger webview', () {
      // Popping these to the feed crashed (SLIMSOCIAL-A) or painted black
      // (#337). Profiles, photos, and login all stay here.
      expect(
        nav('https://www.facebook.com/someone'),
        MessengerNavAction.stay,
      );
      expect(
        nav('https://m.facebook.com/checkpoint/start/'),
        MessengerNavAction.stay,
      );
      expect(
        nav('https://www.facebook.com/photo.php?fbid=1'),
        MessengerNavAction.stay,
      );
    });

    test('sends anything else outside the app', () {
      expect(nav('https://example.com/x'), MessengerNavAction.openExternal);
      expect(nav('https://youtube.com/watch?v=1'), MessengerNavAction.openExternal);
    });
  });

  group('facebookMessagesToMessenger', () {
    Uri? to(String url) => facebookMessagesToMessenger(Uri.parse(url));

    // The chat icon in Facebook's mobile top bar links to /messages/ on
    // facebook.com, and with a mobile user agent that page is nothing but a
    // "Get Messenger" install interstitial — the same one Firefox for Android
    // shows (#338). The app already has a Messenger screen that loads
    // messenger.com with a desktop agent; these addresses belong there.
    test('the inbox goes to the Messenger screen', () {
      expect(
        to('https://m.facebook.com/messages/'),
        Uri.parse('https://www.messenger.com/'),
      );
      expect(
        to('https://touch.facebook.com/messages'),
        Uri.parse('https://www.messenger.com/'),
      );
    });

    test('the jewel entry point and its query are dropped', () {
      expect(
        to('https://m.facebook.com/messages/?entrypoint=jewel&folder=inbox'),
        Uri.parse('https://www.messenger.com/'),
      );
    });

    test('a thread keeps its id', () {
      expect(
        to('https://m.facebook.com/messages/t/1234567890'),
        Uri.parse('https://www.messenger.com/t/1234567890'),
      );
      expect(
        to('https://m.facebook.com/messages/t/1234567890/'),
        Uri.parse('https://www.messenger.com/t/1234567890'),
      );
    });

    test('the legacy read view opens the inbox, not a guessed thread', () {
      // `tid=cid.c.A:B` is not a messenger.com thread id.
      expect(
        to('https://m.facebook.com/messages/read/?tid=cid.c.1:2'),
        Uri.parse('https://www.messenger.com/'),
      );
    });

    test('only the exact /messages segment matches', () {
      expect(to('https://m.facebook.com/messagesabc/'), isNull);
      expect(to('https://m.facebook.com/home.php'), isNull);
      expect(to('https://m.facebook.com/'), isNull);
      expect(to('https://m.facebook.com/groups/messages/'), isNull);
    });

    test('other hosts are not touched', () {
      expect(to('https://www.messenger.com/t/1'), isNull);
      expect(to('https://example.com/messages/'), isNull);
    });

    test('mbasic is left alone: its messages page renders without Messenger',
        () {
      expect(to('https://mbasic.facebook.com/messages/'), isNull);
    });
  });
}
