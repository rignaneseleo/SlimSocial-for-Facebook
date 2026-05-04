![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)
![Kotlin](https://img.shields.io/badge/kotlin-%237F52FF.svg?style=for-the-badge&logo=kotlin&logoColor=white)
![Jetpack Compose](https://img.shields.io/badge/Jetpack%20Compose-%234285F4.svg?style=for-the-badge&logo=jetpackcompose&logoColor=white)

# SlimSocial for Facebook

SlimSocial for Facebook is a lightweight and customizable alternative to the official Facebook app. It was originally [created in 2015](https://forum.xda-developers.com/android/apps-games/app-slimfacebook-1mb-0-permissions-t3254174) as a project to explore Android app development. The codebase has been rewritten in native Kotlin (2026) for a smaller footprint, lower RAM use, and total user control over runtime permissions.

## Features

- **Lightweight** — fast and responsive even on older devices. Sub-2 MB F-Droid APK.
- **Total permission control** — every runtime permission is off at first launch. The WebView cannot request a permission the user hasn't pre-authorised.
- **Customisable** — built-in CSS toggles for dark theme, fixed bar, hide stories, center text, and more. Advanced users can run custom CSS and JS directly from the app.
- **Privacy-first** — no tracking. F-Droid build has zero proprietary classes. Play build's anonymous crash reporting is opt-out and scrubs Facebook session cookies before sending.
- **Hide ads** — multi-language sponsor-keyword filter with a dynamic MutationObserver for newly loaded posts.

## Getting Started

<a href="https://f-droid.org/packages/it.rignanese.leo.slimfacebook/" target="_blank">
<img src="https://fdroid.gitlab.io/artwork/badge/get-it-on.png" alt="Get it on F-Droid" height="50"/></a>
<a href="https://play.google.com/store/apps/details?id=it.rignanese.leo.slimfacebook" target="_blank">
<img src="https://play.google.com/intl/en_us/badges/images/generic/en_badge_web_generic.png" alt="Get it on Google Play" height="50"/></a>

## Building from source

Requires JDK 17 and the Android SDK.

```bash
# Debug build (both flavors)
./gradlew :app:assembleFullDebug :app:assembleFdroidDebug

# Run unit + Robolectric tests
./gradlew :app:testFullDebugUnitTest :app:testFdroidDebugUnitTest
```

The two product flavors:

- `full` — Play Store build with Sentry, Play Billing for in-app donations, and Play In-App Review.
- `fdroid` — FOSS build, all proprietary deps stripped at compile time. Donations route to PayPal.

Architecture and design notes live in [`docs/superpowers/specs/`](docs/superpowers/specs/). Manual test matrix in [`TESTING.md`](TESTING.md).

## Contributing

Contributions welcome — pull requests, translations, and bug reports all appreciated.

## Support

If you enjoy using SlimSocial for Facebook and would like to support the project, you can donate via PayPal [here](https://www.paypal.me/LeonardoRignanese) or inside the app. Your support is greatly appreciated.

## License

SlimSocial for Facebook is released under the [GNU General Public License v2.0](LICENSE).
