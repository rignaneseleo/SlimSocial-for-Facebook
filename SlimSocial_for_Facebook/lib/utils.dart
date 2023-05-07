import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';
import 'package:flutter_file_downloader/flutter_file_downloader.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:slimsocial_for_facebook/style/color_schemes.g.dart';

void launchInAppUrl(BuildContext context, String url) async {
  try {
    await launch(
      url,
      customTabsOption: CustomTabsOption(
        toolbarColor: Theme.of(context).primaryColor,
        enableDefaultShare: true,
        enableUrlBarHiding: false,
        showPageTitle: true,
        enableInstantApps: true,
        extraCustomTabs: const <String>[
          // ref. https://play.google.com/store/apps/details?id=org.mozilla.firefox
          'org.mozilla.firefox',
          // ref. https://play.google.com/store/apps/details?id=com.microsoft.emmx
          'com.microsoft.emmx',
        ],
      ),
      safariVCOption: SafariViewControllerOption(
        preferredBarTintColor: Theme.of(context).primaryColor,
        preferredControlTintColor: Colors.white,
        barCollapsingEnabled: true,
        entersReaderIfAvailable: false,
        dismissButtonStyle: SafariViewControllerDismissButtonStyle.close,
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
      timeInSecForIosWeb: 1,
      backgroundColor: FacebookColors.blue,
      textColor: FacebookColors.white,
      fontSize: 16.0,
    );

extension StringExtension on String {
  String capitalize() {
    return "${this![0].toUpperCase()}${this!.substring(1).toLowerCase()}";
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
  var file = await FileDownloader.downloadFile(
    url: url,
    onDownloadError: (String? error) {
      showToast("error_trylater".tr());
    },
  );
  return file?.path;
}
