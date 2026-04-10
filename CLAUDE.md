# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SlimSocial for Facebook is a lightweight Flutter-based wrapper for Facebook's mobile site. The app provides a customizable, privacy-focused alternative to the official Facebook app by:
- Loading Facebook's mobile site in a WebView
- Injecting custom CSS to hide ads and modify the UI
- Injecting custom JavaScript to enhance functionality
- Supporting custom user agents and proxies
- Minimal permissions and data collection

**Key Update (2026)**: The project has been fully modernized with Flutter 3.38.5, Material 3, and annotation-based Riverpod.

## Working Directory

The main Flutter project is located in: `SlimSocial_for_Facebook/`

All Flutter commands should be run from this directory using FVM.

## Development Commands

### Setup
```bash
# Use FVM for Flutter version management
fvm use 3.38.5
fvm flutter pub get

# Generate Riverpod providers
fvm dart run build_runner build --delete-conflicting-outputs
```

### Build Commands
```bash
# Android APK
fvm flutter build apk

# Android App Bundle (for Play Store)
fvm flutter build appbundle

# iOS
fvm flutter build ios
```

### Run Commands
```bash
# Run on connected device
fvm flutter run

# Run with specific device
fvm flutter devices
fvm flutter run -d <device-id>

# Run in release mode
fvm flutter run --release
```

### Code Generation
```bash
# Generate Riverpod providers (after modifying provider files)
fvm dart run build_runner build --delete-conflicting-outputs

# Watch mode for continuous generation
fvm dart run build_runner watch --delete-conflicting-outputs

# Clean generated files
fvm dart run build_runner clean
```

### Analysis and Linting
```bash
# Analyze code
fvm flutter analyze

# Run custom lint (includes Riverpod lint)
fvm dart run custom_lint
```

### Icon Generation
```bash
# Generate app icons from assets/logo.png
fvm dart run flutter_launcher_icons
```

## Architecture

### Modern Tech Stack (2026)
- **Flutter 3.38.5** with Dart 3.10.4
- **Material 3** (useMaterial3: true) with custom color schemes
- **Riverpod 2.6+** with annotation-based providers and code generation
- **PopScope** (replaces deprecated WillPopScope)
- **Modern linting** with flutter_lints + custom rules

### State Management with Riverpod

The project uses **annotation-based Riverpod** with code generation for type-safe state management.

Key providers in `lib/providers/webview_providers.dart`:
- `fbWebViewProvider` - Manages Facebook WebView URL state
- `messengerWebViewProvider` - Manages Messenger WebView URL state

**Creating a new provider:**

```dart
// lib/providers/my_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'my_provider.g.dart';

@riverpod
class MyFeature extends _$MyFeature {
  @override
  String build() => 'initial value';

  void updateValue(String newValue) => state = newValue;
}
```

After creating/modifying providers, run:
```bash
fvm dart run build_runner build --delete-conflicting-outputs
```

**Using providers:**
```dart
// Watch (rebuild on change)
final value = ref.watch(myFeatureProvider);

// Read (no rebuild)
ref.read(myFeatureProvider.notifier).updateValue('new');

// Listen (side effects)
ref.listen<String>(myFeatureProvider, (previous, next) {
  // React to changes
});

// Invalidate (refresh)
ref.invalidate(myFeatureProvider);
```

### Core Components

#### 1. WebView Management (lib/screens/home_page.dart)
- Uses `webview_flutter` package to display Facebook's mobile site
- Handles navigation decisions to keep users within Facebook domains
- Manages custom widget callbacks for full-screen videos and file pickers
- Injects CSS on page start and JavaScript on page finish
- Uses **PopScope** for back navigation (replaces WillPopScope)

#### 2. CSS Injection System (lib/utils/css.dart)
The app uses a custom CSS system to modify Facebook's appearance:
- CSS strings are defined as `MyCss` objects with a key, description, and code
- Settings are stored in SharedPreferences using the CSS key
- CSS is injected via JavaScript on page load (home_page.dart:390)
- Key CSS customizations:
  - Dark theme (`darkThemeCss`) - with separate messenger dark theme
  - Hide ads (`hideAdsAndPeopleYouMayKnowCss`)
  - Hide stories (`hideStoriesCss`)
  - Fixed navigation bar (`fixedBarCss`)
  - Messenger UI adaptations (`adaptMessengerPageCss`)

#### 3. JavaScript Injection System (lib/utils/js.dart)
Custom JavaScript is injected to enhance functionality:
- `removeAdsFunc` - Finds and removes sponsored posts in 40+ languages
- `removeAdsObserver` - MutationObserver to remove ads as new content loads
- `injectCssFunc()` - Helper to inject CSS via JavaScript
- Users can add custom JavaScript via settings

#### 4. Preferences Controller (lib/controllers/fb_controller.dart)
Centralized logic for user preferences:
- `getHomePage()` - Returns the appropriate Facebook URL (touch, mbasic) with sorting options
- `getUserAgent()` - Returns custom or default user agent
- `getUserCustomCss()` - Returns user's custom CSS if enabled
- `getUserCustomJs()` - Returns user's custom JavaScript if enabled

**Note:** This file no longer contains Riverpod state (moved to providers/).

#### 5. Navigation & URL Handling
The app handles different URL patterns:
- **Facebook URLs** (`kPermittedHostnamesFb`) - Load in main WebView
- **Messenger URLs** (`kPermittedHostnamesMessenger`) - Open in separate MessengerPage
- **External URLs** - Open in custom tabs or external browser
- **Deep Links** - App links handled via `app_links` package to open Facebook URLs directly

### Data Flow

1. App starts → loads SharedPreferences → sets up ProviderScope
2. HomePage initializes WebViewController with user preferences
3. WebView navigation triggers CSS/JS injection
4. User actions update Riverpod state → WebView reloads/refreshes
5. Settings changes stored in SharedPreferences → triggers provider invalidation

### Key Files

- `lib/main.dart` - App entry point, Material 3 theme setup, app links initialization
- `lib/providers/webview_providers.dart` - Annotation-based Riverpod providers
- `lib/screens/home_page.dart` - Main Facebook WebView screen with PopScope
- `lib/screens/messenger_page.dart` - Messenger WebView screen with PopScope
- `lib/screens/settings_page.dart` - Settings UI with permissions, customization options
- `lib/controllers/fb_controller.dart` - Preference logic (no more Riverpod state)
- `lib/utils/css.dart` - CSS injection definitions
- `lib/utils/js.dart` - JavaScript injection definitions
- `lib/consts.dart` - Constants (URLs, user agents, etc.)
- `lib/style/color_schemes.g.dart` - Material 3 color schemes

## Extending Functionality

### Adding New CSS Customizations

1. Define a new `MyCss` object in `lib/utils/css.dart`:
```dart
static MyCss myNewCss = MyCss(
  key: 'my_css_feature',
  description: 'Description of what it does',
  code: 'div.selector { display: none !important; }',
  defaultEnabled: false, // optional
);
```

2. Add it to the `cssList` in `CustomCss` class
3. Add a toggle in `lib/screens/settings_page.dart` under the "style" section (around line 204)
4. Call `ref.invalidate(fbWebViewProvider)` when toggle changes to refresh the WebView
5. CSS will automatically be injected if enabled

### Adding New JavaScript Features

1. Define JavaScript code in `lib/utils/js.dart` as a static String
2. Call `_controller.runJavaScript(yourJsCode)` in HomePage
3. For page-load injection, add to `injectCss()` method (home_page.dart:390)
4. For post-load injection, add to `runJs()` method (home_page.dart:411)

### Adding New Settings

1. Choose a unique SharedPreferences key
2. Add a `SettingsTile` in `lib/screens/settings_page.dart`
3. Use `sp.setBool()`, `sp.getString()`, etc. to persist values
4. Access values via `sp.getBool('your_key')` throughout the app
5. If affecting WebView, call `ref.invalidate(fbWebViewProvider)` to refresh

### Adding New Riverpod Providers

1. Create file `lib/providers/my_provider.dart`
2. Add annotation-based provider:
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'my_provider.g.dart';

@riverpod
class MyProvider extends _$MyProvider {
  @override
  MyType build() {
    // Initialize state
    return MyType();
  }

  void myMethod() {
    // Update state
    state = newValue;
  }
}
```

3. Run code generation:
```bash
fvm dart run build_runner build --delete-conflicting-outputs
```

4. Import and use in widgets:
```dart
final value = ref.watch(myProviderProvider);
ref.read(myProviderProvider.notifier).myMethod();
```

### Adding Translations

1. Translations are in `assets/lang/` directory (40+ languages supported)
2. Add new keys to all language JSON files
3. Use `.tr()` extension method to access translations: `"my_key".tr()`
4. For arguments: `"welcome_user".tr(args: ['John'])`

## Important Notes

- **Material 3**: Now enabled (`useMaterial3: true` in main.dart:136, 141)
- **PopScope**: WillPopScope has been replaced with PopScope for modern navigation handling
- **Riverpod Annotations**: All providers use `@riverpod` annotations with code generation
- **Code Generation**: Always run `build_runner` after modifying provider files
- **WebView Platform Specific Code**: Android-specific code uses `AndroidWebViewController` for features like file selection, geolocation, and fullscreen video
- **Privacy**: The app stores minimal data (only SharedPreferences for settings). No analytics or tracking unless added
- **FVM**: Always use `fvm flutter` instead of `flutter` for consistency

## Testing Facebook Changes

Facebook frequently changes their HTML structure, breaking CSS selectors. When users report issues:

1. Enable developer mode to see "Send to Dev" option in settings
2. Test with different user agents (Firefox, Opera Mini, iPad)
3. Use Chrome DevTools on desktop Facebook to inspect element selectors
4. Update CSS selectors in `lib/utils/css.dart`
5. Test ad removal by checking multiple languages in `removeAdsFunc`
6. Consider that Facebook A/B tests different UIs

## Common Issues

### Riverpod Provider Not Found
```bash
fvm dart run build_runner build --delete-conflicting-outputs
```

### Build Runner Fails
```bash
fvm flutter clean
fvm flutter pub get
fvm dart run build_runner clean
fvm dart run build_runner build --delete-conflicting-outputs
```

### Ad blocking fails
- Facebook changes "Sponsored" text or DOM structure → update `removeAdsFunc` keywords or CSS
- Check if Facebook is using new ad markers

### Messenger not loading
- Check `kPermittedHostnamesMessenger` constants
- Verify MessengerPage CSS adaptations are current

### Images not downloading
- Check `scontent` URL detection in home_page.dart:56
- Verify photo permission is granted

### Permissions not working
- Android permissions require runtime requests → see `handlePermission()` in settings_page.dart:438
- iOS requires Info.plist entries

### Back navigation issues
- Check PopScope implementation in home_page.dart:360
- Verify scontent double-back logic (home_page.dart:370)

## Code Quality

The project uses modern linting rules defined in `analysis_options.yaml`:
- `flutter_lints` as base
- Additional rules for code quality (prefer_const, trailing_commas, etc.)
- Riverpod-specific linting via `riverpod_lint`
- Strict mode enabled (strict-casts, strict-inference, strict-raw-types)

Run analysis before committing:
```bash
fvm flutter analyze
fvm dart run custom_lint
```

## Additional Resources

See `DEVELOPER_GUIDE.md` for comprehensive documentation including:
- Detailed architecture explanations
- Step-by-step tutorials for common tasks
- CSS/JavaScript injection deep dive
- Testing strategies
- Deployment checklist
- Troubleshooting guide
- Contributing guidelines
