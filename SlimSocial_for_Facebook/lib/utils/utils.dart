import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';
import 'package:flutter_file_downloader/flutter_file_downloader.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:slimsocial_for_facebook/style/color_schemes.g.dart';

Future<void> launchInAppUrl(BuildContext context, String url) async {
  try {
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
