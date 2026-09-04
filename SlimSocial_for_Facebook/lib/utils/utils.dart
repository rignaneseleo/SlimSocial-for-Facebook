import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';
import 'package:flutter_file_downloader/flutter_file_downloader.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:slimsocial_for_facebook/controllers/fb_controller.dart';
import 'package:slimsocial_for_facebook/style/color_schemes.g.dart';
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
