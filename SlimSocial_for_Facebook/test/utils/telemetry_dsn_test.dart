/// The feedback send path, exercised in a build that has a dsn compiled in.
///
/// These cases live apart from `telemetry_test.dart` because the two files
/// need opposite builds. That file pins down what a dsn-less build does —
/// `canCollectFeedback` is false, `captureFeedback` refuses, toggling the
/// setting never leaves an sdk running — and every one of those assertions
/// flips the moment a dsn exists. One run cannot satisfy both, so everything
/// that needs a dsn is gathered here instead.
///
/// Run it with:
///
/// ```sh
/// fvm flutter test \
///   --dart-define=SENTRY_DSN=https://abc123def456@localhost:1/1 \
///   test/utils/telemetry_dsn_test.dart
/// ```
///
/// The dsn only has to parse. `localhost:1` routes nowhere, so nothing these
/// tests hand the sdk can leave the machine.
///
/// Under a plain `fvm flutter test` the group is skipped rather than failed:
/// `SENTRY_DSN` is empty there, [Telemetry.captureFeedback] returns on its
/// first line, and every assertion below would be checking nothing.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slimsocial_for_facebook/consts.dart';
import 'package:slimsocial_for_facebook/main.dart';
import 'package:slimsocial_for_facebook/utils/telemetry.dart';

/// Printed by the runner in place of every case here when the build has no
/// dsn, so the command that does run them is never more than one line away.
const String _needsDsn = 'needs a compiled-in dsn: fvm flutter test '
    '--dart-define=SENTRY_DSN=https://abc123def456@localhost:1/1 '
    'test/utils/telemetry_dsn_test.dart';

/// The same dsn the app itself was compiled with, so a client started from a
/// test behaves exactly like one [Telemetry] would have started.
const String _dsn = String.fromEnvironment('SENTRY_DSN');

Future<void> _prefs([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  sp = await SharedPreferences.getInstance();
}

/// An event shaped the way the sdk hands feedback to the scrubber.
SentryEvent _feedbackEvent(String message) => SentryEvent(
      type: 'feedback',
      level: SentryLevel.info,
      contexts: Contexts(feedback: SentryFeedback(message: message)),
    );

/// The same, as the sdk's own event processors leave it: they run ahead of
/// every `beforeSend` callback in `sentry_client`, so `contexts` is already
/// full of device, os, app and culture by the time the app is asked.
SentryEvent _enrichedFeedbackEvent(String message) => SentryEvent(
      type: 'feedback',
      level: SentryLevel.info,
      contexts: Contexts(
        device: SentryDevice(model: 'Pixel 7', manufacturer: 'Google'),
        operatingSystem: SentryOperatingSystem(name: 'Android', version: '14'),
        app: SentryApp(version: '2.4.0'),
        culture: SentryCulture(locale: 'it-IT', timezone: 'Europe/Rome'),
        feedback: SentryFeedback(message: message),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('captureFeedback with a dsn compiled in', () {
    setUp(() async {
      await _prefs();
      //the sdk flag is static and outlives a test. setEnabled(false) is the
      //only lever a test has on it, so every case below starts from no client
      await Telemetry.setEnabled(false);
      //and from a user who has not opted out of anything
      await _prefs();
      Telemetry.resetSession();
      Telemetry.feedbackConsented = false;
    });

    tearDown(() async {
      await _prefs();
      await Telemetry.setEnabled(false);
      Telemetry.feedbackConsented = false;
    });

    test('the empty-message guard is what refuses an empty send', () async {
      //with no dsn this returns on the first line, so the guard below it is
      //only ever reached in this build
      expect(Telemetry.canCollectFeedback, isTrue);

      expect(await Telemetry.captureFeedback(stars: 1, text: '   '), isFalse);
      //refused without starting a client to find out
      expect(Telemetry.sdkRunning, isFalse);
    });

    test('a completed send leaves consent off behind it', () async {
      expect(await Telemetry.captureFeedback(stars: 1, text: 'hi'), isTrue);
      //proves the send really did run: without this the cases here could all
      //be passing because nothing happened
      expect(Telemetry.sdkRunning, isTrue);

      //the flag is the only thing between someone who opted out and every
      //later event of theirs, so it must not outlive the call that set it
      await _prefs({SpKeys.telemetryEnabled: false});
      expect(Telemetry.scrubFeedbackEvent(_feedbackEvent('x')), isNull);
    });

    test('consent is cleared on the path that also closes the client',
        () async {
      //this is the `finally` running after the send did not simply succeed.
      //A throw out of the try is not reachable from a test: sentry's hub
      //catches and logs every error captureFeedback can raise, so the
      //unroutable dsn above fails silently instead. What is reachable is the
      //other order-sensitive path through the same block — the clear and the
      //close, where a close that threw with the clear still queued behind it
      //would strand the flag set for the rest of the session
      await _prefs({SpKeys.telemetryEnabled: false});

      await Telemetry.captureFeedback(stars: 1, text: 'hi');

      //the close half really did run, so the clear is not passing merely by
      //having skipped the half that can fail
      expect(Telemetry.sdkRunning, isFalse);
      expect(Sentry.isEnabled, isFalse);

      //and the flag, which is the only thing between this user and every
      //later event of theirs, did not outlive the call
      expect(Telemetry.scrubFeedbackEvent(_feedbackEvent('x')), isNull);
    });

    test('sends only the context blocks the notice names', () async {
      final options = SentryFlutterOptions();
      Telemetry.configure(options);

      final scrubbed = await options.beforeSendFeedback!(
        _enrichedFeedbackEvent('the feed is blank'),
        Hint(),
      );

      //the dialog's notice promises an app version, a device model and an
      //android version
      expect(scrubbed!.contexts.app!.version, '2.4.0');
      expect(scrubbed.contexts.device!.model, 'Pixel 7');
      expect(scrubbed.contexts.operatingSystem!.version, '14');

      //and promises nothing else, so nothing else the sdk attached may ride
      //along: a locale and a timezone identify a person
      expect(scrubbed.contexts.culture, isNull);
      expect(scrubbed.contexts.toJson().keys, isNot(contains('culture')));
    });

    test('a client the flag never saw is still closed for an opted-out user',
        () async {
      //_start assigns _sdkRunning only once SentryFlutter.init has returned,
      //so an init that raises after bringing the client up leaves exactly
      //this state behind: no flag, live client. Starting one here reproduces
      //it without needing init to fail
      await Sentry.init((options) => options.dsn = _dsn);
      expect(Sentry.isEnabled, isTrue);
      expect(Telemetry.sdkRunning, isFalse);

      await Telemetry.setEnabled(false);

      //someone who has reporting off is left with no client, whatever the
      //local flag happened to say
      expect(Sentry.isEnabled, isFalse);
    });

    test('an opted-out send leaves no sdk running behind it', () async {
      //pressing send is consent for that one message and nothing more: the
      //client started to carry it must not outlive the call
      await _prefs({SpKeys.telemetryEnabled: false});

      await Telemetry.captureFeedback(stars: 1, text: 'hi');

      expect(Telemetry.sdkRunning, isFalse);
      expect(Sentry.isEnabled, isFalse);
    });
  }, skip: Telemetry.canCollectFeedback ? null : _needsDsn);
}
