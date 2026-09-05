import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slimsocial_for_facebook/consts.dart';
import 'package:slimsocial_for_facebook/main.dart';

/// Crash and health reporting.
///
/// The app's job is injecting css and js into a page Facebook rewrites without
/// notice. When a selector goes stale nothing throws — ads come back, or the
/// feed renders wrong — so the store's crash vitals stay green while the app is
/// broken for everyone. [captureIssue] exists for exactly that class of silent
/// breakage; crash reporting is the lesser half of this file.
///
/// Nothing here reaches the network unless a dsn was compiled in with
/// `--dart-define=SENTRY_DSN=...`. A build without one never initialises the
/// sdk, so it behaves exactly like the app did before this file existed.
abstract final class Telemetry {
  /// Baked in at build time. Empty in any build that did not pass the define,
  /// which is the switch that keeps a self-built apk free of reporting.
  static const String _dsn = String.fromEnvironment('SENTRY_DSN');

  static bool get _canReport => _dsn.isNotEmpty;

  /// Signals already sent this session — see [captureIssue].
  static final Set<String> _reportedKinds = <String>{};

  /// Whether the sdk is currently running. Off means no client at all, not a
  /// client that drops what it is handed: only an sdk that was never started
  /// (or was closed again) stops the native layer opening sockets on its own.
  static bool _sdkRunning = false;

  @visibleForTesting
  static bool get sdkRunning => _sdkRunning;

  /// True only while a feedback send the user explicitly asked for is in
  /// flight. Read by [scrubFeedbackEvent], which otherwise drops everything
  /// coming from someone who turned reporting off.
  static bool _feedbackConsented = false;

  @visibleForTesting
  //write-only on purpose: the flag exists to widen what leaves the device,
  //so exposing a reader would only invite code that branches on it
  // ignore: avoid_setters_without_getters
  static set feedbackConsented(bool value) => _feedbackConsented = value;

  /// Initialises reporting (if a DSN was compiled in and the user allows it)
  /// and runs the app inside a guarded zone so uncaught errors are captured.
  static Future<void> init(Future<void> Function() appRunner) async {
    if (!_canReport) {
      await appRunner();
      return;
    }

    //the stored choice is read here, before any sdk exists, because a client
    //that has been started already talks: the native layer sends a session
    //envelope on start whatever the dart side later decides to drop
    if (!await storedChoice()) {
      await appRunner();
      return;
    }

    await _start(appRunner: appRunner);
  }

  /// The persisted choice, read without the [sp] global.
  ///
  /// [init] runs before the guarded runner assigns `sp`, so the preference has
  /// to be fetched on its own. Unreadable preferences mean the choice is
  /// unknowable, and the wrong guess would start reporting for someone who
  /// opted out.
  @visibleForTesting
  static Future<bool> storedChoice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(SpKeys.telemetryEnabled) ?? true;
    }
    //deliberately everything: a preference read must not decide the app fails
    //to start, and any failure here has to fall back to not reporting
    // ignore: avoid_catches_without_on_clauses
    catch (_) {
      return false;
    }
  }

  static Future<void> _start({Future<void> Function()? appRunner}) async {
    await SentryFlutter.init(configure, appRunner: appRunner);
    _sdkRunning = true;
  }

  /// Every option that decides what can leave the device.
  @visibleForTesting
  static void configure(SentryFlutterOptions options) {
    options.dsn = _dsn;

    //the appeal of this app is being a thin private wrapper, so every
    //option below that could carry something about the person using it is
    //turned off rather than left at its default
    options.sendDefaultPii = false;

    //a webview host has no spans worth measuring; tracing would only add
    //a request per app start for numbers nobody reads
    options.tracesSampleRate = null;
    options.enableAutoPerformanceTracing = false;

    //sessions are a request per foreground/background transition that only
    //feeds a crash-free-users percentage nobody reads here, and the native
    //layer sends them without ever consulting the dart callbacks below
    options.enableAutoSessionTracking = false;

    //both of these capture what is on screen, which here is the feed
    options.attachScreenshot = false;
    //pinned rather than left at its default: the default is the sdk's to
    //change, and this one ships the text of every widget over the page
    // ignore: experimental_member_use
    options.attachViewHierarchy = false;

    //tap breadcrumbs carry the tapped widget's label
    options.enableUserInteractionBreadcrumbs = false;
    options.enableUserInteractionTracing = false;

    //DebugPrintIntegration turns every debugPrint into a breadcrumb outside
    //debug builds, and this app debugPrints the user's own custom css and js
    options.enablePrintBreadcrumbs = false;

    //breadcrumbs the native SDK writes itself never reach beforeBreadcrumb, so
    //they would ride out on a native crash without ever being scrubbed. The
    //http one is the dangerous half: the addresses this app talks to are
    //Facebook addresses, and those identify people.
    options.enableAutoNativeBreadcrumbs = false;
    options.recordHttpBreadcrumbs = false;

    //breadcrumbs are scrubbed as they are added, not as they are sent:
    //enableScopeSync mirrors each crumb into the native scope, and an event
    //raised natively is assembled and sent without ever running [scrubEvent]
    options.beforeBreadcrumb = (crumb, hint) => scrubCrumb(crumb);

    options.beforeSend = (event, hint) => scrubEvent(event);

    //feedback is the one event whose body a person types. It arrives as
    //contexts.feedback, and _rebuildScrubbed passes contexts straight
    //through, so without this the raw sentence would leave the device.
    //Sentry prefers this callback over beforeSend for type 'feedback'.
    options.beforeSendFeedback = (event, hint) => scrubFeedbackEvent(event);
  }

  /// Whether the user currently allows reporting.
  ///
  /// Defaults to on. A build with no dsn cannot send anything either way, so
  /// this only ever decides anything where reporting is actually possible.
  ///
  /// Preferences are loaded inside the guarded runner, so an error thrown
  /// before that finishes reaches here with `sp` still unassigned. The choice
  /// is unknowable at that point, and the wrong guess would send an event for
  /// someone who opted out, so those few startup errors go unreported.
  static bool get isEnabled {
    try {
      return sp.getBool(SpKeys.telemetryEnabled) ?? true;
    }
    //reading an unassigned `late` throws an Error, not an Exception
    // ignore: avoid_catching_errors
    on Error {
      return false;
    }
  }

  /// Persists the user's choice and applies it immediately.
  ///
  /// Takes effect without a restart in both directions: turning it off closes
  /// the client, so nothing is left running to send anything; turning it back
  /// on starts one for a session that began without it.
  ///
  /// The positional flag is fixed by the contract the settings screen and the
  /// injection code both call against.
  // ignore: avoid_positional_boolean_parameters
  static Future<void> setEnabled(bool value) async {
    await sp.setBool(SpKeys.telemetryEnabled, value);
    //turning it back on should behave like a fresh session, otherwise a user
    //who opts out and back in to reproduce a problem reports nothing
    resetSession();

    if (!_canReport) return;

    if (value) {
      if (!_sdkRunning) await _start();
      return;
    }

    await _closeClient();
  }

  /// Shuts the client down, and neither throws nor leaves one running.
  ///
  /// [Sentry.isEnabled] is consulted alongside [_sdkRunning] because [_start]
  /// only assigns that flag once `SentryFlutter.init` has returned: an init
  /// that brings the client up and then throws leaves the flag false with a
  /// live client behind it. Someone who has reporting off must end up with no
  /// client whatever happened on the way here, so the sdk's own view of
  /// itself gets a say too.
  static Future<void> _closeClient() async {
    if (!_sdkRunning && !Sentry.isEnabled) return;

    try {
      await Sentry.close();
    }
    //deliberately everything: a close that fails is nothing the caller can
    //act on, and letting it out would replace the dialog's own result with it
    // ignore: avoid_catches_without_on_clauses
    catch (_) {
      //left to the `finally` below: the flag has to be cleared either way
    } finally {
      //a failed close may well have left the native layer running, which is
      //why the guard above asks [Sentry.isEnabled] rather than this flag
      //alone — the next call through here tries again
      _sdkRunning = false;
    }
  }

  /// Records a breadcrumb from the app's own code.
  ///
  /// [message] must be a fixed literal this app chose, never page content or
  /// anything the user typed — `enablePrintBreadcrumbs` is off precisely so
  /// that nothing reaches Sentry by accident, and this is the one deliberate
  /// way back in.
  static void addBreadcrumb(String message) {
    if (!_canReport || !isEnabled) return;

    unawaited(
      Sentry.addBreadcrumb(
        Breadcrumb(message: scrubText(message), level: SentryLevel.info),
      ),
    );
  }

  /// Reports a caught error.
  static void captureError(Object error, StackTrace? stack, {String? hint}) {
    if (!_canReport || !isEnabled) return;

    unawaited(
      Sentry.captureException(
        error,
        stackTrace: stack,
        withScope: hint == null
            ? null
            : (scope) =>
                scope.setContexts(_contextKey, {'hint': scrubText(hint)}),
      ),
    );
  }

  /// Reports a named health signal, e.g. an injection that matched nothing.
  /// [kind] is a stable machine-readable slug like 'injection.no_posts_matched'.
  ///
  /// [sampleOneIn] above 1 sends the signal from only that fraction of the
  /// processes that raise it. It is for success signals, which are counted in
  /// the thousands and are only ever read as a denominator; a failure is
  /// always reported in full.
  static void captureIssue(
    String kind, {
    Map<String, Object?> data = const {},
    int sampleOneIn = 1,
  }) {
    if (!_canReport || !isEnabled) return;
    if (!allowSampled(kind, sampleOneIn)) return;

    unawaited(
      Sentry.captureMessage(
        kind,
        level: SentryLevel.warning,
        withScope: (scope) async {
          //group on the slug alone: the same broken selector has to land in
          //one issue across every user, not one issue per stack trace
          scope.fingerprint = <String>[kind];
          await scope.setContexts(_contextKey, issueContext(data, sampleOneIn));
        },
      ),
    );
  }

  /// What an issue carries in the app's own context block.
  ///
  /// The sampling rate travels with the event because a sampled count means
  /// nothing without it: the reader has to multiply by it to recover how many
  /// processes the events stand for.
  @visibleForTesting
  static Map<String, dynamic> issueContext(
    Map<String, Object?> data,
    int sampleOneIn,
  ) =>
      <String, dynamic>{...scrubData(data), 'sample_one_in': sampleOneIn};

  /// The random source sampling draws from, swapped out by tests.
  @visibleForTesting
  static Random random = Random();

  /// Claims this session's slot for [kind], then decides whether this process
  /// is one of the 1-in-[sampleOneIn] that report it.
  ///
  /// The slot is spent either way. Sampling is meant to reduce how many
  /// processes report, not to give a process that drew a miss another go at
  /// the same signal later on.
  @visibleForTesting
  static bool allowSampled(String kind, int sampleOneIn) {
    if (!allowIssue(kind)) return false;
    if (sampleOneIn <= 1) return true;

    return random.nextInt(sampleOneIn) == 0;
  }

  /// Whether a feedback box can do anything at all.
  ///
  /// False in a build compiled without a dsn, where there is nowhere for the
  /// text to go. The dialog asks this before offering a box, because a Send
  /// button that cannot send is worse than no box.
  static bool get canCollectFeedback => _canReport;

  /// Sends one report the user wrote, with the rating they gave.
  ///
  /// Returns whether it was handed to the sdk, so the caller can tell the
  /// user the truth either way.
  ///
  /// Unlike [captureIssue] this is not throttled: the throttle there exists
  /// because a stale selector fires on every scroll, which has no analogue in
  /// a person pressing a button. The prompt's own ceiling bounds this.
  static Future<bool> captureFeedback({
    required int stars,
    required String text,
  }) async {
    if (!_canReport) return false;

    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    //someone who turned reporting off still gets to send the message they
    //just typed — pressing send is the consent — but their stored choice is
    //not touched, and the client started for it does not outlive the send
    _feedbackConsented = true;
    try {
      if (!_sdkRunning) await _start();

      await Sentry.captureFeedback(
        SentryFeedback(message: trimmed),
        withScope: (scope) async {
          //a number in the app's own context block stays filterable in
          //sentry, where the same value inside the message would not
          await scope.setContexts(_contextKey, <String, dynamic>{
            'stars': stars,
          });
        },
      );
      return true;
    }
    //a failed send must not take the dialog down with it
    // ignore: avoid_catches_without_on_clauses
    catch (_) {
      return false;
    } finally {
      //cleared first, and before anything here that could fail: this flag is
      //the only thing letting an opted-out user's events past
      //[scrubFeedbackEvent], and the `catch` above belongs to the `try`, not
      //to this block. A close that threw with the clear still queued behind
      //it would leave the flag set for the rest of the process, and every
      //later event of theirs would go out
      _feedbackConsented = false;

      //keyed on the stored preference rather than on whether the client was
      //already running: an enabled user whose client had simply not started
      //yet must keep the one this call started
      if (!isEnabled) await _closeClient();
    }
  }

  /// Claims this session's single slot for [kind], returning false once it is
  /// taken.
  ///
  /// A selector that stopped matching fires again on every scroll, so an
  /// unthrottled signal is thousands of identical events per user per day —
  /// enough to bury the one occurrence anybody needed to see.
  @visibleForTesting
  static bool allowIssue(String kind) => _reportedKinds.add(kind);

  /// Forgets which signals were already reported.
  @visibleForTesting
  static void resetSession() => _reportedKinds.clear();

  /// Name of the context block the app's own data is attached under.
  static const String _contextKey = "slimsocial";

  /// Matches an http(s) url anywhere inside free text.
  ///
  /// Deliberately greedy to the next space: trailing punctuation swallowed
  /// with the url is harmless because the whole match is replaced by
  /// [scrubUrl]'s output, while a stricter pattern risks leaving the tail of
  /// an id behind.
  static final RegExp _urlPattern = RegExp(r'https?://\S+');

  /// Facebook user, post and thread ids are long digit runs.
  static final RegExp _idPattern = RegExp(r'\d{8,}');

  /// Which page a url points at, at the only resolution that is safe to send.
  ///
  /// Facebook puts user and post ids in both the path and the query, so the
  /// path itself can never leave the device — one of these three words is the
  /// most that can.
  @visibleForTesting
  static String pageKind(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host == "m.me" || host.endsWith("messenger.com")) return "messenger";

    final path = uri.path.toLowerCase();
    if (path.isEmpty || path == "/" || path.startsWith("/home")) return "feed";

    return "other";
  }

  /// Reduces a url to the host plus a [pageKind], dropping path and query.
  @visibleForTesting
  static String scrubUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return "<url>";

    return "${uri.host}/<${pageKind(uri)}>";
  }

  /// Strips urls and id-shaped numbers out of an arbitrary string.
  ///
  /// Error messages quote the url that failed, so scrubbing only the
  /// structured url fields would still ship a full profile link in the
  /// exception text.
  @visibleForTesting
  static String scrubText(String text) => text
      .replaceAllMapped(_urlPattern, (match) => scrubUrl(match[0]!))
      .replaceAll(_idPattern, "<id>");

  /// Runs [scrubText] over every string reachable from [data].
  @visibleForTesting
  static Map<String, dynamic> scrubData(Map<String, dynamic> data) =>
      data.map((key, value) => MapEntry(key, _scrubValue(value)));

  static dynamic _scrubValue(dynamic value) {
    if (value == null || value is bool || value is num) return value;
    if (value is String) return scrubText(value);
    if (value is Iterable) return value.map<dynamic>(_scrubValue).toList();
    if (value is Map) {
      return value.map<String, dynamic>(
        (dynamic key, dynamic v) => MapEntry("$key", _scrubValue(v)),
      );
    }
    //anything else is a caller's object: only its printed form can be sent,
    //and only once scrubbed
    return scrubText(value.toString());
  }

  /// Last gate before an event leaves the device.
  ///
  /// Fails closed: sentry keeps the *unscrubbed* event when a `beforeSend`
  /// callback throws, so anything unexpected in here has to become a dropped
  /// event rather than a raw one.
  @visibleForTesting
  static SentryEvent? scrubEvent(SentryEvent event) {
    try {
      //an opted-out user sends nothing at all, not even a scrubbed skeleton
      if (!isEnabled) return null;

      return _rebuildScrubbed(event);
    }
    //deliberately everything: see the doc comment
    // ignore: avoid_catches_without_on_clauses
    catch (_) {
      return null;
    }
  }

  /// Last gate before a user's written feedback leaves the device.
  ///
  /// Fails closed for the same reason [scrubEvent] does: sentry keeps the
  /// *unscrubbed* event when a callback throws.
  @visibleForTesting
  static SentryEvent? scrubFeedbackEvent(SentryEvent event) {
    try {
      //someone who opted out sends nothing, unless this is the message they
      //just typed and pressed send on
      if (!isEnabled && !_feedbackConsented) return null;

      return _rebuildScrubbed(
        event,
        contexts: _feedbackContexts(event.contexts),
      );
    }
    //deliberately everything: see the doc comment
    // ignore: avoid_catches_without_on_clauses
    catch (_) {
      return null;
    }
  }

  /// The context blocks a feedback event is allowed to carry, rebuilt from
  /// scratch for the same reason [_rebuildScrubbed] rebuilds the event.
  ///
  /// `contexts` reaches a `beforeSend` callback already filled in: sentry runs
  /// its event processors first, and `LoadContextsIntegration` and the flutter
  /// enricher are two of them. Passing it through untouched would send a
  /// device fingerprint under a notice that promises a message, so only the
  /// three blocks that notice names survive. `culture` is the one worth
  /// naming: locale and timezone identify a person and tell a bug report
  /// nothing.
  static Contexts _feedbackContexts(Contexts contexts) {
    final feedback = contexts.feedback;

    final allowed = Contexts(
      //"your device model"
      device: contexts.device,
      //"your Android version"
      operatingSystem: contexts.operatingSystem,
      //"your app version"
      app: contexts.app,
      feedback: feedback == null
          ? null
          : SentryFeedback(
              message: scrubText(feedback.message),
              //never collected by this app, and pinned to null so that a
              //future sdk default cannot start filling them in
              associatedEventId: feedback.associatedEventId,
            ),
    );

    //the app's own block, which on this path is the star rating the user just
    //picked — part of what they pressed send on, not something sentry added
    final own = contexts[_contextKey];
    if (own != null) allowed[_contextKey] = _scrubValue(own);

    return allowed;
  }

  /// Rebuilds [event] field by field instead of copying and patching it: a
  /// field this list does not name is dropped, so a future sdk version cannot
  /// start attaching something new that silently rides along. `user`,
  /// `serverName` and the unstructured `extra` bag are intentionally missing.
  static SentryEvent _rebuildScrubbed(SentryEvent event, {Contexts? contexts}) {
    final message = event.message;
    final request = event.request;

    return SentryEvent(
      eventId: event.eventId,
      timestamp: event.timestamp,
      platform: event.platform,
      logger: event.logger,
      release: event.release,
      dist: event.dist,
      environment: event.environment,
      modules: event.modules,
      sdk: event.sdk,
      level: event.level,
      type: event.type,
      contexts: contexts ?? event.contexts,
      debugMeta: event.debugMeta,
      threads: event.threads,
      fingerprint: event.fingerprint,
      //a route name, so safe as it stands
      transaction: event.transaction,
      throwable: event.throwableMechanism,
      culprit: event.culprit == null ? null : scrubText(event.culprit!),
      tags: event.tags?.map((key, value) => MapEntry(key, scrubText(value))),
      message: message == null
          ? null
          : SentryMessage(
              scrubText(message.formatted),
              template: message.template,
              params: message.params?.map<dynamic>(_scrubValue).toList(),
            ),
      exceptions: event.exceptions?.map(_scrubException).toList(),
      breadcrumbs: event.breadcrumbs?.map(_scrubBreadcrumb).toList(),
      request: request == null ? null : _scrubRequest(request),
    );
  }

  static SentryException _scrubException(SentryException exception) =>
      SentryException(
        type: exception.type,
        value: exception.value == null ? null : scrubText(exception.value!),
        module: exception.module,
        //frames point at this app's own dart files, not at anything browsed
        stackTrace: exception.stackTrace,
        mechanism: exception.mechanism,
        threadId: exception.threadId,
        throwable: exception.throwable,
      );

  /// Last gate before a breadcrumb is recorded.
  ///
  /// Runs at add time rather than at send time because `enableScopeSync`
  /// mirrors every crumb into the native scope, and a natively raised event
  /// is assembled and sent there without [scrubEvent] ever seeing it.
  ///
  /// Fails closed, and cannot throw: sentry keeps the *raw* crumb when a
  /// `beforeBreadcrumb` callback throws, so every path out of here has to be
  /// either a scrubbed crumb or none.
  @visibleForTesting
  static Breadcrumb? scrubCrumb(Breadcrumb? crumb) {
    try {
      if (crumb == null) return null;
      //an opted-out user records nothing the sdk could later attach
      if (!isEnabled) return null;

      return _scrubBreadcrumb(crumb);
    }
    //deliberately everything: see the doc comment
    // ignore: avoid_catches_without_on_clauses
    catch (_) {
      return null;
    }
  }

  static Breadcrumb _scrubBreadcrumb(Breadcrumb crumb) => Breadcrumb(
        message: crumb.message == null ? null : scrubText(crumb.message!),
        timestamp: crumb.timestamp,
        category: crumb.category,
        data: crumb.data == null ? null : scrubData(crumb.data!),
        level: crumb.level,
        type: crumb.type,
      );

  /// Keeps the host and method only: the query string, cookies, headers, body
  /// and environment of a Facebook request are all session identifiers.
  static SentryRequest _scrubRequest(SentryRequest request) => SentryRequest(
        url: request.url == null ? null : scrubUrl(request.url!),
        method: request.method,
      );
}
