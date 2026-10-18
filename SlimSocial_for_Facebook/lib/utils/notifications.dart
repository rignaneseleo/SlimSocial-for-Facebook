import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:slimsocial_for_facebook/consts.dart';
import 'package:slimsocial_for_facebook/main.dart';

/// Background notifications (#269).
///
/// Facebook gives a webview no push channel, so the Android side
/// (`NotificationWorker.kt`) looks instead: every [kNotificationIntervalMinutes]
/// WorkManager loads the touch site in a hidden, already signed-in webview,
/// reads the jewel counters and posts a notification when the total went up.
///
/// This class is only the switch for it. Android only: on other platforms
/// every call is a no-op.
class SlimNotifications {
  const SlimNotifications._();

  static const MethodChannel _channel = MethodChannel('slimsocial/notifications');

  /// WorkManager's floor for a periodic job is 15 minutes; 30 keeps the battery
  /// and data cost low while still being useful.
  static const int kNotificationIntervalMinutes = 30;

  static bool get isEnabled => sp.getBool(SpKeys.backgroundNotifications) ?? false;

  /// Turns the check on or off and remembers the choice.
  static Future<void> setEnabled(bool enabled) async {
    await sp.setBool(SpKeys.backgroundNotifications, enabled);
    await _apply(enabled);
  }

  /// Re-registers the job after a cold start. WorkManager keeps the job across
  /// reboots, so this is only to pick up a changed interval; it replaces the
  /// existing job rather than adding a second one.
  static Future<void> restore() async {
    if (isEnabled) await _apply(true);
  }

  /// Dismisses the notification and forgets the last count, called when the
  /// reader opens the app (they are about to see what it was about).
  static Future<void> clear() => _invoke('clear');

  static Future<void> _apply(bool enabled) => enabled
      ? _invoke('enable', {'minutes': kNotificationIntervalMinutes})
      : _invoke('disable');

  static Future<void> _invoke(String method, [Map<String, Object?>? args]) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>(method, args);
    } on PlatformException catch (e) {
      debugPrint('notifications $method failed: $e');
    } on MissingPluginException {
      // not wired on this build
    }
  }
}
