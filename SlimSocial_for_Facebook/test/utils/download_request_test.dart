import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:slimsocial_for_facebook/utils/download_request.dart';

/// The smallest valid PNG: a 1x1 transparent pixel.
const String _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8'
    '/58BAAAA//8DAAM=';

String _blobMessage(String data, {String type = 'image/png'}) =>
    jsonEncode({'type': type, 'data': data});

void main() {
  group('classifyDownloadRequest', () {
    test('treats an https cdn address as an image', () {
      expect(
        classifyDownloadRequest(
          Uri.parse(
            'https://scontent-mxp1-1.xx.fbcdn.net/v/t39.30808-6/abc.jpg?dl=1',
          ),
        ),
        DownloadKind.image,
      );
    });

    test('treats a host carrying `scontent` as an image', () {
      // The suffix check covers fbcdn.net today; this is the belt for the same
      // cdn served under another domain.
      expect(
        classifyDownloadRequest(Uri.parse('https://scontent.example.com/a.jpg')),
        DownloadKind.image,
      );
    });

    test('is case-insensitive about the host', () {
      expect(
        classifyDownloadRequest(Uri.parse('https://Scontent.FBCDN.net/a.jpg')),
        DownloadKind.image,
      );
    });

    test('treats a blob url as a blob', () {
      expect(
        classifyDownloadRequest(
          Uri.parse('blob:https://www.facebook.com/1234-5678'),
        ),
        DownloadKind.blob,
      );
    });

    test('leaves an ordinary Facebook page alone', () {
      expect(
        classifyDownloadRequest(
          Uri.parse('https://www.facebook.com/photo/?fbid=1'),
        ),
        DownloadKind.none,
      );
    });

    test('leaves a javascript url alone', () {
      // The user's own script runs through `javascript:` urls, and treating one
      // as a download would swallow it.
      expect(
        classifyDownloadRequest(Uri.parse('javascript:void(0)')),
        DownloadKind.none,
      );
    });

    test('leaves a non-http scheme on a cdn-looking host alone', () {
      expect(
        classifyDownloadRequest(Uri.parse('fb://scontent.fbcdn.net/a.jpg')),
        DownloadKind.none,
      );
    });
  });

  group('parseBlobDownloadMessage', () {
    test('decodes a base64 data url', () {
      final blob = parseBlobDownloadMessage(
        _blobMessage('data:image/png;base64,$_pngBase64'),
      );

      expect(blob, isNotNull);
      expect(blob!.mimeType, 'image/png');
      // A PNG starts with the eight-byte signature.
      expect(blob.bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    });

    test('uses the data url own type when the field is missing', () {
      final blob = parseBlobDownloadMessage(
        jsonEncode({'data': 'data:image/webp;base64,$_pngBase64'}),
      );

      expect(blob?.mimeType, 'image/webp');
    });

    test('returns null on malformed JSON', () {
      expect(parseBlobDownloadMessage('not json at all'), isNull);
    });

    test('returns null when the payload is not a data url', () {
      // Any script on the page can post here, so an address is not a file.
      expect(
        parseBlobDownloadMessage(
          _blobMessage('https://example.com/steal?q=$_pngBase64'),
        ),
        isNull,
      );
    });

    test('returns null on a data url that is not base64', () {
      expect(
        parseBlobDownloadMessage(_blobMessage('data:text/plain,hello')),
        isNull,
      );
    });

    test('returns null on undecodable base64', () {
      expect(
        parseBlobDownloadMessage(_blobMessage('data:image/png;base64,@@@@')),
        isNull,
      );
    });

    test('returns null on an empty payload', () {
      expect(
        parseBlobDownloadMessage(_blobMessage('data:image/png;base64,')),
        isNull,
      );
    });

    test('returns null above the size cap', () {
      // The bytes travel base64-encoded and are held in memory twice on the
      // way, so an unbounded payload is a way to kill the app from the page.
      final oversized = 'A' * (kMaxBlobDownloadBytes ~/ 3 * 4 + 8);

      expect(
        parseBlobDownloadMessage(
          _blobMessage('data:image/png;base64,$oversized'),
        ),
        isNull,
      );
    });
  });

  group('extensionForMimeType', () {
    test('maps jpeg to the extension galleries expect', () {
      expect(extensionForMimeType('image/jpeg'), 'jpg');
    });

    test('uses the subtype for an ordinary type', () {
      expect(extensionForMimeType('image/png'), 'png');
      expect(extensionForMimeType('video/mp4'), 'mp4');
    });

    test('drops parameters the page appended', () {
      expect(extensionForMimeType('image/png; charset=binary'), 'png');
    });

    test('refuses a subtype that is not an extension', () {
      // The type comes from the page, and the name is what the receiving app
      // decides what to do by.
      expect(extensionForMimeType('application/x-msdownload'), 'bin');
      expect(extensionForMimeType('image/a b'), 'bin');
      expect(extensionForMimeType(''), 'bin');
    });
  });
}
