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
      //other order-sensitive path through the same block — the close running
      //first and the flag being cleared second, where anything going wrong
      //in the close would strand the flag set for the rest of the session
      await _prefs({SpKeys.telemetryEnabled: false});

      await Telemetry.captureFeedback(stars: 1, text: 'hi');

      expect(Telemetry.scrubFeedbackEvent(_feedbackEvent('x')), isNull);
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
