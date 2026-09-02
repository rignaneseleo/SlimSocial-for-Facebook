import 'dart:async';

import 'package:flutter/services.dart';

/// Lets one runtime-permission request run at a time.
///
/// permission_handler refuses a request while another is still showing its
/// dialog, and it refuses with a `PlatformException` nothing used to catch
/// (SLIMSOCIAL-V): a switch tapped twice, or the location and camera switches
/// tapped one after the other, took the settings screen down. The refusal is
/// not a failure of the second request so much as a statement that the first
/// is still on screen, so it is answered with `null` — the caller reads the
/// status back afterwards and stores that.
class PermissionRequestGate {
  bool _busy = false;

  /// The error code permission_handler uses for its re-entrancy refusal.
  static const String alreadyRunningCode =
      'PermissionHandler.PermissionManager';

  /// Runs [request], or returns null when one is already in flight — whether
  /// this gate knows it or the platform says so itself.
  ///
  /// Any other failure is the caller's to see.
  Future<T?> run<T>(Future<T> Function() request) async {
    if (_busy) return null;
    _busy = true;
    try {
      return await request();
    } on PlatformException catch (e) {
      if (e.code == alreadyRunningCode) return null;
      rethrow;
    } finally {
      _busy = false;
    }
  }
}
