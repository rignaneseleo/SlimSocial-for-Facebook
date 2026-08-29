import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:slimsocial_for_facebook/utils/telemetry.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Handles the WebView's request for files to hand back to a page `<input
/// type="file">` — the Facebook composer's photo picker, in practice.
///
/// This used to be gated behind the stored `photos_permission` flag, which made
/// photo upload permanently unreachable below Android 13: `Permission.photos` maps to
/// `READ_MEDIA_IMAGES`, which only exists from API 33, so on anything older the
/// permission could never be granted, the stored flag stayed false, and the
/// picker was never opened at all. The gate was also unnecessary — the system
/// document picker returns a URI the app is already granted access to, so it
/// needs no runtime permission on any API level.
Future<List<String>> handleFileChooser(FileSelectorParams params) async {
  //One probe, once per process, to learn what Facebook actually asks for.
  //`acceptTypes` is markup Facebook authored, not anything the user typed.
  Telemetry.captureIssue(
    'file_chooser.params',
    data: {
      'accept': params.acceptTypes.join('|'),
      'mode': params.mode.name,
    },
  );

  try {
    final result = await FilePicker.platform.pickFiles();
    if (result == null) return [];

    //Walk the list rather than reading `.single`, which throws a StateError on
    //any result that is not exactly one long.
    return result.files
        .map((f) => f.path)
        .whereType<String>()
        .map((p) => File(p).uri.toString())
        .toList();
  } on Object catch (e, stack) {
    //A throw here escapes into the WebView callback and takes the upload with
    //it, silently. Nothing has ever reported a failure from this path.
    Telemetry.captureError(e, stack, hint: 'file chooser');
    return [];
  }
}
