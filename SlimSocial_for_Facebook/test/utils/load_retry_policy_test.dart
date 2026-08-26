import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slimsocial_for_facebook/utils/load_retry_policy.dart';

const String _kHome = "https://m.facebook.com/";
const String _kFailed = "https://m.facebook.com/home.php";

/// Stands in for the webview: records what the policy asked it to do and lets
/// a test pretend there is no committed navigation yet (`url` left null).
class _FakeTarget implements LoadRetryTarget {
  _FakeTarget({this.url});

  String? url;
  final List<String> calls = <String>[];

  @override
  Future<String?> currentUrl() async => url;

  @override
  Future<void> reload() async {
    calls.add("reload");
  }

  @override
  Future<void> loadRequest(Uri uri) async {
    calls.add("load:$uri");
  }
}

void main() {
  late _FakeTarget target;
  late LoadRetryPolicy policy;
  late int changes;

  LoadRetryPolicy build({String? currentUrl = _kHome}) {
    target = _FakeTarget(url: currentUrl);
    changes = 0;
    return policy = LoadRetryPolicy(
      target: target,
      homeUrl: () => Uri.parse(_kHome),
      onChanged: () => changes++,
    );
  }

  void fail(FakeAsync async, {bool isForMainFrame = true}) {
    policy.onLoadError(url: _kFailed, isForMainFrame: isForMainFrame);
    // let the reissue's awaited `currentUrl()` settle if a retry fired
    async.flushMicrotasks();
  }

  group('LoadRetryPolicy', () {
    test('the error page finishing does not clear the retry count', () {
      fakeAsync((async) {
        build();
        policy.onNavigationStarted();
        fail(async);
        expect(policy.retryCount, 1);

        // Android delivers onPageFinished for the error page itself
        policy.onNavigationFinished();

        expect(policy.retryCount, 1, reason: "error page is not a success");
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();
        expect(target.calls, <String>["reload"]);
      });
    });

    test('escalates the delay and gives up after the third retry', () {
      fakeAsync((async) {
        build();
        for (final expected in <int>[2, 4, 6]) {
          fail(async);
          async.elapse(Duration(seconds: expected - 1));
          async.flushMicrotasks();
          expect(
            target.calls.length,
            expected ~/ 2 - 1,
            reason: "must still be waiting ${expected}s in",
          );
          async.elapse(const Duration(seconds: 1));
          async.flushMicrotasks();
          expect(target.calls.length, expected ~/ 2);
        }

        expect(policy.loadFailed, isFalse);
        fail(async);
        expect(policy.loadFailed, isTrue, reason: "retries exhausted");
        async.elapse(const Duration(minutes: 1));
        async.flushMicrotasks();
        expect(target.calls.length, 3, reason: "no fourth retry");
      });
    });

    test('a real success resets the counter and cancels the pending retry', () {
      fakeAsync((async) {
        build();
        fail(async);
        expect(policy.retryCount, 1);

        policy.onNavigationStarted();
        policy.onNavigationFinished();

        expect(policy.retryCount, 0);
        expect(policy.loadFailed, isFalse);
        async.elapse(const Duration(minutes: 1));
        async.flushMicrotasks();
        expect(target.calls, isEmpty, reason: "superseded retry must not fire");
      });
    });

    test('loads the url again when there is no committed navigation', () {
      fakeAsync((async) {
        build(currentUrl: null);
        fail(async);
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();
        expect(target.calls, <String>["load:$_kFailed"]);
      });
    });

    test('falls back to the home page when the failed url is unknown', () {
      fakeAsync((async) {
        build(currentUrl: null);
        policy.onLoadError(url: null, isForMainFrame: true);
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();
        expect(target.calls, <String>["load:$_kHome"]);
      });
    });

    test('a manual retry clears the failure and cancels the pending retry', () {
      fakeAsync((async) {
        build();
        fail(async);
        unawaited(policy.retryNow());
        async.flushMicrotasks();

        expect(policy.retryCount, 0);
        expect(policy.loadFailed, isFalse);
        async.elapse(const Duration(minutes: 1));
        async.flushMicrotasks();
        expect(target.calls, <String>["load:$_kHome"]);
      });
    });

    test('dispose cancels the pending retry', () {
      fakeAsync((async) {
        build();
        fail(async);
        policy.dispose();
        async.elapse(const Duration(minutes: 1));
        async.flushMicrotasks();
        expect(target.calls, isEmpty);
      });
    });

    test('ignores failures that are not for the main frame', () {
      fakeAsync((async) {
        build();
        fail(async, isForMainFrame: false);

        expect(policy.retryCount, 0);
        expect(policy.loadFailed, isFalse);
        async.elapse(const Duration(minutes: 1));
        async.flushMicrotasks();
        expect(target.calls, isEmpty);
      });
    });

    test('notifies only when the visible failure state changes', () {
      fakeAsync((async) {
        build();
        fail(async);
        expect(changes, 0, reason: "a silent retry changes nothing on screen");

        fail(async);
        fail(async);
        fail(async);

        expect(policy.loadFailed, isTrue);
        expect(changes, 1, reason: "only the overlay appearing is visible");
      });
    });
  });
}
