import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:slimsocial_for_facebook/consts.dart';

part 'webview_providers.g.dart';

/// Provider for managing Facebook WebView URL state
@riverpod
class FbWebView extends _$FbWebView {
  @override
  Uri build() => Uri.parse(kTouchFacebookHomeUrl);

  void updateUrl(String url) => state = Uri.parse(url);
}

/// Provider for managing Messenger WebView URL state
@riverpod
class MessengerWebView extends _$MessengerWebView {
  @override
  Uri build() => Uri.parse(kMessengerUrl);

  void updateUrl(String url) => state = Uri.parse(url);
}
