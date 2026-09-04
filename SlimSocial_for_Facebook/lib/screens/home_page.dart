import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:slimsocial_for_facebook/utils/ad_filter.dart';
import 'package:slimsocial_for_facebook/utils/css.dart';
import 'package:slimsocial_for_facebook/utils/dark_theme.dart';
import 'package:slimsocial_for_facebook/utils/fb_navigation.dart';
import 'package:slimsocial_for_facebook/utils/file_chooser.dart';
import 'package:slimsocial_for_facebook/utils/js.dart';
import 'package:slimsocial_for_facebook/utils/link_menu.dart';
import 'package:slimsocial_for_facebook/utils/load_retry_policy.dart';
import 'package:slimsocial_for_facebook/utils/rating_prompt.dart';
import 'package:slimsocial_for_facebook/utils/telemetry.dart';
import 'package:slimsocial_for_facebook/utils/url_cleaner.dart';
import 'package:slimsocial_for_facebook/utils/utils.dart';
import 'package:slimsocial_for_facebook/utils/webview_permissions.dart';
import 'package:slimsocial_for_facebook/widgets/rating_dialog.dart';
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
  AndroidWebViewController? _androidController;
  bool isLoading = false;
  bool isScontentUrl = false;

  /// Owns everything about a failed load: how many automatic retries are
  /// left, how long to wait before each, and whether the app should be showing
  /// its own error state instead of the browser's.
  late final LoadRetryPolicy _retryPolicy;

  /// Feed loads completed since this screen was built.
  ///
  /// Deliberately a field and not a preference: "this session" is the whole
  /// point of it, and a field dies with the screen for free.
  final SessionLoadCounter _loadsThisSession = SessionLoadCounter();

  /// Set while the rating prompt is being written down or shown.
  ///
  /// [_maybeAskForRating] is started with `unawaited`, so the callback that
  /// starts it can fire again while it is suspended on its first `await` — and
  /// at that point the ask has been counted but the launch it was asked on has
  /// not been recorded yet, so the second caller passes every gate and opens a
  /// second dialog on top of the first. That spends two of the three lifetime
  /// asks on one launch. A plain synchronous bool closes the window without
  /// depending on `shared_preferences` answering a write from its own cache.
  bool _askingForRating = false;

  /// Set while a Messenger route is on the stack.
  ///
  /// The chat icon raises a navigation request per tap, and a second tap
  /// landing while the route is being pushed would stack a second Messenger
  /// screen on the first.
  bool _messengerOpen = false;

  /// The feed's `history.length` as of the last url it actually moved to, and
  /// the url that reading was done on.
  ///
  /// Read here rather than when the chat icon is tapped, because the tap is a
  /// race this cannot win. Measured on a Pixel 10 Pro on 2026-09-03: Facebook
  /// pushed its "Get the Messenger app" page with `pushState` about 10ms
  /// *before* the `fb-messenger://` request arrived, so a count taken inside
  /// [_openMessenger] already included the pushed entry and the feed was left
  /// sitting on the interstitial. A second run had the two the other way round,
  /// which is what makes it a race rather than an order to code against.
  ///
  /// A `pushState` keeps the url it was called on, so it never updates these;
  /// a real navigation to a different url does.
  int? _feedHistoryLength;
  String? _feedHistoryUrl;

  @override
  void initState() {
    super.initState();

    _retryPolicy = LoadRetryPolicy(
      target: _WebViewLoadTarget(() => _controller),
      homeUrl: () => Uri.parse(PrefController.getHomePage()),
      onChanged: () {
        if (mounted) setState(() {});
      },
    );
    _controller = _initWebViewController();

    //the feed is still built and still what Back returns to: only the route on
    //top of it changes. Pushed after the first frame because [initState] has no
    //Navigator to push onto yet.
    if (PrefController.startsOnMessenger()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          _openMessenger(Uri.parse(kMessengerInboxUrl), source: 'startup'),
        );
      });
    }
  }

  WebViewController _initWebViewController() {
    final homepage = PrefController.getHomePage();
    final controller = WebViewController(
      onPermissionRequest: handleWebViewPermissionRequest,
    )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(FacebookColors.darkBlue)
      ..setUserAgent(PrefController.getUserAgent())
      //Facebook ships `maximum-scale=1, user-scalable=no` in its viewport, and
      //that meta tag is the only thing standing between the reader and pinch
      //zoom: the webview's own gesture is already on, because
      //webview_flutter_android's controller sets `builtInZoomControls` itself
      //(android_webview_controller.dart:91 in 4.3.4) and Android's
      //`setSupportZoom` defaults to true. Asked for explicitly all the same —
      //`webview_flutter_android` is pinned as `any` here, so that default is
      //not ours to rely on. CustomJs.unlockZoomFunc does the other half.
      ..enableZoom(true)
      ..addJavaScriptChannel(
        kAdCountChannelName,
        onMessageReceived: onAdCountMessage,
      )
      ..addJavaScriptChannel(
        kDiagnosticsChannelName,
        onMessageReceived: onDiagnosticsMessage,
      )
      ..addJavaScriptChannel(
        kLinkMenuChannelName,
        onMessageReceived: onLinkMenuMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: onNavigationRequest,
          onWebResourceError: onWebResourceError,
          onPageStarted: (String url) async {
            //the controller outlives this State: its callbacks keep firing for
            //a load already in flight after the widget is gone, and setState
            //then dereferences a null element and takes the app down with it.
            //Checked again after each await, because the widget can go away
            //while one is outstanding.
            if (!mounted) return;
            _retryPolicy.onNavigationStarted();
            _loadsThisSession.onNavigationStarted();
            setState(() {
              isScontentUrl = Uri.parse(url).host.contains("scontent");
            });

            //inject the css as soon as the DOM is loaded
            await injectCss();
            if (!mounted) return;

            //the install bar is decided by structure, in script, because the
            //stylesheet rule that did this took the share menu with it (#336)
            await runIsolatedJs(
              'app upsell',
              () => _controller.runJavaScript(
                CustomJs.whenDomReady(CustomJs.hideAppUpsellFunc()),
              ),
            );
            if (!mounted) return;

            //the webview offers no long-press callback, so the only way to
            //reach a link's address is a listener the page itself carries
            await runIsolatedJs(
              'link menu',
              () => _controller.runJavaScript(
                CustomJs.whenDomReady(
                  CustomJs.linkLongPressFunc(kLinkMenuChannelName),
                ),
              ),
            );
            if (!mounted) return;

            //before the dark theme, because unlocking the viewport reflows the
            //page and the theme script reads colours back out of it
            await runIsolatedJs(
              'zoom unlock',
              () => _controller
                  .runJavaScript(CustomJs.whenDomReady(CustomJs.unlockZoomFunc())),
            );
            if (!mounted) return;

            //the dark theme's text colours ship in that css, but the surfaces
            //they sit on are repainted by the script below. Running it only at
            //page finish leaves pale text on still-white cards for as long as
            //the rest of the page takes to arrive.
            await injectDarkTheme();
            if (!mounted) return;

            //re-read the zoom, so changing it in the settings takes effect on
            //the next load instead of needing the app restarted
            await _androidController?.setTextZoom(PrefController.getTextZoom());
          },
          onPageFinished: (String url) async {
            if (!mounted) return;
            //asked before anything is awaited: a navigation starting while
            //runJs is outstanding belongs to the next page, and it would clear
            //the very failure this finish is reporting
            final loadCompleted = _loadsThisSession.onNavigationFinished();
            _retryPolicy.onNavigationFinished();
            await runJs();
            if (!mounted) return;
            if (kDebugMode) debugPrint(url);

            await _rememberHistory(url);
            if (!mounted) return;

            //a failed main-frame load finishes like any other document on
            //Android, and asking for a rating over the error page is the
            //one-star review this gate exists to avoid
            if (loadCompleted) unawaited(_maybeAskForRating());
          },
          //Facebook's touch layout moves between pages in-document, and no
          //load finishes for those: without this the remembered count would
          //still describe whatever page the app last loaded outright
          onUrlChange: (change) {
            final url = change.url;
            if (url != null) unawaited(_rememberHistory(url));
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
      //debug builds only: lets `chrome://inspect` and the DevTools protocol
      //attach to the webview. That is the only way to read the markup Facebook
      //actually serves, which is what the injected selectors have to match.
      //Never enabled in release.
      if (kDebugMode) {
        AndroidWebViewController.enableDebugging(true);
      }

      final androidController = controller.platform as AndroidWebViewController;
      _androidController = androidController;

      androidController
        //videos and reels are muted until the page sees a "user gesture", and
        //the gesture the webview recognises is not the one that starts the
        //video: without this the first taps only toggle the sound off again
        ..setMediaPlaybackRequiresUserGesture(false)
        ..setTextZoom(PrefController.getTextZoom())
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
    _retryPolicy.dispose();
    super.dispose();
  }

  /// Records how many feed items the injected filter hid.
  ///
  /// The payload comes from the page, so it is parsed defensively and anything
  /// unexpected is dropped rather than trusted into the stored total.
  ///
  /// A rejected payload is described, never quoted. Any script on facebook.com
  /// can post here, `debugPrint` output is collected as a breadcrumb on
  /// whatever is reported next, and a log line that reproduces the payload
  /// turns the reject path into the page's own way off the device.
  void onAdCountMessage(JavaScriptMessage message) {
    final count = int.tryParse(message.message.trim());
    if (count == null || count <= 0) {
      debugPrint("ignored ad count: ${message.message.length} chars");
      return;
    }
    unawaited(PrefController.addAdsBlocked(count));
  }

  /// Forwards a health signal from the injected filter.
  ///
  /// This is how the app learns that Facebook changed its markup: nothing
  /// crashes when a selector goes stale, the filter simply stops matching.
  ///
  /// [parseDiagnostic] does the deciding, because everything arriving here is
  /// hostile input: any script on facebook.com can post on a channel the app
  /// registers. A rejected message is described, never quoted — `debugPrint`
  /// output is collected as a breadcrumb on whatever is reported next, so
  /// echoing the payload would hand the page a way off the device through the
  /// rejection path itself.
  void onDiagnosticsMessage(JavaScriptMessage message) {
    final diagnostic = parseDiagnostic(message.message);
    if (diagnostic == null) {
      debugPrint("ignored diagnostic: ${message.message.length} chars");
      return;
    }

    Telemetry.captureIssue(diagnostic.kind, data: diagnostic.data);
  }

  /// Offers to copy or open the link the reader long-pressed.
  ///
  /// [parseLinkMenuMessage] does the deciding, for the same reason as
  /// [onDiagnosticsMessage]: any script on facebook.com can post here, and
  /// what comes back out of this is a url the app copies or hands to a
  /// browser. A rejected message is described, never quoted.
  void onLinkMenuMessage(JavaScriptMessage message) {
    final link = parseLinkMenuMessage(message.message);
    if (link == null) {
      debugPrint("ignored link menu message: ${message.message.length} chars");
      return;
    }

    if (!mounted) return;
    unawaited(showLinkMenu(context, link));
  }

  /// Hands a failed page load to the retry policy.
  void onWebResourceError(WebResourceError error) {
    //a failure the platform will not classify is treated as the main frame's
    final isForMainFrame = error.isForMainFrame ?? true;

    //Facebook drops individual images and beacons all the time, so only a
    //main-frame failure is worth a line in the log
    if (isForMainFrame) {
      debugPrint(
        "load failed: ${error.errorType} ${error.errorCode} ${error.description}",
      );
    }

    _retryPolicy.onLoadError(url: error.url, isForMainFrame: isForMainFrame);
    //fires before the error page's own onPageFinished, which is what keeps
    //that finish from being counted as a load that worked
    _loadsThisSession.onLoadError(isForMainFrame: isForMainFrame);
  }

  Future<NavigationDecision> onNavigationRequest(
    NavigationRequest request,
  ) async {
    final uri = Uri.parse(request.url);
    //a full Facebook address names the person reading it, and debugPrint output
    //is collected as a breadcrumb on anything reported afterwards
    if (kDebugMode) debugPrint("onNavigationRequest: ${request.url}");

    //the chat icon in the mobile top bar is an `fb-messenger://` deep link, not
    //a link to /messages/, so it used to fall through to the Custom Tab — which
    //cannot open the scheme — and leave the feed on Facebook's "Get the
    //Messenger app" page (#338). See [messengerScreenTargetFor].
    final messengerTarget = messengerScreenTargetFor(uri);
    if (messengerTarget != null) {
      await _openMessenger(
        messengerTarget,
        source: uri.scheme == 'fb-messenger' ? 'jewel' : 'link',
      );
      return NavigationDecision.prevent;
    }

    //Facebook's mobile web opens its own video player through an `fb://` link
    //meant for the native app. Nothing below handles a scheme that is not http,
    //so these used to fall all the way through to the Custom Tab — which either
    //hands the reader to the official Facebook app or, if it is not installed,
    //does nothing at all. Either way the tap is lost. Sent back to the web
    //address for the same video instead.
    //
    //Skipped in basic mode: `/reel/` is a touch-layout address, mbasic does not
    //serve it, and navigating the one webview to a page that 404s would strand
    //the reader somewhere worse than where they started.
    if (uri.scheme == "fb" && !(sp.getBool(SpKeys.useMbasic) ?? false)) {
      final target = facebookAppLinkTarget(
        uri,
        host: Uri.parse(PrefController.getHomePage()).host,
      );
      if (target != null) {
        await _controller.loadRequest(target);
        return NavigationDecision.prevent;
      }
    }

    for (final other in kPermittedHostnamesFb) {
      if (uri.host.endsWith(other)) {
        return NavigationDecision.navigate;
      }
    }

    // open on webview
    //the address of a link the user tapped is their browsing, and debugPrint
    //output is collected as a breadcrumb on anything reported afterwards
    if (kDebugMode) debugPrint("Launching external url: ${request.url}");
    launchInAppUrl(context, request.url);
    return NavigationDecision.prevent;
  }

  /// Opens the Messenger screen on [target], and puts the feed back afterwards
  /// if the tap that got here pushed a page onto it.
  ///
  /// [source] names what asked — 'jewel', 'link', 'app_bar' or 'startup'. It
  /// is a fixed slug this app chose, and it is all that is reported: the
  /// address itself is the reader's browsing.
  ///
  /// Every hop is guarded, in the style of the callbacks above: this can be
  /// suspended for as long as the Messenger screen stays open, and the feed can
  /// be gone by the time it resumes.
  Future<void> _openMessenger(Uri target, {required String source}) async {
    if (_messengerOpen) return;

    //Facebook answers a tap on the chat icon by pushing its "Get the Messenger
    //app" page as an in-page history entry, without changing the document url,
    //and the feed has to be walked back off it afterwards. The count to compare
    //against is the one from before that push, and reading it here is too late:
    //measured on a Pixel 10 Pro on 2026-09-03 the push landed about 10ms
    //*before* the `fb-messenger://` request did, so a fresh read already
    //counted it and the feed stayed on the interstitial. [_rememberHistory]
    //holds the value from the last real url change instead; reading it now is
    //only the fallback for a feed that has not had one yet.
    final before = _feedHistoryLength ?? await _historyLength();
    if (!mounted) return;

    Telemetry.captureIssue('messenger.opened', data: {'source': source});

    _messengerOpen = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => MessengerPage(initialUrl: target.toString()),
        ),
      );
    } finally {
      _messengerOpen = false;
    }
    if (!mounted) return;

    final after = await _historyLength();
    if (!mounted) return;

    //the count could not be read, or nothing moved: leave the page alone. A
    //back step taken on a guess would throw away the post the reader was on.
    //
    //Any change counts, in either direction. `history.length` can also shrink
    //on a jewel tap: a reader who has gone back off a post sits at position 1
    //of 2, and Facebook's pushState truncates the forward entry before pushing
    //its own, so the length can hold or drop instead of rising. A shrink is
    //still proof that a page was pushed on top of the one that was remembered,
    //and stepping back off it is right.
    if (before == null || after == null || after == before) return;

    if (await _controller.canGoBack()) {
      if (!mounted) return;
      await _controller.goBack();
    }
  }

  /// Records the feed's history length for [url], at most once per url.
  ///
  /// Ignoring a url already seen is what makes this survive the race described
  /// on [_feedHistoryLength]: Facebook's interstitial is pushed under the url
  /// the feed is already on, so it never overwrites the count, and the stored
  /// number keeps describing the page as it was before the chat icon was
  /// tapped.
  Future<void> _rememberHistory(String url) async {
    if (url == _feedHistoryUrl) return;

    //claimed before the await, so a second callback for the same url cannot
    //race in and read the count twice
    _feedHistoryUrl = url;

    final length = await _historyLength();
    if (!mounted) return;

    _feedHistoryLength = length;
  }

  /// `history.length` for the page in the feed, or null when it cannot be read.
  ///
  /// Every failure is one answer, because the number is only ever used to ask
  /// whether an entry appeared: "unknown" has to mean "change nothing".
  Future<int?> _historyLength() async {
    try {
      final result =
          await _controller.runJavaScriptReturningResult('history.length');
      //Android hands numbers back as a String, iOS as a num
      if (result is num) return result.toInt();
      return int.tryParse(result.toString());
    }
    //deliberately everything: a page that will not run script must not stop
    //the Messenger screen from opening
    // ignore: avoid_catches_without_on_clauses
    catch (_) {
      return null;
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
          if (sp.getBool(SpKeys.enableMessenger) ?? true)
            IconButton(
              onPressed: () async {
                await _openMessenger(
                  Uri.parse(kMessengerInboxUrl),
                  source: 'app_bar',
                );
              },
              icon: Image.asset('assets/icons/ic_messenger.png', height: 22),
            ),
          PopupMenuButton<String>(
            onSelected: (item) async {
              switch (item) {
                case "share_url":
                  final url = await _controller.currentUrl();
                  //a Facebook address picked up off the feed carries `fbclid`,
                  //`mibextid` and friends, and those identify the person who
                  //did the sharing rather than the post being shared. Sending
                  //them on hands that to every recipient and to whatever app
                  //they paste it into.
                  if (url != null) Share.share(stripTrackingParams(url));
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
                case "exit":
                  await SystemNavigator.pop();
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
              PopupMenuItem<String>(
                value: "exit",
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.exit_to_app),
                  title: Text("exit".tr().capitalize()),
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
            //covers the webview so the browser's own error page, sitting on a
            //near-black background, is never what the user sees
            if (_retryPolicy.loadFailed)
              ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.wifi_off_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "error_page_offline".tr(),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _retryPolicy.retryNow,
                          icon: const Icon(Icons.refresh),
                          label: Text("retry".tr()),
                        ),
                      ],
                    ),
                  ),
                ),
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
    //reads the theme off this element's context, so it is only safe while the
    //widget is still in the tree
    if (!mounted) return;
    final accent = cssColorFromColor(Theme.of(context).colorScheme.primary);

    final sheets = <String, String>{
      'slim-messenger-download': CustomCss.removeMessengerDownloadCss.code,
      'slim-browser-notice': CustomCss.removeBrowserNotSupportedCss.code,
      'slim-app-upsell': CustomCss.hideAppUpsellCss.code,
      'slim-selectable': CustomCss.selectableContentCss.code,
      'slim-ad-placeholder': CustomCss.adPlaceholderCss.code,
      'slim-user-sheet':
          CustomCss.buildFacebookCss(PrefController.getUserCustomCss()),
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

  /// The dark theme's surface colours cannot be shipped as CSS: Facebook
  /// generates the class that carries each surface per page render, so the
  /// palette has to be read back out of the page. Called from both the
  /// DOM-ready and the page-finished path — the script is idempotent, and a
  /// second run only picks up the stylesheets that arrived in between.
  Future<void> injectDarkTheme() async {
    if (!CustomCss.darkThemeCss.isEnabled()) return;

    await runIsolatedJs(
      'dark theme',
      () => _controller.runJavaScript(CustomJs.whenDomReady(darkThemeScript())),
    );
  }

  /// Runs one injection step so that its failure cannot reach the others.
  ///
  /// iOS hands a page exception back through `runJavaScript`, so a single
  /// throwing step left unguarded aborts every step queued behind it: the ad
  /// observer never installs, and the user's own script never runs.
  ///
  /// Carrying on is right, but doing it in silence is not: a step that fails on
  /// every load is the app quietly not working, which is exactly what nothing
  /// else here can see.
  ///
  /// [reportDetail] is false for a step running code the user wrote: iOS quotes
  /// the failing source back in the exception, and their own script is not ours
  /// to collect.
  Future<void> runIsolatedJs(
    String step,
    Future<void> Function() inject, {
    bool reportDetail = true,
  }) async {
    try {
      await inject();
    } on Object catch (e, stack) {
      if (reportDetail) {
        debugPrint('$step injection failed: $e');
        Telemetry.captureError(e, stack, hint: 'injection step: $step');
      } else {
        debugPrint('$step injection failed');
        Telemetry.captureIssue(kDiagUserScriptThrew);
      }
    }
  }

  Future<void> runJs() async {
    final hideAds = sp.getBool(SpKeys.hideAds) ?? true;
    final hidePymk = sp.getBool(SpKeys.hidePeopleYouMayKnow) ?? false;

    // Runs after injectCss so the generated sheet lands last and wins the ties.
    await injectDarkTheme();

    // One DOM walk serves both: the filter is injected when either setting
    // wants it, and each half is switched on independently inside the script.
    if (hideAds || hidePymk) {
      // Two steps, not one: the filter script runs a first pass on the way in,
      // and a page exception thrown by that pass would take the observer down
      // with it — leaving the ads to come back on the first scroll. The observer
      // checks for the filter itself before installing, so it is safe alone.
      await runIsolatedJs(
        'ad filter',
        () => _controller.runJavaScript(
          adFilterScript(
            placeholderText: 'ad_removed'.tr(),
            extraLabels: hideAds ? ['sponsored_keyword_fb'.tr()] : const [],
            hideSponsored: hideAds,
            hidePeopleYouMayKnow: hidePymk,
          ),
        ),
      );
      await runIsolatedJs(
        'ad observer',
        () => _controller.runJavaScript(CustomJs.removeAdsObserver),
      );
    }

    final userCustomJs = PrefController.getUserCustomJs();
    if (userCustomJs != null) {
      await runIsolatedJs(
        'user script',
        () => _controller.runJavaScript(userCustomJs),
        reportDetail: false,
      );
    }
  }

  /// Shows the rating prompt if this is one of the launches it is due on.
  ///
  /// Every hop here is guarded: the controller outlives this State, so a load
  /// still in flight keeps calling back after the widget has gone.
  Future<void> _maybeAskForRating() async {
    if (!mounted) return;
    //one prompt at a time: the gates below are read from storage that the
    //first call has not finished writing yet
    if (_askingForRating) return;
    //asking over a feed that is still retrying is asking about a broken app
    if (_retryPolicy.loadFailed) return;

    final opens = sp.getInt(SpKeys.ratingOpens) ?? 0;
    final asks = sp.getInt(SpKeys.ratingAsks) ?? 0;

    if (!RatingPrompt.shouldAsk(
      opens: opens,
      asks: asks,
      answered: sp.getBool(SpKeys.ratingAnswered) ?? false,
      lastAskedOpen: sp.getInt(SpKeys.ratingLastAskedOpen) ?? 0,
      loadsThisSession: _loadsThisSession.completed,
    )) {
      return;
    }

    //set before the first await and cleared however this ends, including a
    //dialog that throws
    _askingForRating = true;
    try {
      //written before the dialog opens, so a crash or a force-quit mid-prompt
      //still costs this launch's single ask rather than looping on it
      await sp.setInt(SpKeys.ratingAsks, asks + 1);
      await sp.setInt(SpKeys.ratingLastAskedOpen, opens);
      if (!mounted) return;

      await showRatingDialog(
        context: context,
        onRated: (stars) => sp.setBool(SpKeys.ratingAnswered, true),
      );
    } finally {
      _askingForRating = false;
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

/// Lets [LoadRetryPolicy] drive the webview without knowing about it.
///
/// The controller is reached through a callback because the policy is built
/// first: it is what the controller's navigation callbacks report to.
class _WebViewLoadTarget implements LoadRetryTarget {
  const _WebViewLoadTarget(this._controller);

  final WebViewController Function() _controller;

  @override
  Future<String?> currentUrl() => _controller().currentUrl();

  @override
  Future<void> reload() => _controller().reload();

  @override
  Future<void> loadRequest(Uri uri) => _controller().loadRequest(uri);
}
