import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';
import 'package:flutter_file_downloader/flutter_file_downloader.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:slimsocial_for_facebook/controllers/fb_controller.dart';
import 'package:slimsocial_for_facebook/style/color_schemes.g.dart';
import 'package:slimsocial_for_facebook/utils/download_request.dart';
// flutter_custom_tabs also exports `launchUrl`, so this one needs a prefix.
import 'package:url_launcher/url_launcher.dart' as url_launcher;

Future<void> launchInAppUrl(BuildContext context, String url) async {
  try {
    if (PrefController.usesSystemBrowser()) {
      await url_launcher.launchUrl(
        Uri.parse(url),
        mode: url_launcher.LaunchMode.externalApplication,
      );
      return;
    }

    await launchUrl(
      Uri.parse(url),
      customTabsOptions: const CustomTabsOptions(
        showTitle: true,
        urlBarHidingEnabled: false,
        shareState: CustomTabsShareState.on,
        colorSchemes: CustomTabsColorSchemes(
          colorScheme: CustomTabsColorScheme.light,
        ),
        browser: CustomTabsBrowserConfiguration(
          prefersDefaultBrowser: true,
          fallbackCustomTabs: <String>[
            // ref. https://play.google.com/store/apps/details?id=org.mozilla.firefox
            'org.mozilla.firefox',
            // ref. https://play.google.com/store/apps/details?id=com.microsoft.emmx
            'com.microsoft.emmx',
          ],
        ),
      ),
    );
  } catch (e) {
    // An exception is thrown if browser app is not installed on Android device.
    debugPrint(e.toString());
  }
}

void showToast(String text) => Fluttertoast.showToast(
      msg: text,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: FacebookColors.blue,
      textColor: FacebookColors.white,
      fontSize: 16,
    );

extension StringExtension on String {
  String capitalize() {
    //a missing translation resolves to an empty string, and indexing it
    //used to throw a RangeError while building the settings screen
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}

extension StringNullExtension on String? {
  bool isNullOrEmpty() {
    if (this == null) return true;
    if (this!.trim().isEmpty) return true;

    return false;
  }
}

Future<String?> downloadImage(String url) async {
  final file = await FileDownloader.downloadFile(
    url: url,
    onDownloadError: (String? error) {
      showToast("error_trylater".tr());
    },
  );
  return file?.path;
}

/// Downloads [url] into Downloads, tells the reader, and opens it.
///
/// Lives here rather than on a screen because two callers have to behave the
/// same way: the app bar's save button, and the navigation delegate, which is
/// where Facebook's own Save menu item lands (#348). Duplicating the toasts is
/// how the two drifted apart before.
Future<void> saveImageFromUrl(String url) async {
  showToast("${"downloading".tr()}...");
  final path = await downloadImage(url);
  if (path == null) return;

  showToast('image_saved'.tr());
  //not awaited: the toast is the confirmation, and opening the viewer is a
  //convenience that must not hold up the caller
  unawaited(OpenFile.open(path));
}

/// Hands the reader a file the page read out of a `blob:` url.
///
/// The share sheet, rather than a write into Downloads, because the bytes are
/// already in memory: sharing them needs no storage permission and no
/// dependency the app does not already have, and the sheet's own targets cover
/// saving to Photos or Files.
///
/// [message] is what `CustomJs.fetchBlobFunc` posted.
/// [parseBlobDownloadMessage] does the deciding, because this is hostile
/// input: any script on the page can post on a channel the app registers. A
/// rejected message is described, never quoted — `debugPrint` output is
/// collected as a breadcrumb on whatever is reported next.
void shareBlobDownload(String message) {
  final blob = parseBlobDownloadMessage(message);
  if (blob == null) {
    debugPrint("ignored blob download: ${message.length} chars");
    return;
  }

  //the file only ever exists inside the share sheet, so the name is just
  //something recognisable in whatever app receives it
  final name = 'facebook-${DateTime.now().millisecondsSinceEpoch}'
      '.${extensionForMimeType(blob.mimeType)}';

  //the channel callback is synchronous, and there is nothing to do with the
  //sheet's outcome: the reader either picks a target or dismisses it
  unawaited(
    Share.shareXFiles([
      XFile.fromData(blob.bytes, mimeType: blob.mimeType, name: name),
    ]),
  );
}
