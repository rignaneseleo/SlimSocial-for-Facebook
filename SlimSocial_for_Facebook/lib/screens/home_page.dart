import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webview_pro/webview_flutter.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:slimsocial_for_facebook/consts.dart';
import 'package:slimsocial_for_facebook/screens/messenger_page.dart';
import 'package:slimsocial_for_facebook/screens/settings_page.dart';
import 'package:slimsocial_for_facebook/style/color_schemes.g.dart';

import '../controllers/fb_controller.dart';
import '../utils/css.dart';
import '../utils/js.dart';
import '../main.dart';
import '../utils/utils.dart';

class HomePage extends ConsumerStatefulWidget {
  //String? initialUrl;

  HomePage({Key? key}) : super(key: key);

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  WebViewController? _controller;
  bool isLoading = false;
  bool isScontentUrl = false;

  @override
  void initState() {
    if (Platform.isAndroid) {
      WebView.platform = SurfaceAndroidWebView();
    }

    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<NavigationDecision> onNavigationRequest(
      NavigationRequest request) async {
    Uri uri = Uri.parse(request.url);
    print("onNavigationRequest: ${request.url}");

    for (String other in kPermittedHostnamesFb)
      if (uri.host.endsWith(other)) {
        return NavigationDecision.navigate;
      }

    for (String other in kPermittedHostnamesMessenger)
      if (uri.host.endsWith(other)) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MessengerPage(initialUrl: uri.path),
          ),
        );
        return NavigationDecision.prevent;
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
        var currentUrl = await _controller?.currentUrl();
        if (currentUrl != null) {
          var currentUri = Uri.parse(currentUrl);
          if (currentUri.toString() == next.toString()) {
            print("refreshing keeping the y index...");
            //if I'm refreshing the page, I need to save the current scroll position
            var y = await _controller?.getScrollY();
            var x = await _controller?.getScrollX();

            //refresh
            await _controller?.reload();

            //go back to the previous location
            if (y != null && x != null && (y > 0 || x > 0)) {
              await Future.delayed(const Duration(milliseconds: 1500));
              print("restoring  $x, $y");
              await _controller?.scrollTo(x, y);
            }
            return;
          }
        }

        _controller?.loadUrl(next.toString());
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
          onTap: () => _controller?.scrollTo(0, 0),
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
                var url = await _controller?.currentUrl();
                if (url != null) {
                  showToast("downloading".tr() + "...");
                  var path = await downloadImage(url);
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
                var url = await _controller?.currentUrl();
                if (url != null) {
                  print("sharing".tr() + "...");
                  var path = await downloadImage(url);
                  if (path != null) Share.shareXFiles([XFile(path)]);
                }
              },
              icon: const Icon(Icons.ios_share_outlined),
            ),
          if (sp.getBool("enable_messenger") ?? true)
            IconButton(
              onPressed: () async {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => MessengerPage(),
                  ),
                );
              },
              icon: Image.asset('assets/icons/ic_messenger.png', height: 22),
            ),
          PopupMenuButton<String>(
            onSelected: (item) async {
              switch (item) {
                case "share_url":
                  var url = await _controller?.currentUrl();
                  if (url != null) Share.share(url);
                  break;
                case "refresh":
                  _controller?.reload();
                  break;
                case "settings":
                  Navigator.of(context).pushNamed("/settings");
                  break;
                case "top":
                  _controller?.scrollTo(0, 0);
                  break;
                case "support":
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            SettingsPage(productId: "donation_1")),
                  );
                  break;
                default:
                  print("Unknown menu item: $item");
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                  value: "top",
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.vertical_align_top),
                    title: Text("top".tr().capitalize()),
                  )),
              PopupMenuItem<String>(
                  value: "refresh",
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.refresh),
                    title: Text("refresh".tr().capitalize()),
                  )),
              PopupMenuItem<String>(
                  value: "share_url",
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.share),
                    title: Text("share_url".tr().capitalize()),
                  )),
              PopupMenuItem<String>(
                  value: "settings",
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.settings),
                    title: Text("settings".tr().capitalize()),
                  )),
              PopupMenuItem<String>(
                  value: "support",
                  child: ListTile(
                    iconColor: Colors.red,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.favorite),
                    title: Text("support".tr().capitalize()),
                  )),
            ],
          ),
        ],
      ),
      body: WillPopScope(
        onWillPop: () async {
          if (_controller == null) return true;

          if (await _controller!.canGoBack()) {
            _controller!.goBack();

            if (isScontentUrl) {
              //gotta go back twice to leave scontent (facebook bug?)
              _controller!.goBack();
            }
            return false;
          }
          return true;
        },
        child: Stack(
          alignment: AlignmentDirectional.bottomCenter,
          children: [
            WebView(
              initialUrl: PrefController.getHomePage(),
              javascriptMode: JavascriptMode.unrestricted,
              onWebViewCreated: (WebViewController webViewController) =>
                  _controller = (webViewController),
              onProgress: (int progress) {
                setState(() {
                  isLoading = progress < 100;
                });
              },

              /* javascriptChannels: <JavascriptChannel>{
                  _setupJavascriptChannel(context),
                },*/
              navigationDelegate: onNavigationRequest,
              debuggingEnabled: kDebugMode,
              onPageStarted: (String url) async {
                setState(() {
                  isScontentUrl = (Uri.parse(url).host.contains("scontent"));
                });

                //inject the css as soon as the DOM is loaded
                injectCss();
              },
              onPageFinished: (String url) async {
                runJs();
                if (kDebugMode) print(url);
              },
              geolocationEnabled: sp.getBool("gps_permission") ?? false,
              allowsInlineMediaPlayback: true,
              userAgent: PrefController.getUserAgent(),
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              initialMediaPlaybackPolicy: AutoMediaPlaybackPolicy.always_allow,

              //gestures
              gestureNavigationEnabled: false,
            ),
            if (isLoading)
              LinearProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(FacebookColors.official),
                backgroundColor: Colors.transparent,
              ),
          ],
        ),
      ),
    );
  }

  Future injectCss() async {
    String cssList = "";
    for (var css in CustomCss.cssList) {
      if (await css.isEnabled()) cssList += (css.code);
    }

    //create the function that will be called later
    _controller?.runJavascript(CustomJs.removeAdsFunc);

    //it's important to remove the \n
    var code = """
                    document.addEventListener("DOMContentLoaded", function() {
                        ${CustomJs.injectCssFunc(CustomCss.removeMessengerDownloadCss.code)}
                        ${CustomJs.injectCssFunc(CustomCss.removeBrowserNotSupportedCss.code)}
                        ${CustomJs.injectCssFunc(cssList)}
                         ${(sp.getBool('hide_ads') ?? true) ? "removeAds();" : ""}
                    });"""
        .replaceAll("\n", " ");
    await _controller?.runJavascript(code);
  }

  Future<void> runJs() async {
    if (sp.getBool('hide_ads') ?? true) {
      //setup the observer to run on page updates
      _controller?.runJavascript(CustomJs.removeAdsObserver);
    }

    var userCustomJs = await PrefController.getUserCustomJs();
    if (userCustomJs?.isNotEmpty ?? false)
      await _controller?.runJavascript(userCustomJs!);
  }

/*  JavascriptChannel _setupJavascriptChannel(BuildContext context) {
    return JavascriptChannel(
      name: 'Toaster',
      onMessageReceived: (JavascriptMessage message) {
        // ignore: deprecated_member_use
        print('Message received: ${message.message}');
      },
    );
  }*/
}
