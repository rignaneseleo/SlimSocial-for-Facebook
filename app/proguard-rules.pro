# Keep our Settings data classes for DataStore round-trip
-keep class it.rignanese.leo.slim.domain.** { *; }
-keep class it.rignanese.leo.slim.data.** { *; }

# Keep WebView JS bridge methods (none yet, but planning ahead)
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Sentry rules are pulled in transitively from io.sentry:sentry-android.
# We add an extra to keep our scrubber code path:
-keep class it.rignanese.leo.slim.platform.SentryCrashReporter { *; }

# Compose
-dontwarn androidx.compose.**
