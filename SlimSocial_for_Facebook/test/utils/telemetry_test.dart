import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slimsocial_for_facebook/consts.dart';
import 'package:slimsocial_for_facebook/main.dart';
import 'package:slimsocial_for_facebook/utils/ad_filter.dart';
import 'package:slimsocial_for_facebook/utils/telemetry.dart';

/// A story link as Facebook actually serves it: the poster and the post are
/// both in the query, and the numeric segment in the path is a page id.
const String _kStoryUrl =
    "https://m.facebook.com/story.php?story_fbid=10158371829201234&id=100001234567890";


/// Stands in for whatever a page script can hand the diagnostics channel: an
/// object that cannot be turned into text without throwing.
class _Explosive {
  @override
  String toString() => throw StateError("boom");
}

/// A random source that always draws the same number, so a sampling decision
/// is a fact of the test rather than a coin toss.
class _FixedRandom implements Random {
  _FixedRandom(this.value);

  final int value;

  @override
  int nextInt(int max) => value;

  @override
  double nextDouble() => value.toDouble();

  @override
  bool nextBool() => value == 0;
}

/// A random source that cannot be drawn from, so a test can assert that a
/// path never reaches one.
class _ExplosiveRandom implements Random {
  @override
  int nextInt(int max) => throw StateError("drawn from");

  @override
  double nextDouble() => throw StateError("drawn from");

  @override
  bool nextBool() => throw StateError("drawn from");
}

Future<void> _prefs([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  sp = await SharedPreferences.getInstance();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await _prefs();
    Telemetry.resetSession();
    Telemetry.random = Random();
  });

  group('a build with no dsn', () {
    test('runs the app and never initialises the sdk', () async {
      var ran = false;
      await Telemetry.init(() async => ran = true);

      expect(ran, isTrue);
      expect(Sentry.isEnabled, isFalse);
    });

    test('captureIssue does not even claim a rate limit slot', () {
      Telemetry.captureIssue('injection.no_posts_matched');

      //if the call had done any work the slot would be gone
      expect(Telemetry.allowIssue('injection.no_posts_matched'), isTrue);
    });

    test('captureError is a no-op rather than a throw', () {
      expect(
        () => Telemetry.captureError(Exception("boom"), StackTrace.current),
        returnsNormally,
      );
    });
  });

  group("the user's choice", () {
    test('defaults to on when nothing was ever stored', () {
      expect(Telemetry.isEnabled, isTrue);
    });

    test('is read back from the shared key cluster B writes', () async {
      await Telemetry.setEnabled(false);

      expect(sp.getBool(SpKeys.telemetryEnabled), isFalse);
      expect(Telemetry.isEnabled, isFalse);
    });

    test('opting back in starts a fresh session', () async {
      expect(Telemetry.allowIssue('injection.no_posts_matched'), isTrue);

      await Telemetry.setEnabled(false);
      await Telemetry.setEnabled(true);

      expect(Telemetry.allowIssue('injection.no_posts_matched'), isTrue);
    });
  });

  group('pageKind', () {
    test('recognises the feed however it was reached', () {
      for (final url in [
        "https://touch.facebook.com/home.php?sk=h_chr",
        "https://mbasic.facebook.com/home.php",
        "https://facebook.com/",
        "https://m.facebook.com",
      ]) {
        expect(Telemetry.pageKind(Uri.parse(url)), "feed", reason: url);
      }
    });

    test('recognises messenger on both of its hosts', () {
      expect(
        Telemetry.pageKind(Uri.parse("https://www.messenger.com/t/1234567890")),
        "messenger",
      );
      expect(
        Telemetry.pageKind(Uri.parse("https://m.me/some.person")),
        "messenger",
      );
    });

    test('everything else is only "other"', () {
      expect(Telemetry.pageKind(Uri.parse(_kStoryUrl)), "other");
      expect(
        Telemetry.pageKind(Uri.parse("https://facebook.com/some.person")),
        "other",
      );
    });
  });

  group('scrubUrl', () {
    test('keeps the host and drops the path and query', () {
      expect(Telemetry.scrubUrl(_kStoryUrl), "m.facebook.com/<other>");
    });

    test('leaves no digit of any id behind', () {
      expect(Telemetry.scrubUrl(_kStoryUrl), isNot(contains(RegExp(r'\d'))));
      expect(Telemetry.scrubUrl(_kStoryUrl), isNot(contains("story_fbid")));
    });

    test('a username in the path is not sent either', () {
      expect(
        Telemetry.scrubUrl("https://facebook.com/some.person/about"),
        "facebook.com/<other>",
      );
    });

    test('something that is not a url at all sends nothing', () {
      expect(Telemetry.scrubUrl("not a url"), "<url>");
    });
  });

  group('scrubText', () {
    test('replaces a url quoted inside an error message', () {
      final scrubbed = Telemetry.scrubText(
        "Failed to load $_kStoryUrl after 3 retries",
      );

      expect(scrubbed, "Failed to load m.facebook.com/<other> after 3 retries");
    });

    test('replaces a bare id that no url wrapped', () {
      expect(
        Telemetry.scrubText("profile 100001234567890 has no feed"),
        "profile <id> has no feed",
      );
    });

    test('leaves short numbers alone', () {
      expect(Telemetry.scrubText("hid 12 posts"), "hid 12 posts");
    });
  });

  group('scrubEvent', () {
    SentryEvent buildEvent() => SentryEvent(
          message: SentryMessage("injection failed on $_kStoryUrl"),
          request: SentryRequest(
            url: _kStoryUrl,
            queryString: "story_fbid=10158371829201234",
            cookies: "c_user=100001234567890",
            headers: const {"Referer": _kStoryUrl},
          ),
          user: SentryUser(id: "100001234567890"),
          serverName: "leo-pixel",
          exceptions: [
            SentryException(
              type: "StateError",
              value: "no element at $_kStoryUrl",
            ),
          ],
          breadcrumbs: [
            Breadcrumb(
              message: "navigated to $_kStoryUrl",
              category: "navigation",
              data: const {
                "to": _kStoryUrl,
                "from": "https://facebook.com/home.php",
              },
            ),
          ],
        );

    test('drops the event entirely when the user opted out', () async {
      await Telemetry.setEnabled(false);

      expect(Telemetry.scrubEvent(buildEvent()), isNull);
    });

    test('keeps the event when the user allows reporting', () {
      expect(Telemetry.scrubEvent(buildEvent()), isNotNull);
    });

    test('carries no id anywhere in the serialised payload', () {
      final scrubbed = Telemetry.scrubEvent(buildEvent())!;

      expect(scrubbed.toJson().toString(), isNot(contains("1000012345")));
      expect(scrubbed.toJson().toString(), isNot(contains("story_fbid")));
    });

    test('reduces the request to host and method', () {
      final request = Telemetry.scrubEvent(buildEvent())!.request!;

      expect(request.url, "m.facebook.com/<other>");
      expect(request.queryString, isNull);
      expect(request.cookies, isNull);
      expect(request.headers, isEmpty);
    });

    test('scrubs the message, the exception value and the breadcrumbs', () {
      final scrubbed = Telemetry.scrubEvent(buildEvent())!;

      expect(
        scrubbed.message!.formatted,
        "injection failed on m.facebook.com/<other>",
      );
      expect(
        scrubbed.exceptions!.single.value,
        "no element at m.facebook.com/<other>",
      );

      final crumb = scrubbed.breadcrumbs!.single;
      expect(crumb.message, "navigated to m.facebook.com/<other>");
      expect(crumb.data, {
        "to": "m.facebook.com/<other>",
        "from": "facebook.com/<feed>",
      });
    });

    test('drops the fields that identify the person and the device', () {
      final scrubbed = Telemetry.scrubEvent(buildEvent())!;

      expect(scrubbed.user, isNull);
      expect(scrubbed.serverName, isNull);
    });
  });

  group('the sdk options', () {
    SentryFlutterOptions configured() {
      final options = SentryFlutterOptions();
      Telemetry.configure(options);
      return options;
    }

    test('never turns a debugPrint into a breadcrumb', () {
      //fb_controller debugPrints the user's own custom css and js, which
      //DebugPrintIntegration would otherwise upload verbatim
      expect(configured().enablePrintBreadcrumbs, isFalse);
    });

    test('does not track sessions', () {
      //sessions are sent by the native layer, which no dart callback sees
      expect(configured().enableAutoSessionTracking, isFalse);
    });

    test('scrubs breadcrumbs as they are added, not only as they are sent', () {
      final options = configured();

      expect(options.beforeBreadcrumb, isNotNull);
      expect(options.beforeSend, isNotNull);
    });

    test('the registered callback scrubs a crumb on its way in', () {
      final scrubbed = configured().beforeBreadcrumb!(
        Breadcrumb(message: "navigated to $_kStoryUrl"),
        Hint(),
      );

      expect(scrubbed!.message, "navigated to m.facebook.com/<other>");
    });

    test('the registered callback scrubs feedback on its way out', () async {
      //the assignment in configure() is the whole defence: every other
      //feedback test calls scrubFeedbackEvent directly, so deleting the line
      //would leave the raw sentence shipping with the suite still green
      final options = configured();

      expect(options.beforeSendFeedback, isNotNull);

      final scrubbed = await options.beforeSendFeedback!(
        SentryEvent(
          type: 'feedback',
          level: SentryLevel.info,
          contexts: Contexts(
            feedback: SentryFeedback(
              message: "broken on $_kStoryUrl for 100001234567890",
            ),
          ),
        ),
        Hint(),
      );

      final message = scrubbed!.contexts.feedback!.message;
      expect(message, isNot(contains("story_fbid")));
      expect(message, isNot(contains("100001234567890")));
      expect(message, contains("<id>"));
    });

    test('sends nothing that shows what is on screen', () {
      final options = configured();

      expect(options.attachScreenshot, isFalse);
      //pinned on purpose, so the experimental flag has to be read here too
      // ignore: experimental_member_use
      expect(options.attachViewHierarchy, isFalse);
      expect(options.enableUserInteractionBreadcrumbs, isFalse);
      expect(options.sendDefaultPii, isFalse);
    });
  });

  group('scrubCrumb', () {
    test('strips the url and the ids out of message and data', () {
      final scrubbed = Telemetry.scrubCrumb(
        Breadcrumb(
          message: "navigated to $_kStoryUrl",
          category: "navigation",
          data: const {"to": _kStoryUrl, "profile": "100001234567890"},
        ),
      )!;

      expect(scrubbed.message, "navigated to m.facebook.com/<other>");
      expect(scrubbed.data, {"to": "m.facebook.com/<other>", "profile": "<id>"});
      expect(scrubbed.category, "navigation");
    });

    test('drops the crumb entirely when the user opted out', () async {
      await Telemetry.setEnabled(false);

      expect(Telemetry.scrubCrumb(Breadcrumb(message: "anything")), isNull);
    });

    test('drops the crumb rather than throwing on hostile contents', () {
      //a throw here would be worse than useless: sentry keeps the raw crumb
      final crumb = Breadcrumb(
        message: "diagnostics",
        data: {"payload": _Explosive()},
      );

      expect(Telemetry.scrubCrumb(crumb), isNull);
    });

    test('handles a null crumb', () {
      expect(Telemetry.scrubCrumb(null), isNull);
    });
  });

  group('off means off', () {
    test('the stored choice is readable without the sp global', () async {
      expect(await Telemetry.storedChoice(), isTrue);

      await _prefs({SpKeys.telemetryEnabled: false});

      expect(await Telemetry.storedChoice(), isFalse);
    });

    test('an opted-out start runs the app and starts no sdk', () async {
      await _prefs({SpKeys.telemetryEnabled: false});

      var ran = false;
      await Telemetry.init(() async => ran = true);

      expect(ran, isTrue);
      expect(Telemetry.sdkRunning, isFalse);
      expect(Sentry.isEnabled, isFalse);
    });

    test('toggling the setting never leaves an sdk running in this build', () async {
      await Telemetry.setEnabled(true);
      expect(Telemetry.sdkRunning, isFalse);
      expect(Sentry.isEnabled, isFalse);

      await Telemetry.setEnabled(false);
      expect(Telemetry.sdkRunning, isFalse);
      expect(Sentry.isEnabled, isFalse);
    });
  });

  group('the per-kind rate limit', () {
    test('lets a signal through once and never again this session', () {
      expect(Telemetry.allowIssue('injection.no_posts_matched'), isTrue);
      expect(Telemetry.allowIssue('injection.no_posts_matched'), isFalse);
      expect(Telemetry.allowIssue('injection.no_posts_matched'), isFalse);
    });

    test('throttles each kind on its own', () {
      expect(Telemetry.allowIssue('injection.no_posts_matched'), isTrue);
      expect(Telemetry.allowIssue('injection.no_ads_matched'), isTrue);
      expect(Telemetry.allowIssue('injection.no_posts_matched'), isFalse);
    });
  });

  group('sampling a success signal', () {
    test('a sampled-out kind sends nothing but still spends its slot', () {
      //49 out of 50 draws miss
      Telemetry.random = _FixedRandom(7);

      expect(Telemetry.allowSampled(kDiagPostsMatched, 50), isFalse);
      //once per process still means once: a miss does not hand the next call
      //of the same kind a second chance
      expect(Telemetry.allowIssue(kDiagPostsMatched), isFalse);
    });

    test('a sampled-in kind goes out saying what it was sampled at', () {
      Telemetry.random = _FixedRandom(0);

      expect(Telemetry.allowSampled(kDiagPostsMatched, 50), isTrue);
      expect(
        Telemetry.issueContext(const {'page': 'feed'}, 50),
        {'page': 'feed', 'sample_one_in': 50},
      );
    });

    test('an unsampled kind never draws from the random source', () {
      Telemetry.random = _ExplosiveRandom();

      expect(Telemetry.allowSampled(kDiagNoPostsMatched, 1), isTrue);
    });

    test('only the success signal is sampled', () {
      expect(kDiagSampleOneIn.keys, [kDiagPostsMatched]);
    });
  });

  group('feedback events', () {
    SentryEvent feedbackEvent(String message, {String? email, String? name}) =>
        SentryEvent(
          type: 'feedback',
          level: SentryLevel.info,
          contexts: Contexts(
            feedback: SentryFeedback(
              message: message,
              contactEmail: email,
              name: name,
            ),
          ),
        );

    tearDown(() => Telemetry.feedbackConsented = false);

    test('scrubs the url and the ids out of what the user typed', () {
      //the whole reason beforeSendFeedback is set: contexts rides through
      //_rebuildScrubbed untouched, so the message has to be cleaned here
      final event = Telemetry.scrubFeedbackEvent(
        feedbackEvent("broken on $_kStoryUrl for user 100001234567890"),
      );

      final message = event!.contexts.feedback!.message;
      expect(message, isNot(contains("story_fbid")));
      expect(message, isNot(contains("100001234567890")));
      expect(message, contains("<id>"));
      expect(message, contains("m.facebook.com"));
    });

    test('keeps the type so sentry still routes it to feedback', () {
      final event =
          Telemetry.scrubFeedbackEvent(feedbackEvent("the feed is blank"));

      expect(event, isNotNull);
      expect(event!.type, "feedback");
      expect(event.contexts.feedback!.message, "the feed is blank");
    });

    test('drops a contact email and a name even when handed both', () {
      final event = Telemetry.scrubFeedbackEvent(
        feedbackEvent("hi", email: "someone@example.com", name: "Someone"),
      );

      expect(event!.contexts.feedback!.contactEmail, isNull);
      expect(event.contexts.feedback!.name, isNull);
      expect(event.contexts.feedback!.url, isNull);
    });

    test('drops every context block the notice does not name', () {
      //contexts reaches a beforeSend callback already filled in — sentry runs
      //its event processors, LoadContextsIntegration and the flutter enricher
      //among them, before any of the callbacks — so this is the shape a real
      //feedback event has by the time the app sees it
      final event = Telemetry.scrubFeedbackEvent(
        SentryEvent(
          type: 'feedback',
          level: SentryLevel.info,
          contexts: Contexts(
            device: SentryDevice(model: "Pixel 7", manufacturer: "Google"),
            operatingSystem:
                SentryOperatingSystem(name: "Android", version: "14"),
            app: SentryApp(version: "2.4.0"),
            culture: SentryCulture(locale: "it-IT", timezone: "Europe/Rome"),
            feedback: SentryFeedback(message: "the feed is blank"),
          ),
        ),
      );

      //the notice names an app version, a device model and an android
      //version, and nothing else: a locale and a timezone identify a person
      //and tell a bug report nothing
      expect(event!.contexts.culture, isNull);
      expect(event.contexts.toJson().keys, isNot(contains("culture")));

      //and the three it does name have to survive, or the notice would be
      //untrue the other way round
      expect(event.contexts.device!.model, "Pixel 7");
      expect(event.contexts.operatingSystem!.version, "14");
      expect(event.contexts.app!.version, "2.4.0");
      expect(event.contexts.feedback!.message, "the feed is blank");
    });

    test('sends nothing at all for a user who opted out', () async {
      await _prefs({SpKeys.telemetryEnabled: false});

      expect(Telemetry.scrubFeedbackEvent(feedbackEvent("hi")), isNull);
    });

    test('lets an opted-out user through only while they are sending',
        () async {
      await _prefs({SpKeys.telemetryEnabled: false});
      Telemetry.feedbackConsented = true;

      final event = Telemetry.scrubFeedbackEvent(feedbackEvent("hi"));

      expect(event, isNotNull);
      expect(event!.contexts.feedback!.message, "hi");
    });

    test('a build with no dsn cannot collect feedback at all', () {
      //the tests run without --dart-define, so this is the f-droid build
      expect(Telemetry.canCollectFeedback, isFalse);
    });

    test('captureFeedback reports failure rather than pretending', () async {
      //a dialog that says "thanks, sent" when nothing was sent is a lie, so
      //the return value has to be honest with no dsn compiled in
      expect(
        await Telemetry.captureFeedback(stars: 2, text: "the feed is blank"),
        isFalse,
      );
    });

    test('an empty message is never sent', () async {
      expect(await Telemetry.captureFeedback(stars: 1, text: "   "), isFalse);
    });

    test('captureFeedback leaves consent off once it returns', () async {
      await Telemetry.captureFeedback(stars: 1, text: "hi");

      //the flag is the only thing standing between an opted-out user and a
      //later unrelated event, so it must never be left set
      await _prefs({SpKeys.telemetryEnabled: false});
      expect(
        Telemetry.scrubFeedbackEvent(feedbackEvent("unrelated")),
        isNull,
      );
    });
  });
}
