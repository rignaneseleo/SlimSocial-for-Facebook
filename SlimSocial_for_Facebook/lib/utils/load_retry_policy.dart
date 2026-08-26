import 'dart:async';

/// The webview, as far as the retry policy needs to know it.
///
/// Kept to the three calls the policy makes so the policy stays plain Dart:
/// the retry rules are the part worth testing, and a `WebViewController` can
/// only be built on a device.
abstract class LoadRetryTarget {
  /// The url of the committed navigation, or null when nothing has committed
  /// yet — a fresh webview that has never finished a load.
  Future<String?> currentUrl();

  Future<void> reload();

  Future<void> loadRequest(Uri uri);
}

/// Decides what to do when a page fails to load.
///
/// A failed main-frame load is retried automatically a few times before the
/// app gives up and shows its own error state. The common case is a transient
/// DNS failure when the app is opened as the device wakes and the network has
/// not settled — the load fails, and without a retry the user is left looking
/// at an error until they think to reload themselves.
class LoadRetryPolicy {
  LoadRetryPolicy({
    required this.target,
    required this.homeUrl,
    required this.onChanged,
  });

  final LoadRetryTarget target;

  /// Where to go when the failed url is unknown.
  final Uri Function() homeUrl;

  /// Called when [loadFailed] flips, so the ui can repaint. Retrying quietly
  /// in the background changes nothing on screen and does not call this.
  final void Function() onChanged;

  /// How many times to retry before showing the error screen.
  ///
  /// Measured on a real device: opening the app as the phone wakes produces
  /// `ERR_INTERNET_DISCONNECTED` first — no network attached at all — and only
  /// then `ERR_NAME_NOT_RESOLVED` once DNS is reachable but not yet answering.
  /// A single quick retry lands in the middle of that and still fails, so the
  /// delay grows with each attempt.
  static const int maxRetries = 3;

  /// Grows with each attempt: 2s, then 4s, then 6s — long enough in total to
  /// outlast a phone reattaching to the network, short enough not to feel
  /// stuck.
  static const Duration retryStep = Duration(seconds: 2);

  bool _loadFailed = false;
  bool _navigationFailed = false;
  int _retryCount = 0;
  Timer? _retryTimer;
  bool _disposed = false;

  /// Whether the app should show its own error state.
  ///
  /// Without this the user gets Chrome's "webpage not available" page on a
  /// near-black background, which reads as the app being broken rather than
  /// the network being briefly unavailable.
  bool get loadFailed => _loadFailed;

  /// Automatic retries used since the last successful load.
  int get retryCount => _retryCount;

  void onNavigationStarted() {
    _navigationFailed = false;
    //a new navigation started, so any previous failure is stale
    _setLoadFailed(false);
  }

  /// Handles a failed page load.
  ///
  /// Only main-frame failures matter: Facebook drops individual images and
  /// beacons all the time, and treating those as a page failure would replace
  /// a perfectly good feed with an error screen.
  void onLoadError({required String? url, required bool isForMainFrame}) {
    if (!isForMainFrame) return;

    _navigationFailed = true;

    if (_retryCount < maxRetries) {
      _retryCount++;
      _retryTimer?.cancel();
      _retryTimer = Timer(retryStep * _retryCount, () {
        unawaited(reissueLoad(url));
      });
      return;
    }

    _setLoadFailed(true);
  }

  void onNavigationFinished() {
    //a page that finished loading is not a failed one, even if a subresource
    //errored on the way. Android delivers `onPageFinished` for a failed
    //main-frame load too — the error page commits and finishes like any other
    //document — so a navigation that already reported an error is not a
    //success and must not clear the count, or the ceiling above could never
    //be reached.
    if (!_navigationFailed && (_loadFailed || _retryCount > 0)) {
      //reloading a healthy page throws the user back to the top of the feed,
      //so a retry the page has already made unnecessary is dropped
      _retryTimer?.cancel();
      _retryCount = 0;
      _setLoadFailed(false);
    }
    _navigationFailed = false;
  }

  /// Retries at the user's request, from the error screen.
  Future<void> retryNow() async {
    _retryTimer?.cancel();
    _retryCount = 0;
    _setLoadFailed(false);
    await target.loadRequest(homeUrl());
  }

  /// Asks the webview for the failed page again.
  ///
  /// A plain `reload()` is not enough after a failed *first* load: iOS has no
  /// committed navigation to reload at that point, so the call does nothing
  /// and fires no callbacks at all — the retry would silently never happen. A
  /// null current url is exactly that state.
  Future<void> reissueLoad(String? url) async {
    if (_disposed) return;
    if (await target.currentUrl() != null) {
      await target.reload();
      return;
    }
    await target.loadRequest(Uri.parse(url ?? homeUrl().toString()));
  }

  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
  }

  void _setLoadFailed(bool value) {
    if (_loadFailed == value) return;
    _loadFailed = value;
    onChanged();
  }
}
