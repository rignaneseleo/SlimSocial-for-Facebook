import 'package:easy_localization/easy_localization.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:slimsocial_for_facebook/consts.dart';
import 'package:slimsocial_for_facebook/main.dart';
import 'package:slimsocial_for_facebook/utils/utils.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Whether SlimSocial knows how to answer a request for [types].
///
/// Only the camera is supported. The microphone (voice and video calls) would
/// additionally need a `RECORD_AUDIO` manifest entry and a settings toggle of
/// its own, so those requests are refused instead of being left unanswered.
bool isWebViewPermissionSupported(Set<WebViewPermissionResourceType> types) {
  return types.isNotEmpty &&
      types.every((type) => type == WebViewPermissionResourceType.camera);
}

/// Answers a permission request coming from the web content.
///
/// Nothing used to listen for these requests, so the webview never received an
/// answer and the camera toggle in the settings had no effect whatsoever:
/// taking a photo from inside Facebook simply did nothing.
Future<void> handleWebViewPermissionRequest(
  WebViewPermissionRequest request,
) async {
  if (!isWebViewPermissionSupported(request.types)) {
    return request.deny();
  }

  //the user has to opt in from the settings first
  if (!(sp.getBool(SpKeys.cameraPermission) ?? false)) {
    showToast("check_permission".tr());
    return request.deny();
  }

  //...and Android still requires the OS-level grant on top of that
  final status = await Permission.camera.request();
  if (status.isGranted) return request.grant();

  showToast("check_permission".tr());
  return request.deny();
}
