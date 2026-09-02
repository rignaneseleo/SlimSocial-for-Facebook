import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slimsocial_for_facebook/utils/permission_gate.dart';

void main() {
  group('PermissionRequestGate', () {
    test('runs the request and hands back its result', () async {
      final gate = PermissionRequestGate();

      final result = await gate.run(() async => 'granted');

      expect(result, 'granted');
    });

    test('refuses a second request while the first is still in flight',
        () async {
      // A switch tapped twice, or two switches tapped in a row, used to send
      // two requests to permission_handler, which answers the second with a
      // PlatformException that nothing caught (SLIMSOCIAL-V).
      final gate = PermissionRequestGate();
      final first = Completer<String>();

      final firstRun = gate.run(() => first.future);
      final second = await gate.run(() async => 'second');

      expect(second, isNull);

      first.complete('first');
      expect(await firstRun, 'first');
    });

    test('opens again once the request has finished', () async {
      final gate = PermissionRequestGate();

      await gate.run(() async => 'one');
      final again = await gate.run(() async => 'two');

      expect(again, 'two');
    });

    test('opens again when the request throws', () async {
      final gate = PermissionRequestGate();

      await expectLater(
        gate.run(() async => throw StateError('boom')),
        throwsStateError,
      );

      expect(await gate.run(() async => 'after'), 'after');
    });

    test('swallows the "already running" refusal from permission_handler',
        () async {
      // The plugin's own re-entrancy error. Reaching here means the OS dialog
      // for the other request is still up, so there is nothing to show and
      // nothing to store: the caller reads the status back afterwards.
      final gate = PermissionRequestGate();

      final result = await gate.run<String>(
        () async => throw PlatformException(
          code: 'PermissionHandler.PermissionManager',
          message: 'A request for permissions is already running',
        ),
      );

      expect(result, isNull);
    });

    test('lets any other platform failure through', () async {
      final gate = PermissionRequestGate();

      await expectLater(
        gate.run<String>(
          () async => throw PlatformException(code: 'something_else'),
        ),
        throwsA(isA<PlatformException>()),
      );
    });
  });
}
