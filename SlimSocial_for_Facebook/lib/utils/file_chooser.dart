import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:slimsocial_for_facebook/utils/telemetry.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// How the picker is opened for a page request in [mode].
///
/// Facebook's composer asks with `openMultiple` and an empty accept list —
/// measured in production, once per process, over four days (SLIMSOCIAL-9: 72
/// reports, every one identical). The picker used to ignore the mode and open
/// single-file regardless, so a photo post that is usually several photos
/// took one pick per photo.
///
/// The accept list is not used: it was always empty, and `FileType.any` is
/// what an empty list means.
({bool allowMultiple}) pickerOptionsFor(FileSelectorMode mode) =>
    (allowMultiple: mode == FileSelectorMode.openMultiple);

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
  final options = pickerOptionsFor(params.mode);

  try {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: options.allowMultiple,
    );
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
