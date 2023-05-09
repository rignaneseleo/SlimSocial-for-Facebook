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
import 'package:slimsocial_for_facebook/style/color_schemes.g.dart';

import '../controllers/fb_controller.dart';
import '../css.dart';
import '../js.dart';
import '../main.dart';
import '../utils.dart';

class HomePage extends ConsumerStatefulWidget {
  //String? initialUrl;

  HomePage({Key? key}) : super(key: key);

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  WebViewController? _controller;
  bool isLoading = false;
  late Timer adsRemoverTimer;
  bool isScontentUrl = false;

  @override
  void initState() {
    if (Platform.isAndroid) {
      WebView.platform = SurfaceAndroidWebView();
    }

    adsRemoverTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (sp.getBool('hide_ads') ?? false)
        _controller?.runJavascript(CustomJs.removeAds);
    });

    super.initState();
  }

  @override
  void dispose() {
    adsRemoverTimer.cancel();
    super.dispose();
  }

  Future<NavigationDecision> onNavigationRequest(
      NavigationRequest request) async {
    Uri uri = Uri.parse(request.url);

    for (String other in kPermittedHostnames)
      if (uri.host.endsWith(other)) {
        return NavigationDecision.navigate;
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
      webUriProvider,
      (previous, next) async {
        if (previous == next) {
          var y = await _controller?.getScrollY();
          var x = await _controller?.getScrollX();
          await _controller?.reload();

          //go back to the previous location
          if (y != null && x != null && y > 0 && x > 0) {
            await Future.delayed(const Duration(milliseconds: 1500));
            await _controller?.scrollTo(x, y);
          }
        } else
          _controller?.loadUrl(next.toString());
      },
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () =>
              ref.read(webUriProvider.notifier).update(kFacebookHomeUrl),
          icon: const Icon(Icons.home),
        ),
        centerTitle: true,
        title: GestureDetector(
          child: const Text('SlimSocial'),
          onTap: () => _controller?.scrollTo(0, 0),
        ),
        backgroundColor: CustomCss.darkThemeCss.isEnabled()
            ? FacebookColors.black
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
          if (!isScontentUrl)
            IconButton(
              onPressed: () async {
                var url = await _controller?.currentUrl();
                if (url != null) Share.share(url);
              },
              icon: const Icon(Icons.share),
            ),
          IconButton(
            onPressed: () async => Navigator.of(context).pushNamed("/settings"),
            icon: const Icon(Icons.settings),
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
              onPageStarted: (String url) {
                setState(() {
                  isScontentUrl = (Uri.parse(url).host.contains("scontent"));
                });
              },
              onPageFinished: (String url) {
                runCss();
                if (kDebugMode) print(url);
              },
              geolocationEnabled: sp.getBool("gps_permission") ?? false,
              allowsInlineMediaPlayback: true,
              userAgent: PrefController.getUserAgent(),
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              initialMediaPlaybackPolicy: AutoMediaPlaybackPolicy.always_allow,

              //gestures
              gestureNavigationEnabled: true,
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

  Future<void> runCss() async {
    //active by default
    await _controller?.runJavascript(
        CustomJs.editCss(CustomCss.removeMessengerDownloadCss.code));
    await _controller?.runJavascript(
        CustomJs.editCss(CustomCss.removeBrowserNotSupportedCss.code));

    //load CSS based on settings
    for (var css in CustomCss.cssList) {
      if (await css.isEnabled())
        await _controller?.runJavascript(CustomJs.editCss(css.code));
    }

    var userCustomCss = await PrefController.getUserCustomCss();
    if (userCustomCss?.isNotEmpty ?? false)
      await _controller?.runJavascript(CustomJs.editCss(userCustomCss!));

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
