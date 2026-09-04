import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:slimsocial_for_facebook/utils/url_cleaner.dart';
import 'package:slimsocial_for_facebook/utils/utils.dart';

/// A link the reader long-pressed inside the webview.
class LongPressedLink {
  const LongPressedLink({required this.uri, required this.text});

  /// Where the link goes, with the reading-session parameters already gone.
  final Uri uri;

  /// The anchor's own label, or an empty string when it had none.
  final String text;
}

/// Reads a message posted on the link-menu channel, or returns null.
///
/// Everything arriving here is hostile input: any script on facebook.com can
/// post on a channel this app registers, so nothing is trusted about the
/// payload's shape. A message that is not an object with a http(s) `href` and
/// a string `text` is dropped rather than repaired, because the only thing
/// downstream of this is a sheet that copies the url or opens it.
LongPressedLink? parseLinkMenuMessage(String json) {
  Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    return null;
  }

  if (decoded is! Map<String, dynamic>) return null;

  final href = decoded['href'];
  final text = decoded['text'];
  if (href is! String || text is! String) return null;

  //the scheme is checked again on this side: the script filters it too, but
  //the script is not what decides whether this app hands a url to a browser
  final uri = Uri.tryParse(stripTrackingParams(href));
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  if (uri.host.isEmpty) return null;

  return LongPressedLink(uri: uri, text: text);
}

/// Shows what can be done with a long-pressed [link].
///
/// This is the whole of the feature the platform used to give for free: the
/// WebView's own context menu offered "copy link address", and it is gone
/// (#183). Two entries only, because copying and opening are the two things
/// the old menu was used for.
Future<void> showLinkMenu(BuildContext context, LongPressedLink link) {
  final url = link.uri.toString();

  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              //an anchor with no label — an image link, most of the time —
              //would otherwise put an empty line above the url
              title: link.text.isEmpty ? null : Text(link.text),
              subtitle: Text(url),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.link),
              title: Text('copy_link'.tr()),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await Clipboard.setData(ClipboardData(text: url));
                showToast('link_copied'.tr());
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_browser),
              title: Text('open_in_browser'.tr()),
              onTap: () {
                Navigator.of(sheetContext).pop();
                //not awaited: `context` is only safe to use while no
                //asynchronous gap has passed, and the launch itself has
                //nothing left to report back here. It honours the
                //system-browser preference on its own.
                unawaited(launchInAppUrl(context, url));
              },
            ),
          ],
        ),
      );
    },
  );
}
