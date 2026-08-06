import 'dart:convert';

class CustomJs {
  /// Builds JavaScript that appends [css] to the document in a `<style>` tag.
  ///
  /// [id] makes the operation idempotent. Injection runs on every page start,
  /// and Facebook navigates in-page constantly, so without this each navigation
  /// would append another copy of the same rules.
  ///
  /// jsonEncode gives us a valid JS string literal: it escapes quotes,
  /// backslashes and newlines, so user-provided CSS cannot break out of the
  /// call and turn the whole injection into a syntax error.
  ///
  /// The stylesheet is assigned with `textContent`, not `innerHTML`: CSS is not
  /// markup, and the HTML entity parser mangles any `&` inside a selector.
  /// It goes into `<head>` because `<body>` does not reliably exist yet when
  /// this runs.
  static String injectCssFunc(String css, {required String id}) {
    return '''
      (function (css, id) {
        if (document.getElementById(id)) return;
        var node = document.createElement('style');
        node.id = id;
        node.textContent = css;
        (document.head || document.documentElement).appendChild(node);
      }) (${jsonEncode(css)}, ${jsonEncode(id)});
    ''';
  }

  /// Wraps [body] so it runs as soon as the document is parsed.
  ///
  /// Injection is triggered from `onPageStarted`, but there is no guarantee the
  /// document is still parsing by the time the script evaluates. A bare
  /// DOMContentLoaded listener registered after the event has already fired
  /// never runs, and the styling is silently lost.
  static String whenDomReady(String body) {
    return '''
      (function () {
        function slimRun() { $body }
        if (document.readyState === 'loading') {
          document.addEventListener('DOMContentLoaded', slimRun);
        } else {
          slimRun();
        }
      })();
    ''';
  }

  static String exampleJs = """
javascript:function foo() {
	     document.body.innerHTML = '';
		}
		foo();""";

  static String removeAdsObserver = """
// The observer is stored on `window` so it survives being re-injected on every
// page load: without a global we cannot tell whether one is already running.
// (The guard used to read `typeof newPostsObserver !== 'undefined'` against a
// block-scoped `const` declared inside the branch, so it was always false and
// the observer was never installed -- ads came back as soon as you scrolled.)
if (typeof window.newPostsObserver === 'undefined') {
    // Select the node that will be observed for changes
    const bodyNode = document.body;

    // Create a new observer object
    window.newPostsObserver = new MutationObserver(function (mutations) {
        mutations.forEach(function (mutation) {
            // Filter out added nodes that are not <section> elements
            const addedSections = Array.from(mutation.addedNodes).filter(node => node.nodeName === 'SECTION');

            // Check if any new <section> elements were added
            if (addedSections.length) {
                removeAds();
            }
        });
    });

    // Options for the observer (which mutations to observe)
    const config = { childList: true, subtree: true };

    // Start observing the target node for configured mutations
    window.newPostsObserver.observe(bodyNode, config);
}
  """;
}

String createFabFunc = """
javascript:function createFab() {
		var button = document.createElement('button');
		button.type = 'button';
  		button.innerHTML = '▲';
  		button.className = 'my_fab_btn';

  		button.onclick = function() {
    		window.scrollTo(0,0);
  		};

  		var container = document.getElementById('root');
  		container.appendChild(button);
		}
		createFab();""";
