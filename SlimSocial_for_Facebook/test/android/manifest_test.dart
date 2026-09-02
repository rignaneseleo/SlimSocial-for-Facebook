import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level guards over the Android manifest, in the style of
/// lang_test.dart: the behaviour needs a device to exercise, but the mistake is
/// visible in the file.
void main() {
  late String manifest;

  setUpAll(() {
    manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  });

  test('the engine does not push opened links as named routes', () {
    // Flutter's Android embedding handles VIEW intents itself unless told
    // otherwise (FlutterActivityLaunchConfigs.deepLinkEnabled defaults to
    // true). With the app already running, that turns every facebook.com link
    // the user opens into `Navigator.pushNamed('https://...')`, and a
    // MaterialApp with no route by that name dereferences a null
    // `onUnknownRoute` and takes the app down (SLIMSOCIAL-4, 26 crashes in 5
    // days). app_links reads the same intent on its own, so the engine's copy
    // is only ever a liability here.
    final metaData = RegExp(
      r'<meta-data\s+android:name="flutter_deeplinking_enabled"\s+android:value="false"\s*/>',
    );

    expect(
      metaData.hasMatch(manifest),
      isTrue,
      reason: 'flutter_deeplinking_enabled must be declared false',
    );
  });

  test('the deep-link switch sits inside the launcher activity', () {
    // The engine reads it off the *activity's* metadata, not the application's.
    final activityStart = manifest.indexOf('<activity');
    final activityEnd = manifest.indexOf('</activity>');
    final metaAt = manifest.indexOf('flutter_deeplinking_enabled');

    expect(activityStart, greaterThanOrEqualTo(0));
    expect(metaAt, greaterThan(activityStart));
    expect(metaAt, lessThan(activityEnd));
  });
}
