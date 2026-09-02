import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The app used to build its text theme with google_fonts, which downloads
/// Roboto from fonts.gstatic.com on every cold start. Roboto is Android's own
/// system font, so the request bought nothing, and when it failed — captive
/// portals, flaky cellular, a TLS handshake cut short — it surfaced as a fatal
/// unhandled exception (SLIMSOCIAL-7, 35 events in three days). For an app
/// whose pitch is being a thin private wrapper, a call home to Google on
/// launch is also the wrong default.
void main() {
  test('nothing imports google_fonts', () {
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.readAsStringSync().contains('google_fonts'))
        .map((f) => f.path)
        .toList();

    expect(offenders, isEmpty);
  });

  test('google_fonts is not a dependency', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, isNot(contains('google_fonts')));
  });
}
