import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:slimsocial_for_facebook/consts.dart';
import 'package:slimsocial_for_facebook/controllers/fb_controller.dart';
import 'package:slimsocial_for_facebook/main.dart';
import 'package:slimsocial_for_facebook/screens/messenger_page.dart';
import 'package:slimsocial_for_facebook/screens/settings_page.dart';
import 'package:slimsocial_for_facebook/style/color_schemes.g.dart';
import 'package:slimsocial_for_facebook/utils/css.dart';
import 'package:slimsocial_for_facebook/utils/js.dart';
import 'package:slimsocial_for_facebook/utils/utils.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class HomePage extends ConsumerStatefulWidget {
  //String? initialUrl;

  const HomePage({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late WebViewController _controller;
  bool isLoading = false;
  bool isScontentUrl = false;

  @override
  void initState() {
    super.initState();

    _controller = _initWebViewController();
  }

  WebViewController _initWebViewController() {
    final homepage = PrefController.getHomePage();
    final controller = (WebViewController())
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(FacebookColors.darkBlue)
      ..setUserAgent(PrefController.getUserAgent())
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: onNavigationRequest,
          onPageStarted: (String url) async {
            setState(() {
              isScontentUrl = Uri.parse(url).host.contains("scontent");
            });

            //inject the css as soon as the DOM is loaded
            await injectCss();
          },
          onPageFinished: (String url) async {
            await runJs();
            if (kDebugMode) debugPrint(url);
          },
          onProgress: (int progress) {
            setState(() {
              isLoading = progress < 100;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(homepage));

    if (Platform.isAndroid) {
      (controller.platform as AndroidWebViewController)
        ..setCustomWidgetCallbacks(
          onShowCustomWidget:
              (Widget widget, OnHideCustomWidgetCallback callback) {
            // Handle the full screen videos
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => widget,
                fullscreenDialog: true,
              ),
            );
          },
          onHideCustomWidget: () {
            // Handle the full screen videos
            Navigator.of(context).pop();
          },
        )
        ..setOnShowFileSelector(
          (FileSelectorParams params) async {
            final photosPermission = sp.getBool("photos_permission") ?? false;

            if (photosPermission) {
              final result = await FilePicker.platform.pickFiles();

              if (result != null && result.files.single.path != null) {
                final file = File(result.files.single.path!);
                return [file.uri.toString()];
              }
            } else {
              // Handle the case when the permission is not granted
              showToast("check_permission".tr());
            }
            return [];
          },
        )
        ..setGeolocationPermissionsPromptCallbacks(
          onShowPrompt: (request) async {
            final gpsPermission = sp.getBool("gps_permission") ?? false;

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

  Future<NavigationDecision> onNavigationRequest(
    NavigationRequest request,
  ) async {
    final uri = Uri.parse(request.url);
    debugPrint("onNavigationRequest: ${request.url}");

    for (final other in kPermittedHostnamesFb) {
      if (uri.host.endsWith(other)) {
        return NavigationDecision.navigate;
      }
    }

    for (final other in kPermittedHostnamesMessenger) {
      if (uri.host.endsWith(other)) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => MessengerPage(initialUrl: uri.toString()),
          ),
        );
        return NavigationDecision.prevent;
      }
    }

    // open on webview
    print("Launching external url: ${request.url}");
    launchInAppUrl(context, request.url);
    return NavigationDecision.prevent;
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
        leading: IconButton(
          onPressed: () {
            //_controller?.loadUrl(PrefController.getHomePage());
            ref
                .read(fbWebViewProvider.notifier)
                .updateUrl(PrefController.getHomePage());
          },
          icon: const Icon(Icons.home),
        ),
        centerTitle: true,
        title: GestureDetector(
          child: const Text('SlimSocial'),
          onTap: () => _controller.scrollTo(0, 0),
        ),
        backgroundColor: CustomCss.darkThemeCss.isEnabled()
            ? FacebookColors.darkBlue
            : FacebookColors.official,
        elevation: 0,
        actions: [
          /*  IconButton(
            onPressed: () => _controller?.loadUrl(kMessengerUrl),
            icon: const Icon(Icons.messenger_outlined),
          ),*/
          if (isScontentUrl)
            IconButton(
              onPressed: () async {
                final url = await _controller.currentUrl();
                if (url != null) {
                  showToast("${"downloading".tr()}...");
                  final path = await downloadImage(url);
                  if (path != null) {
                    //showToast("Image saved to {}".tr(args: [path]));
                    OpenFile.open(path);
                  }
                }
              },
              icon: const Icon(Icons.save),
            ),
          if (isScontentUrl)
            IconButton(
              onPressed: () async {
                final url = await _controller.currentUrl();
                if (url != null) {
                  debugPrint("${"sharing".tr()}...");
                  final path = await downloadImage(url);
                  if (path != null) Share.shareXFiles([XFile(path)]);
                }
              },
              icon: const Icon(Icons.ios_share_outlined),
            ),
          if (sp.getBool("enable_messenger") ?? true)
            IconButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => const MessengerPage(),
                  ),
                );
              },
              icon: Image.asset('assets/icons/ic_messenger.png', height: 22),
            ),
          PopupMenuButton<String>(
            onSelected: (item) async {
              switch (item) {
                case "share_url":
                  final url = await _controller.currentUrl();
                  if (url != null) Share.share(url);
                  break;
                case "refresh":
                  _controller.reload();
                  break;
                case "settings":
                  Navigator.of(context).pushNamed("/settings");
                  break;
                case "top":
                  _controller.scrollTo(0, 0);
                  break;
                case "support":
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) =>
                          const SettingsPage(productId: "donation_1"),
                    ),
                  );
                  break;
                case "reset":
                  await _controller.clearCache();
                  await _controller.clearLocalStorage();
                  _controller = _initWebViewController();
                  break;
                default:
                  debugPrint("Unknown menu item: $item");
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: "top",
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.vertical_align_top),
                  title: Text("top".tr().capitalize()),
                ),
              ),
              PopupMenuItem<String>(
                value: "refresh",
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.refresh),
                  title: Text("refresh".tr().capitalize()),
                ),
              ),
              PopupMenuItem<String>(
                value: "share_url",
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.share),
                  title: Text("share_url".tr().capitalize()),
                ),
              ),
              PopupMenuItem<String>(
                value: "settings",
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.settings),
                  title: Text("settings".tr().capitalize()),
                ),
              ),
              PopupMenuItem<String>(
                value: "support",
                child: ListTile(
                  iconColor: Colors.red,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.favorite),
                  title: Text("support".tr().capitalize()),
                ),
              ),
              PopupMenuItem<String>(
                value: "reset",
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.restore),
                  title: Text("reset".tr().capitalize()),
                ),
              ),
            ],
          ),
        ],
      ),
      body: WillPopScope(
        onWillPop: () async {
          if (await _controller.canGoBack()) {
            _controller.goBack();

            if (isScontentUrl) {
              //gotta go back twice to leave scontent (facebook bug?)
              _controller.goBack();
            }
            return false;
          }
          return true;
        },
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
    );
  }

  Future<void> injectCss() async {
    var cssList = "";
    for (final css in CustomCss.cssList) {
      if (css.isEnabled()) cssList += css.code;
    }

    //create the function that will be called later
    await _controller.runJavaScript(CustomJs.removeAdsFunc);
    await _controller.runJavaScript(CustomJs.removeSuggestedFunc);

    //it's important to remove the \n
    final code = """
                    document.addEventListener("DOMContentLoaded", function() {
                        ${CustomJs.injectCssFunc(CustomCss.removeMessengerDownloadCss.code)}
                        ${CustomJs.injectCssFunc(CustomCss.removeBrowserNotSupportedCss.code)}
                        ${CustomJs.injectCssFunc(cssList)}
                         ${(sp.getBool('hide_ads') ?? true) ? "removeAds();" : ""}
                         ${(sp.getBool('hide_suggested') ?? true) ? "removeSuggested();" : ""}
                    });"""
        .replaceAll("\n", " ");
    await _controller.runJavaScript(code);
  }

  Future<void> runJs() async {
    if (sp.getBool('hide_ads') ?? true) {
      //setup the observer to run on page updates
      await _controller.runJavaScript(CustomJs.removeAdsObserver);
    }
    if (sp.getBool('hide_suggested') ?? true) {
      await _controller.runJavaScript(CustomJs.removeSuggestedObserver);
    }

    final userCustomJs = PrefController.getUserCustomJs();
    if (userCustomJs?.isNotEmpty ?? false) {
      await _controller.runJavaScript(userCustomJs!);
    }
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
