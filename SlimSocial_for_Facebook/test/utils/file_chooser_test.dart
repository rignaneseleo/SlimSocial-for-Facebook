import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

/// Source with comments removed.
///
/// These assertions are all of the form "this identifier is gone". Run against
/// raw source they also match the comments explaining why it is gone, so every
/// one of them fails on its own documentation.
String _code(String path) => _read(path)
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  //Source-level guards, in the style of lang_test.dart. The behaviour these
  //protect is a WebView callback that needs a device to exercise, but the
  //regression that broke it was visible in the source the whole time: a
  //permission gate in front of the picker. That is what is asserted here.
  group('the file chooser is not gated on a runtime permission', () {
    const screens = [
      'lib/screens/home_page.dart',
      'lib/screens/messenger_page.dart',
    ];

    for (final path in screens) {
      test('$path opens the picker unconditionally', () {
        final source = _code(path);

        //The gate that made photo upload unreachable below Android 13.
        //Permission.photos maps to READ_MEDIA_IMAGES, which does not exist
        //before API 33, so the stored flag could never become true and the
        //picker was never opened at all.
        expect(source, isNot(contains('SpKeys.photosPermission')));
        expect(source, isNot(contains('check_permission')));

        //Both screens carried a byte-identical copy. One handler now.
        expect(source, contains('setOnShowFileSelector(handleFileChooser)'));
      });
    }

    test('the settings screen no longer offers a photos toggle', () {
      final source = _code('lib/screens/settings_page.dart');

      expect(source, isNot(contains('Permission.photos')));
      expect(source, isNot(contains("'photo_permission'")));
    });

    test('the storage key itself is kept', () {
      //It exists on roughly 925k installs. Nothing reads it any more, but
      //deleting the constant would let a future change reuse the name for
      //something else and inherit whatever those devices already stored.
      expect(_code('lib/consts.dart'), contains('photosPermission'));
    });
  });

  group('the handler cannot throw into the WebView callback', () {
    late String source;

    setUpAll(() => source = _code('lib/utils/file_chooser.dart'));

    test('walks the result list instead of reading .single', () {
      //`.single` throws a StateError on any list that is not exactly one long,
      //and the throw escapes into the callback and takes the upload with it.
      expect(source, isNot(contains('.single')));
      expect(source, contains('whereType<String>()'));
    });

    test('catches everything and reports it', () {
      expect(source, contains('on Object catch'));
      expect(source, contains('Telemetry.captureError'));

      //Returning [] is what tells the page the user picked nothing, which is
      //the only honest answer once the pick has failed.
      final catchAt = source.indexOf('on Object catch');
      expect(source.substring(catchAt), contains('return [];'));
    });

    test('probes what Facebook actually asks for', () {
      //acceptTypes is markup Facebook authored, not anything the user typed.
      //Nothing in this repo records what arrives here, and the normaliser that
      //would use it cannot be written until that is known.
      expect(source, contains('file_chooser.params'));
      expect(source, contains('params.acceptTypes'));
    });
  });
}
