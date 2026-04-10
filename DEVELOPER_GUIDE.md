# SlimSocial for Facebook - Developer Guide

## Table of Contents
1. [Quick Start](#quick-start)
2. [Project Architecture](#project-architecture)
3. [State Management with Riverpod](#state-management-with-riverpod)
4. [Adding New Features](#adding-new-features)
5. [CSS & JavaScript Injection](#css--javascript-injection)
6. [Testing](#testing)
7. [Building & Deployment](#building--deployment)
8. [Troubleshooting](#troubleshooting)

## Quick Start

### Prerequisites
- Flutter 3.38.5+ (managed with FVM)
- Dart 3.10+
- Xcode 15+ (for iOS)
- Android Studio / Android SDK 34+ (for Android)

### Setup

```bash
# Clone the repository
cd SlimSocial_for_Facebook

# Set Flutter version with FVM
fvm use 3.38.5

# Install dependencies
fvm flutter pub get

# Generate code for Riverpod
fvm dart run build_runner build --delete-conflicting-outputs

# Run the app
fvm flutter run
```

### Development Commands

```bash
# Run with hot reload
fvm flutter run

# Run on specific device
fvm flutter devices
fvm flutter run -d <device-id>

# Analyze code
fvm flutter analyze

# Run custom lint (Riverpod lint)
fvm dart run custom_lint

# Generate code (after modifying providers)
fvm dart run build_runner build --delete-conflicting-outputs

# Watch mode for continuous code generation
fvm dart run build_runner watch --delete-conflicting-outputs

# Build APK
fvm flutter build apk

# Build App Bundle for Play Store
fvm flutter build appbundle

# Generate app icons
fvm dart run flutter_launcher_icons
```

## Project Architecture

### Overview
SlimSocial is a WebView wrapper for Facebook with custom CSS/JS injection capabilities:

```
lib/
├── main.dart                 # App entry point, theme setup
├── providers/
│   └── webview_providers.dart   # Riverpod providers (annotation-based)
├── screens/
│   ├── home_page.dart           # Main Facebook WebView
│   ├── messenger_page.dart      # Messenger WebView
│   └── settings_page.dart       # App settings
├── controllers/
│   └── fb_controller.dart       # Preference logic
├── utils/
│   ├── css.dart                 # CSS injection definitions
│   ├── js.dart                  # JavaScript injection functions
│   └── utils.dart               # Utility functions
├── style/
│   └── color_schemes.g.dart     # Material 3 color schemes
└── consts.dart                  # App constants
```

### Key Technologies
- **Flutter 3.38.5** with Material 3
- **Riverpod 2.6+** (annotation-based) for state management
- **webview_flutter 4.10+** for displaying Facebook
- **easy_localization** for multi-language support (40+ languages)
- **shared_preferences** for local storage
- **app_links** for deep linking

## State Management with Riverpod

### Annotation-Based Providers

This project uses Riverpod with annotations for type-safe, code-generated providers.

**Example: Creating a new provider**

```dart
// lib/providers/my_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'my_provider.g.dart';

/// Provider that manages some state
@riverpod
class MyState extends _$MyState {
  @override
  String build() => 'initial value';

  void updateValue(String newValue) => state = newValue;
}
```

After creating/modifying providers, run:
```bash
fvm dart run build_runner build --delete-conflicting-outputs
```

**Using providers in widgets:**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:your_app/providers/my_provider.dart';

class MyWidget extends ConsumerWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read the value
    final value = ref.watch(myStateProvider);

    // Update the value
    return ElevatedButton(
      onPressed: () {
        ref.read(myStateProvider.notifier).updateValue('new value');
      },
      child: Text(value),
    );
  }
}
```

### Existing Providers

#### `fbWebViewProvider` (lib/providers/webview_providers.dart:8)
Manages the Facebook WebView URL state.

```dart
// Navigate to a specific Facebook URL
ref.read(fbWebViewProvider.notifier).updateUrl('https://facebook.com/profile');

// Listen to URL changes
ref.listen<Uri>(fbWebViewProvider, (previous, next) {
  // Handle URL change
});
```

#### `messengerWebViewProvider` (lib/providers/webview_providers.dart:15)
Manages the Messenger WebView URL state.

## Adding New Features

### 1. Add a New CSS Customization

**Step 1:** Define the CSS in `lib/utils/css.dart`:

```dart
static MyCss myNewFeatureCss = MyCss(
  key: 'my_new_feature',
  description: 'Description shown in settings',
  code: '''
    .facebook-selector {
      display: none !important;
    }
  ''',
  defaultEnabled: false, // Set to true to enable by default
);
```

**Step 2:** Add it to the `cssList`:

```dart
static List<MyCss> cssList = [
  centerTextPostsCss,
  addSpaceBetweenPostsCss,
  hideStoriesCss,
  fixedBarCss,
  darkThemeCss,
  hideMessengerSidebar,
  myNewFeatureCss, // Add your new CSS here
];
```

**Step 3:** Add a toggle in `lib/screens/settings_page.dart` (around line 205):

```dart
SettingsTile.switchTile(
  onToggle: (value) {
    setState(() {
      sp.setBool(CustomCss.myNewFeatureCss.key, value);
    });
    ref.invalidate(fbWebViewProvider);
  },
  initialValue: CustomCss.myNewFeatureCss.isEnabled(),
  title: Text(CustomCss.myNewFeatureCss.key.tr()),
  leading: const Icon(Icons.star),
),
```

**Step 4:** Add translation keys to `assets/lang/*.json`:

```json
{
  "my_new_feature": "My New Feature"
}
```

### 2. Add Custom JavaScript Function

**Step 1:** Define JavaScript in `lib/utils/js.dart`:

```dart
static String myCustomFunction = """
  javascript: function myFunc() {
    // Your JavaScript code here
    console.log('Custom function executed');
  }
  myFunc();
""";
```

**Step 2:** Inject it in `lib/screens/home_page.dart`:

```dart
Future<void> runJs() async {
  if (sp.getBool('hide_ads') ?? true) {
    await _controller.runJavaScript(CustomJs.removeAdsObserver);
  }

  // Add your custom JS here
  if (sp.getBool('my_custom_feature') ?? false) {
    await _controller.runJavaScript(CustomJs.myCustomFunction);
  }

  final userCustomJs = PrefController.getUserCustomJs();
  if (userCustomJs?.isNotEmpty ?? false) {
    await _controller.runJavaScript(userCustomJs!);
  }
}
```

### 3. Add a New Setting

**Step 1:** Add a SettingsTile in `lib/screens/settings_page.dart`:

```dart
SettingsTile.switchTile(
  onToggle: (value) {
    setState(() {
      sp.setBool('my_setting_key', value);
    });
    // Optionally refresh WebView
    ref.invalidate(fbWebViewProvider);
  },
  initialValue: sp.getBool('my_setting_key') ?? false,
  leading: const Icon(Icons.settings),
  title: Text('my_setting_title'.tr()),
  description: Text('my_setting_description'.tr()),
),
```

**Step 2:** Access the setting value:

```dart
final isEnabled = sp.getBool('my_setting_key') ?? false;
```

### 4. Add a New Provider

**Step 1:** Create provider file `lib/providers/my_feature_provider.dart`:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'my_feature_provider.g.dart';

@riverpod
class MyFeature extends _$MyFeature {
  @override
  bool build() => false; // Initial state

  void toggle() => state = !state;
  void enable() => state = true;
  void disable() => state = false;
}
```

**Step 2:** Generate code:

```bash
fvm dart run build_runner build --delete-conflicting-outputs
```

**Step 3:** Use in widgets:

```dart
import 'package:slimsocial_for_facebook/providers/my_feature_provider.dart';

// In your widget
final isEnabled = ref.watch(myFeatureProvider);
ref.read(myFeatureProvider.notifier).toggle();
```

## CSS & JavaScript Injection

### How It Works

1. **Page Load:** WebView loads Facebook URL
2. **DOM Ready:** `injectCss()` is called on `onPageStarted` (lib/screens/home_page.dart:60)
3. **Page Finished:** `runJs()` is called on `onPageFinished` (lib/screens/home_page.dart:63)

### CSS Injection Flow

```dart
Future<void> injectCss() async {
  var cssList = "";

  // Collect all enabled CSS
  for (final css in CustomCss.cssList) {
    if (css.isEnabled()) cssList += css.code;
  }

  // Inject via JavaScript
  await _controller.runJavaScript(CustomJs.injectCssFunc(cssList));
}
```

### JavaScript Injection Flow

```dart
Future<void> runJs() async {
  // Remove ads (if enabled)
  if (sp.getBool('hide_ads') ?? true) {
    await _controller.runJavaScript(CustomJs.removeAdsObserver);
  }

  // User custom JavaScript
  final userCustomJs = PrefController.getUserCustomJs();
  if (userCustomJs?.isNotEmpty ?? false) {
    await _controller.runJavaScript(userCustomJs!);
  }
}
```

### Ad Removal System

The ad removal system works in two stages:

1. **Initial Removal** (`removeAdsFunc`): Scans the page for "Sponsored" text in 40+ languages
2. **Continuous Removal** (`removeAdsObserver`): Uses MutationObserver to detect and remove ads as they're dynamically loaded

### Testing CSS/JS Changes

1. Enable **Developer Mode** on your device
2. Go to **Settings → Advanced → Send to Dev** (only visible in dev mode)
3. Test custom CSS/JS directly in the app
4. Share working code with developers

### Finding Facebook Selectors

1. Open https://facebook.com in Chrome desktop
2. Right-click → Inspect Element
3. Find the element's classes/IDs
4. Test CSS in Chrome DevTools
5. Add to `lib/utils/css.dart`

**Example:**

```css
/* Hide Facebook Stories */
#MStoriesTray {
  display: none !important;
}
```

## Testing

### Manual Testing Checklist

- [ ] App launches successfully
- [ ] Facebook loads and displays correctly
- [ ] Login works
- [ ] Dark theme toggles properly
- [ ] Custom CSS features work (hide ads, stories, etc.)
- [ ] Messenger opens in separate page
- [ ] External links open in custom tabs
- [ ] Deep links work
- [ ] Settings persist after app restart
- [ ] Permissions (GPS, Camera, Photos) work
- [ ] File upload works
- [ ] Video playback works (including fullscreen)
- [ ] Back navigation works correctly

### Testing on Different Facebook Versions

The app supports multiple Facebook interfaces:

1. **Touch Facebook** (default): `touch.facebook.com`
2. **mBasic**: `mbasic.facebook.com` (lite version)

Toggle in Settings → "Use mBasic Version"

### Testing Localization

```dart
// Test translation keys
print('test_key'.tr());

// Test with arguments
print('welcome_user'.tr(args: ['John']));
```

## Building & Deployment

### Android

```bash
# Debug APK
fvm flutter build apk --debug

# Release APK
fvm flutter build apk --release

# App Bundle (for Play Store)
fvm flutter build appbundle --release

# Split APKs by ABI
fvm flutter build apk --split-per-abi --release
```

### iOS

```bash
# Build for iOS
fvm flutter build ios --release

# Open in Xcode for signing
open ios/Runner.xcworkspace
```

### Versioning

Update version in `pubspec.yaml`:

```yaml
version: 26.01.23+200
#       ^^^^^^^^ ^^^
#       |        |
#       |        +-- Build number (increment for each release)
#       +----------- Version name (YY.MM.DD format)
```

### Pre-Release Checklist

- [ ] Update version in `pubspec.yaml`
- [ ] Run `fvm flutter analyze` (no errors)
- [ ] Run `fvm dart run custom_lint` (no critical issues)
- [ ] Test on Android (min SDK 21)
- [ ] Test on iOS (min iOS 12)
- [ ] Update CHANGELOG.md
- [ ] Test all languages
- [ ] Test dark/light themes
- [ ] Verify all custom CSS features work

## Troubleshooting

### Common Issues

#### Build Runner Fails

```bash
# Clean and regenerate
fvm flutter clean
fvm flutter pub get
fvm dart run build_runner clean
fvm dart run build_runner build --delete-conflicting-outputs
```

#### WebView Not Loading

1. Check internet connection
2. Check user agent in `lib/consts.dart`
3. Clear app cache via Settings → Reset
4. Check Facebook domain permits in `kPermittedHostnamesFb`

#### CSS Not Working

1. Check if CSS is enabled in settings
2. Verify CSS code has no syntax errors
3. Use `!important` for high specificity
4. Facebook might have changed their HTML structure
5. Test in Chrome DevTools first

#### Riverpod Provider Not Found

```bash
# Regenerate providers
fvm dart run build_runner build --delete-conflicting-outputs

# If still failing, clean first
fvm dart run build_runner clean
fvm dart run build_runner build --delete-conflicting-outputs
```

#### App Crashes on Launch

1. Check logs: `fvm flutter logs`
2. Verify all dependencies are compatible
3. Check for breaking changes in updated packages
4. Ensure SharedPreferences is initialized

### Facebook Changes Breaking the App

Facebook frequently updates their UI, which can break CSS selectors:

1. **Inspect New Structure**: Use Chrome DevTools on desktop Facebook
2. **Update Selectors**: Modify CSS in `lib/utils/css.dart`
3. **Test Thoroughly**: Check all CSS features
4. **Update Ad Keywords**: If ad blocking fails, update `removeAdsFunc` in `lib/utils/js.dart`

### Debugging Tips

```dart
// Enable verbose logging
debugPrint('Message: $variable');

// Log WebView navigation
onNavigationRequest: (request) {
  debugPrint('Navigation: ${request.url}');
  return NavigationDecision.navigate;
},

// Inspect SharedPreferences
final allPrefs = sp.getKeys();
for (final key in allPrefs) {
  debugPrint('$key: ${sp.get(key)}');
}
```

## Contributing Guidelines

### Code Style

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart)
- Use `const` constructors where possible
- Prefer `final` over `var`
- Use trailing commas for better diffs
- Run `fvm flutter analyze` before committing
- Use meaningful variable names

### Commit Messages

```
feat: Add dark mode for Messenger
fix: Resolve back navigation issue on scontent URLs
docs: Update developer guide with CSS injection examples
refactor: Migrate to annotation-based Riverpod
chore: Update dependencies to latest versions
```

### Pull Request Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make changes and test thoroughly
4. Run analysis: `fvm flutter analyze`
5. Update documentation if needed
6. Commit changes with clear messages
7. Push to your fork
8. Create a Pull Request with description

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Riverpod Documentation](https://riverpod.dev/)
- [WebView Flutter](https://pub.dev/packages/webview_flutter)
- [Material 3 Design](https://m3.material.io/)
- [Facebook Mobile Web](https://touch.facebook.com)

## Support

- **Issues**: https://github.com/rignaneseleo/SlimSocial-for-Facebook/issues
- **Discussions**: Use GitHub Discussions for questions
- **Email**: dev.rignaneseleo+slimsocial@gmail.com

---

**Last Updated**: January 2026
**Flutter Version**: 3.38.5
**Dart Version**: 3.10.4
