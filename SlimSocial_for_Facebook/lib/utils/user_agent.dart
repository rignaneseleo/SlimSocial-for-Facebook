/// Control characters, plus the Unicode line and paragraph separators.
///
/// The Android webview's `setUserAgentString` throws `Invalid HTTP header
/// value` for a user agent with a line break in it, and the app applies the
/// custom user agent while it builds its first screen, so one bad value made
/// every start crash. A pasted user agent easily carries a trailing newline.
final _controlChars = RegExp(r'[\x00-\x1F\x7F-\x9F\u2028\u2029]+');

/// Spaces left side by side where control characters were removed.
final _spaceRuns = RegExp(' {2,}');

/// [raw] as a user agent the webview accepts, or null when nothing usable is
/// left.
///
/// Each run of control characters (line breaks, tabs, NUL, ...) becomes one
/// space, so `Mozilla/5.0\n(Linux)` stays two words. The result is trimmed.
/// Null tells the caller to use the default user agent.
String? sanitizeUserAgent(String? raw) {
  if (raw == null) return null;
  var value = raw;
  //only a value that had control characters is respaced, so an ordinary user
  //agent comes back exactly as it was typed
  if (_controlChars.hasMatch(value)) {
    value = value.replaceAll(_controlChars, ' ').replaceAll(_spaceRuns, ' ');
  }
  value = value.trim();
  return value.isEmpty ? null : value;
}
