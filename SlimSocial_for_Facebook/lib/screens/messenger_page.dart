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
import 'package:slimsocial_for_facebook/screens/settings_page.dart';
import 'package:slimsocial_for_facebook/style/color_schemes.g.dart';

import '../controllers/fb_controller.dart';
import '../utils/css.dart';
import '../utils/js.dart';
import '../main.dart';
import '../utils/utils.dart';

class MessengerPage extends ConsumerStatefulWidget {
  String? initialUrl;

  MessengerPage({this.initialUrl, Key? key}) : super(key: key);

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<MessengerPage> {
  WebViewController? _controller;
  bool isLoading = false;

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

    for (String other in kPermittedHostnamesMessenger)
      if (uri.host.endsWith(other)) {
        return NavigationDecision.navigate;
      }

    for (String other in kPermittedHostnamesFb)
      if (uri.host.endsWith(other)) {
        ref.read(fbWebViewProvider.notifier).updateUrl(request.url);
        Navigator.of(context).pop();
        //todo hide msg
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
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset('assets/icons/ic_messenger.png', height: 22),
            const SizedBox(width: 5),
            Text('Messenger'),
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
          if (_controller == null) return true;

          if (await _controller!.canGoBack()) {
            _controller!.goBack();
            return false;
          }
          return true;
        },
        child: Stack(
          alignment: AlignmentDirectional.bottomCenter,
          children: [
            WebView(
              initialUrl: widget.initialUrl ?? kMessengerUrl,
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
                //inject the css as soon as the DOM is loaded
                injectCss();
              },
              onPageFinished: (String url) {
                runJs();
                if (kDebugMode) print(url);
              },
              geolocationEnabled: sp.getBool("gps_permission") ?? false,
              allowsInlineMediaPlayback: true,
              userAgent: kFirefoxUserAgent,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              initialMediaPlaybackPolicy: AutoMediaPlaybackPolicy.always_allow,
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

  Future<void> runJs() async {
    var userCustomJs = await PrefController.getUserCustomJs();
    if (userCustomJs?.isNotEmpty ?? false)
      await _controller?.runJavascript(userCustomJs!);
  }

  Future injectCss() async {
    String cssList = "";

    if (await CustomCss.darkThemeCss.isEnabled())
      cssList += ((CustomCss.darkThemeMessengerCss.code));

    var userCustomCss = await PrefController.getUserCustomCss();
    if (userCustomCss?.isNotEmpty ?? false) cssList += ((userCustomCss!));

    var code = """
                    document.addEventListener("DOMContentLoaded", function() {
                        ${CustomJs.injectCssFunc(CustomCss.adaptMessengerPageCss.code)}
                        ${CustomJs.injectCssFunc(cssList)}
                    });"""
        .replaceAll("\n", " ");
    await _controller?.runJavascript(code);
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
