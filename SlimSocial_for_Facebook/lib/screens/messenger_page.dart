import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:slimsocial_for_facebook/consts.dart';
import 'package:slimsocial_for_facebook/controllers/fb_controller.dart';
import 'package:slimsocial_for_facebook/main.dart';
import 'package:slimsocial_for_facebook/style/color_schemes.g.dart';
import 'package:slimsocial_for_facebook/utils/css.dart';
import 'package:slimsocial_for_facebook/utils/download_request.dart';
import 'package:slimsocial_for_facebook/utils/fb_navigation.dart';
import 'package:slimsocial_for_facebook/utils/file_chooser.dart';
import 'package:slimsocial_for_facebook/utils/js.dart';
import 'package:slimsocial_for_facebook/utils/link_menu.dart';
import 'package:slimsocial_for_facebook/utils/telemetry.dart';
import 'package:slimsocial_for_facebook/utils/utils.dart';
import 'package:slimsocial_for_facebook/utils/webview_permissions.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class MessengerPage extends ConsumerStatefulWidget {
  const MessengerPage({this.initialUrl, super.key});
  final String? initialUrl;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<MessengerPage> {
  late WebViewController _controller;
  AndroidWebViewController? _androidController;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = _initWebViewController();
  }

  WebViewController _initWebViewController() {
    var homepage = widget.initialUrl ?? kMessengerInboxUrl;
    if (!homepage.startsWith('http')) {
      //this screen is on facebook.com now, so a path handed to it belongs to
      //that host and not to messenger.com
      homepage = '${Uri.parse(kMessengerInboxUrl).origin}$homepage';
    }

    final controller = WebViewController(
      onPermissionRequest: handleWebViewPermissionRequest,
    )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(FacebookColors.darkBlue)
      ..setUserAgent(
        PrefController.getUserAgent(role: UserAgentRole.messenger),
      )
      ..addJavaScriptChannel(
        kLinkMenuChannelName,
        onMessageReceived: onLinkMenuMessage,
      )
      //the only way a `blob:` download can reach Dart: the bytes live in the
      //page and no url outside it resolves them. Registered here too because a
      //photo in a chat saves through exactly the same path as one in the feed.
      ..addJavaScriptChannel(
        kBlobDownloadChannelName,
        onMessageReceived: (message) => shareBlobDownload(message.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: onNavigationRequest,
          onPageStarted: (String url) async {
            //the delegate outlives this State: the route pops while loads are
            //still in flight, and context/ref are unusable once that happens
            if (!mounted) return;

            //inject the css as soon as the DOM is loaded
            await injectCss();
            if (!mounted) return;

            //the webview offers no long-press callback, so the only way to
            //reach a link's address is a listener the page itself carries
            await _controller.runJavaScript(
              CustomJs.whenDomReady(
                CustomJs.linkLongPressFunc(kLinkMenuChannelName),
              ),
            );
            if (!mounted) return;

            //re-read the zoom, so changing it in the settings takes effect on
            //the next load instead of needing the app restarted
            await _androidController?.setTextZoom(PrefController.getTextZoom());
          },
          onPageFinished: (String url) async {
            await runJs();
            if (kDebugMode) debugPrint(url);
          },
          onProgress: (int progress) {
            if (!mounted) return;

            setState(() {
              isLoading = progress < 100;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(homepage));

    if (Platform.isAndroid) {
      final androidController = controller.platform as AndroidWebViewController;
      _androidController = androidController;

      androidController
        //let videos and voice clips play with sound on the first tap
        ..setMediaPlaybackRequiresUserGesture(false)
        ..setTextZoom(PrefController.getTextZoom())
        ..setOnShowFileSelector(handleFileChooser)
        ..setGeolocationPermissionsPromptCallbacks(
          onShowPrompt: (request) async {
            final gpsPermission = sp.getBool(SpKeys.gpsPermission) ?? false;

            if (gpsPermission) {
              // request location permission
              final locationPermissionStatus =
                  await Permission.locationWhenInUse.request();

              // return the response
              return GeolocationPermissionsResponse(
                allow: locationPermissionStatus == PermissionStatus.granted,
                retain: false,
              );
            } else {
              // return the response denying the permission
              return const GeolocationPermissionsResponse(
                allow: false,
                retain: false,
              );
            }
          },
          onHidePrompt: () =>
              debugPrint("Geolocation permission prompt hidden"),
        );
    }
    return controller;
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Offers to copy or open the link the reader long-pressed.
  ///
  /// Everything arriving here is hostile input — any script on the page can
  /// post on a channel the app registers — so [parseLinkMenuMessage] does the
  /// deciding, and a rejected message is described rather than quoted.
  void onLinkMenuMessage(JavaScriptMessage message) {
    final link = parseLinkMenuMessage(message.message);
    if (link == null) {
      debugPrint("ignored link menu message: ${message.message.length} chars");
      return;
    }

    if (!mounted) return;
    unawaited(showLinkMenu(context, link));
  }

  Future<NavigationDecision> onNavigationRequest(
    NavigationRequest request,
  ) async {
    final uri = Uri.parse(request.url);

    //saving a photo out of a chat starts a download, and on Android every
    //download the webview starts is routed into this delegate rather than into
    //a callback of its own (webview_flutter_android 4.3.4,
    //android_webview_controller.dart:1455). Without this the cdn address went
    //to a Custom Tab and a `blob:` url went nowhere at all — see the feed's
    //copy of this and #348.
    //
    //Only the kind is reported. The address is the photo the reader is looking
    //at, which is their browsing.
    switch (classifyDownloadRequest(uri)) {
      case DownloadKind.image:
        Telemetry.captureIssue('download.intercepted', data: {'kind': 'image'});
        await saveImageFromUrl(request.url);
        return NavigationDecision.prevent;
      case DownloadKind.blob:
        Telemetry.captureIssue('download.intercepted', data: {'kind': 'blob'});
        showToast("${"downloading".tr()}...");
        //the bytes come back on kBlobDownloadChannelName, asynchronously
        try {
          await _controller.runJavaScript(
            CustomJs.fetchBlobFunc(request.url, kBlobDownloadChannelName),
          );
        }
        //a page exception comes back through runJavaScript on iOS, and there is
        //no recovery to attempt: the reader has already been told it started
        on Object catch (e, stack) {
          Telemetry.captureError(e, stack, hint: 'blob download');
        }
        return NavigationDecision.prevent;
      case DownloadKind.none:
        break;
    }

    switch (messengerNavigationFor(uri)) {
      case MessengerNavAction.stay:
        return NavigationDecision.navigate;
      case MessengerNavAction.openExternal:
        if (!mounted) return NavigationDecision.prevent;
        //the address of a link the user tapped is their browsing, and this line
        //used to run in release builds through a bare `print`: Sentry collects
        //stdout as a breadcrumb, so every conversation and every link opened
        //out of Messenger travelled with the next report.
        if (kDebugMode) debugPrint("Launching external url: ${request.url}");
        launchInAppUrl(context, request.url);
        return NavigationDecision.prevent;
    }
  }

  @override
  Widget build(BuildContext context) {
    //refresh the page whenever a new state (url) comes
    ref.listen<Uri>(
      fbWebViewProvider,
      (previous, next) async {
        final currentUrl = await _controller.currentUrl();
        if (currentUrl != null) {
          final currentUri = Uri.parse(currentUrl);
          if (currentUri.toString() == next.toString()) {
            debugPrint("refreshing keeping the y index...");
            //if I'm refreshing the page, I need to save the current scroll position
            final position = await _controller.getScrollPosition();
            final x = position.dx;
            final y = position.dy;

            //refresh
            await _controller.reload();

            //go back to the previous location
            if (y > 0 || x > 0) {
              await Future<void>.delayed(const Duration(milliseconds: 1500));
              debugPrint("restoring  $x, $y");
              await _controller.scrollTo(x.toInt(), y.toInt());
            }
            return;
          }
        }

        await _controller.loadRequest(next);
      },
    );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/icons/ic_messenger.png', height: 22),
            const SizedBox(width: 5),
            const Text('Messenger'),
          ],
        ),
        backgroundColor: CustomCss.darkThemeCss.isEnabled()
            ? FacebookColors.black
            : FacebookColors.official,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: WillPopScope(
        onWillPop: () async {
          if (await _controller.canGoBack()) {
            _controller.goBack();
            return false;
          }
          return true;
        },
        //edge-to-edge is enforced from target sdk 35+, so the transparent
        //navigation bar overlays the page; the app bar already covers the top
        child: SafeArea(
          top: false,
          child: Stack(
            alignment: AlignmentDirectional.bottomCenter,
            children: [
              WebViewWidget(
                controller: _controller,
              ),
              if (isLoading)
                const LinearProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(FacebookColors.official),
                  backgroundColor: Colors.transparent,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> runJs() async {
    final userCustomJs = PrefController.getUserCustomJs();
    if (userCustomJs?.isNotEmpty ?? false) {
      await _controller.runJavaScript(userCustomJs!);
    }
  }

  Future<void> injectCss() async {
    final accent = cssColorFromColor(Theme.of(context).colorScheme.primary);

    final sheets = <String, String>{
      'slim-messenger-adapt': CustomCss.adaptMessengerPageCss.code,
      'slim-messenger-list-height': CustomCss.messengerListHeightCss.code,
      'slim-messenger-fb-chrome':
          CustomCss.hideFacebookChromeOnMessengerCss.code,
      'slim-user-sheet':
          CustomCss.buildMessengerCss(PrefController.getUserCustomCss()),
    };

    final body = sheets.entries
        .map(
          (e) => CustomJs.injectCssFunc(
            resolveCssPlaceholders(e.value, accent: accent),
            id: e.key,
          ),
        )
        .join('\n');

    await _controller.runJavaScript(CustomJs.whenDomReady(body));
  }

/*  JavascriptChannel _setupJavascriptChannel(BuildContext context) {
    return JavascriptChannel(
      name: 'Toaster',
      onMessageReceived: (JavascriptMessage message) {
        // ignore: deprecated_member_use
        debugPrint('Message received: ${message.message}');
      },
    );
  }*/
}
