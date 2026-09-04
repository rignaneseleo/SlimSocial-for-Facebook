import 'dart:convert';
import 'dart:typed_data';

/// What a navigation request that the webview raised for a download is.
///
/// `webview_flutter_android` has no download callback of its own: its
/// `DownloadListener` calls straight into the same handler the navigation
/// delegate uses (android_webview_controller.dart:1455 in 4.3.4). So a
/// response carrying `Content-Disposition: attachment`, an `<a download>` and
/// a `blob:` url all arrive at `onNavigationRequest` looking like an ordinary
/// link tap, and the app used to hand them to a Custom Tab. That is #348: the
/// photo viewer's Save does nothing.
enum DownloadKind {
  /// Not a download. Handled by the ordinary navigation rules.
  none,

  /// A media file on Facebook's cdn, downloadable over http.
  image,

  /// A `blob:` url. Its bytes live in the page and nothing outside the page
  /// can read them, so the file has to be fetched in JavaScript.
  blob,
}

/// Facebook serves user media from `*.fbcdn.net`, which is deliberately not in
/// `kPermittedHostnamesFb` — the app wants those addresses handled, not loaded
/// in the feed webview.
const String _kCdnHostSuffix = 'fbcdn.net';

/// Hosts for the same cdn spell the name in several ways
/// (`scontent-mxp1-1.xx.fbcdn.net`, `scontent.xx.fbcdn.net`). The suffix above
/// catches them all today; this is the belt for a host that carries the same
/// marker under some other domain.
const String _kCdnHostMarker = 'scontent';

/// Classifies a request the webview raised, so a download can be saved instead
/// of thrown at a browser that cannot open it.
DownloadKind classifyDownloadRequest(Uri uri) {
  if (uri.scheme == 'blob') return DownloadKind.blob;

  if (uri.scheme != 'http' && uri.scheme != 'https') return DownloadKind.none;

  final host = uri.host.toLowerCase();
  if (host.endsWith(_kCdnHostSuffix)) return DownloadKind.image;
  if (host.contains(_kCdnHostMarker)) return DownloadKind.image;

  return DownloadKind.none;
}

/// Largest blob the app will take off the page.
///
/// The bytes travel base64-encoded through a JavaScript channel and are held
/// in memory twice on the way, so an unbounded payload is a way to kill the
/// app from inside the page. A photo or a short video sits far below this.
const int kMaxBlobDownloadBytes = 25 * 1024 * 1024;

/// Parses what the blob-download script posts back.
///
/// The payload is `{"type": "<mime>", "data": "data:<mime>;base64,<bytes>"}`.
/// Any script on the page can post on a channel the app registers, so this is
/// treated as hostile input: anything that is not a decodable base64 data url
/// within the size cap returns null and is dropped.
({Uint8List bytes, String mimeType})? parseBlobDownloadMessage(String json) {
  Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on Object catch (_) {
    return null;
  }
  if (decoded is! Map) return null;

  final data = decoded['data'];
  if (data is! String) return null;

  //only a data url, and only a base64 one: a `data:` url with percent-encoded
  //text in it is not a file the page just read for us
  final comma = data.indexOf(',');
  if (comma < 0) return null;
  final header = data.substring(0, comma);
  if (!header.startsWith('data:')) return null;
  if (!header.endsWith(';base64')) return null;

  final payload = data.substring(comma + 1);
  //3 base64 characters carry at most 3 bytes, so this bounds the decode
  //without doing it first
  if (payload.length > kMaxBlobDownloadBytes ~/ 3 * 4 + 4) return null;

  Uint8List bytes;
  try {
    bytes = base64Decode(payload);
  } on Object catch (_) {
    return null;
  }
  if (bytes.isEmpty) return null;
  if (bytes.length > kMaxBlobDownloadBytes) return null;

  //the mime type only ever names a file extension and is reported to nobody,
  //but it still comes from the page: fall back to the header's own type, and
  //to octet-stream, rather than trusting a free-form string
  final type = decoded['type'];
  final headerType = header.substring('data:'.length, header.length - 7);
  final mimeType = type is String && type.isNotEmpty
      ? type
      : (headerType.isNotEmpty ? headerType : 'application/octet-stream');

  return (bytes: bytes, mimeType: mimeType);
}

/// File extension for [mimeType], for naming the file the share sheet hands on.
///
/// The share sheet's target decides what to do with the file largely by its
/// name, so an image saved as `.bin` lands in the wrong place or is refused.
String extensionForMimeType(String mimeType) {
  final subtype = mimeType.split('/').last.split(';').first.trim().toLowerCase();
  if (subtype.isEmpty) return 'bin';
  //`image/jpeg` is the type; `.jpg` is what every gallery expects
  if (subtype == 'jpeg') return 'jpg';
  if (subtype == 'svg+xml') return 'svg';
  if (subtype == 'quicktime') return 'mov';
  //a subtype with anything odd in it is not an extension
  if (!RegExp(r'^[a-z0-9]{1,8}$').hasMatch(subtype)) return 'bin';
  return subtype;
}
