import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
// `share_plus` re-exports the result types but not the platform class the
// instance is swapped on, so this comes from the interface package directly.
// ignore: depend_on_referenced_packages
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart'
    show SharePlatform;
import 'package:slimsocial_for_facebook/utils/utils.dart';

/// The smallest valid PNG: a 1x1 transparent pixel.
const String _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8'
    '/58BAAAA//8DAAM=';

/// Records what would have reached the share sheet.
///
/// A subclass rather than a mock: [SharePlatform]'s own constructor carries
/// the token the interface verifies, so nothing more is needed to stand in for
/// the platform here.
class _RecordingSharePlatform extends SharePlatform {
  final List<List<XFile>> shared = [];

  @override
  Future<ShareResult> shareXFiles(
    List<XFile> files, {
    String? subject,
    String? text,
    Rect? sharePositionOrigin,
    List<String>? fileNameOverrides,
  }) async {
    shared.add(files);
    return const ShareResult('', ShareResultStatus.success);
  }
}

void main() {
  group('capitalize', () {
    test('upper-cases the first letter and lower-cases the rest', () {
      expect('settings'.capitalize(), 'Settings');
      expect('SETTINGS'.capitalize(), 'Settings');
    });

    test('returns an empty string instead of throwing', () {
      // A missing translation resolves to '', and indexing it used to throw a
      // RangeError while the settings screen was being built.
      expect(''.capitalize(), '');
    });

    test('handles a single character', () {
      expect('a'.capitalize(), 'A');
    });
  });

  group('isNullOrEmpty', () {
    test('treats null, empty and blank as empty', () {
      expect(null.isNullOrEmpty(), isTrue);
      expect(''.isNullOrEmpty(), isTrue);
      expect('   '.isNullOrEmpty(), isTrue);
    });

    test('treats real content as not empty', () {
      expect('a'.isNullOrEmpty(), isFalse);
    });
  });

  group('shareBlobDownload', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    const toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    late List<MethodCall> toasts;
    late _RecordingSharePlatform share;

    setUp(() {
      toasts = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(toastChannel, (call) async {
            toasts.add(call);
            return true;
          });
      share = _RecordingSharePlatform();
      SharePlatform.instance = share;
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(toastChannel, null);
    });

    test('hands a decoded file to the share sheet', () async {
      shareBlobDownload(
        jsonEncode({
          'type': 'image/png',
          'data': 'data:image/png;base64,$_pngBase64',
        }),
      );
      await pumpEventQueue();

      expect(share.shared, hasLength(1));
      final file = share.shared.single.single;
      expect(file.mimeType, 'image/png');
      // A PNG starts with the eight-byte signature.
      expect((await file.readAsBytes()).sublist(0, 4), [
        0x89,
        0x50,
        0x4E,
        0x47,
      ]);
    });

    test('tells the reader when the page could not read the blob', () async {
      // #363: Facebook revokes the blob url as soon as it has clicked its own
      // download link. The reader has already seen "Downloading...", so the
      // failure has to end in a word rather than in silence.
      shareBlobDownload(jsonEncode({'error': 'unavailable'}));
      await pumpEventQueue();

      expect(share.shared, isEmpty);
      expect(toasts, hasLength(1));
      // `.tr()` yields the raw key here: no localization is loaded.
      expect((toasts.single.arguments as Map)['msg'], 'error_trylater');
    });

    test('stays silent on a message that is not ours', () async {
      // Any script on the page can post on the channel, and a toast for each
      // one would be a way to shout at the reader from inside a page.
      shareBlobDownload('not json at all');
      await pumpEventQueue();

      expect(share.shared, isEmpty);
      expect(toasts, isEmpty);
    });
  });
}
