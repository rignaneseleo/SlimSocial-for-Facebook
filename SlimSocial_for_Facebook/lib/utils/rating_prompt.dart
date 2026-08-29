/// Decides when to ask the user to rate the app.
///
/// Plain Dart on purpose. The schedule is the part worth testing and every
/// input is a number the caller already holds, so nothing here reads a
/// preference or touches a widget and the whole policy is covered by a table
/// of integers. Where the numbers are stored, and what is done with the
/// answer, is the caller's business.
abstract final class RatingPrompt {
  /// Cold starts on which the prompt may appear.
  ///
  /// Three points across the life of the install: once the app has been used
  /// enough to have an opinion, once it is a habit, and once it has survived
  /// a few of Facebook's redesigns.
  static const List<int> kAskOnOpens = <int>[1, 3, 10];

  /// Completed feed loads required before the very first ask.
  ///
  /// The concrete reading of "after a few interactions": enough navigation
  /// that the person has seen the app work rather than merely started it.
  static const int kFirstAskInteractions = 5;

  /// Completed feed loads required before any later ask.
  ///
  /// One is not a formality. `injection.no_posts_matched` fires in production
  /// and the oldest complaint in the tracker is a feed that never renders;
  /// prompting over a blank screen collects a one-star rating and nothing
  /// that was not already known.
  static const int kLaterAskInteractions = 1;

  /// How many times the prompt may ever appear.
  ///
  /// Deliberately independent of [kAskOnOpens]: lengthening that list should
  /// change *when* the app asks, never turn the prompt into a recurring nag.
  static const int kMaxAsks = 3;

  /// How many completed loads this session must have before asking on [opens].
  static int requiredLoads(int opens) => opens == kAskOnOpens.first
      ? kFirstAskInteractions
      : kLaterAskInteractions;

  /// Whether the prompt should be shown right now.
  static bool shouldAsk({
    required int opens,
    required int asks,
    required bool answered,
    required int lastAskedOpen,
    required int loadsThisSession,
  }) {
    //a star was already given: they told us, and asking again is nagging
    if (answered) return false;
    if (asks >= kMaxAsks) return false;
    if (!kAskOnOpens.contains(opens)) return false;
    //one ask per launch, however many times the feed reloads
    if (lastAskedOpen == opens) return false;

    return loadsThisSession >= requiredLoads(opens);
  }
}

/// Counts the feed loads that actually worked, for one run of the screen.
///
/// `onPageFinished` on its own cannot be that count. Android commits and
/// finishes an error page like any other document, so a main-frame failure
/// arrives as an ordinary finish — and since the retry policy only admits to a
/// failure once its retries are spent, every attempt in a retry sequence would
/// read as a completed load. A phone opened while it is still attaching to the
/// network is enough to reach [RatingPrompt.kLaterAskInteractions] that way,
/// and the prompt then opens on top of the error screen: exactly the one-star
/// outcome the engagement gate exists to prevent.
///
/// So the failure is remembered per navigation, which is all the webview's
/// callbacks can tell us: set when the main frame errors, cleared only when the
/// next navigation starts.
class SessionLoadCounter {
  int _completed = 0;
  bool _navigationFailed = false;

  /// Loads that finished with no main-frame error reported against them.
  int get completed => _completed;

  /// A new navigation began, so the last one's failure is no longer ours.
  void onNavigationStarted() => _navigationFailed = false;

  /// Only main-frame failures count: Facebook drops individual images and
  /// beacons on every page, and a feed that rendered is a feed that worked.
  void onLoadError({required bool isForMainFrame}) {
    if (!isForMainFrame) return;
    _navigationFailed = true;
  }

  /// Records a finished load, and reports whether it was a real one.
  ///
  /// The failure is deliberately not cleared here. A navigation can report
  /// finished more than once, and a second finish arriving after an error is
  /// still that same broken page — counting it would put the prompt back over
  /// the error screen by another route.
  bool onNavigationFinished() {
    if (_navigationFailed) return false;
    _completed++;
    return true;
  }
}
