import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:slimsocial_for_facebook/screens/supporter_page.dart';
import 'package:slimsocial_for_facebook/services/store.dart';
import 'package:slimsocial_for_facebook/services/store_services_foss.dart';
import 'package:slimsocial_for_facebook/services/supporter.dart';
import 'package:slimsocial_for_facebook/widgets/supporter_tile.dart';

import 'supporter_harness.dart';

/// Renders the supporter screen to PNGs for a human to look at.
///
/// Skipped unless `SLIM_SHOTS_DIR` names a directory:
///
///     SLIM_SHOTS_DIR=/tmp/shots flutter test test/screens/supporter_screenshots_test.dart
///
/// A 390x844 phone with a 28dp status bar and a 20dp gesture bar, real Roboto.
final String? _dir = Platform.environment['SLIM_SHOTS_DIR'];

const _shotKey = ValueKey('shot');

/// Euro prices formatted the way Play shows them in an English locale.
const Map<SupporterTier, SupporterPrice> _euroPrices = {
  SupporterTier.small: SupporterPrice(formatted: '€10.00', raw: 10),
  SupporterTier.medium: SupporterPrice(formatted: '€25.00', raw: 25),
  SupporterTier.large: SupporterPrice(formatted: '€50.00', raw: 50),
};

Future<void> _shoot(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_shotKey),
  );
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!;
  });
  Directory(_dir!).createSync(recursive: true);
  File('$_dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

Future<void> _pumpScreen(
  WidgetTester tester,
  Widget child, {
  bool dark = false,
  double textScale = 1,
}) async {
  usePhone(tester, top: 28, bottom: 20);
  await tester.pumpWidget(
    testApp(
      child,
      dark: dark,
      still: false,
      textScale: textScale,
      boundaryKey: _shotKey,
    ),
  );
  //past the route transition; the heart keeps beating, so never settle
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));
}

Future<void> _toStep(WidgetTester tester, String step) async {
  await tester.tap(find.byKey(ValueKey('supporter_step_$step')));
  await tester.pump();
  //past the spring and the count, mid-burst for a step up
  await tester.pump(const Duration(milliseconds: 650));
}

double _scrollExtent(WidgetTester tester) =>
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .maxScrollExtent;

void main() {
  setUpAll(() async {
    loadStrings();
    await loadRealFonts();
  });
  tearDown(resetStoreServicesForTest);

  final skip = _dir == null;

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('play steps ($theme)', skip: skip, (tester) async {
      setStoreServicesForTest(FakeSubscriptionStore(prices: _euroPrices));
      await _pumpScreen(tester, const SupporterPage(), dark: dark);
      expect(_scrollExtent(tester), 0, reason: 'scrolls at default size');
      await _shoot(tester, 'play_step25_$theme');

      await _toStep(tester, 'small');
      await tester.pump(const Duration(milliseconds: 600));
      await _shoot(tester, 'play_step10_$theme');

      await tester.tap(find.byKey(const ValueKey('supporter_step_large')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 420));
      await _shoot(tester, 'play_step50_burst_$theme');
      await tester.pump(const Duration(milliseconds: 1400));
      await _shoot(tester, 'play_step50_$theme');
    });

    testWidgets('thanks ($theme)', skip: skip, (tester) async {
      setStoreServicesForTest(
        FakeSubscriptionStore(prices: _euroPrices, supporter: true),
      );
      await _pumpScreen(tester, const SupporterPage(), dark: dark);
      await tester.pump(const Duration(seconds: 4));
      await _shoot(tester, 'thanks_$theme');
    });

    testWidgets('settings tile ($theme)', skip: skip, (tester) async {
      final store = FakeSubscriptionStore(prices: _euroPrices);
      setStoreServicesForTest(store);
      final settings = Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: SettingsList(
          sections: [
            const CustomSettingsSection(child: SupporterTile()),
            SettingsSection(
              title: const Text('SlimSocial'),
              tiles: [
                SettingsTile.navigation(
                  leading: const Icon(Icons.privacy_tip),
                  title: const Text('Privacy'),
                  description: const Text(
                    'No personal or device information is ever collected or '
                    'transmitted by this app.',
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      await _pumpScreen(tester, settings, dark: dark);
      await _shoot(tester, 'settings_tile_$theme');

      store.isSupporter.value = true;
      await tester.pump();
      await _shoot(tester, 'settings_tile_supporter_$theme');
    });
  }

  testWidgets('play states', skip: skip, (tester) async {
    final store = FakeSubscriptionStore(
      prices: const {},
      purchaseResult: SupporterPurchaseResult.error,
    );
    setStoreServicesForTest(store);
    await _pumpScreen(tester, const SupporterPage());
    await _shoot(tester, 'play_prices_failed_light');

    store.prices = _euroPrices;
    await tester.tap(find.text('Try again'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('supporter_cta')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await _shoot(tester, 'play_payment_error_light');
  });

  testWidgets('play at text scale 1.3', skip: skip, (tester) async {
    setStoreServicesForTest(FakeSubscriptionStore(prices: _euroPrices));
    await _pumpScreen(tester, const SupporterPage(), textScale: 1.3);
    await _shoot(tester, 'play_step25_text130_light');
    //print how far it scrolls, for the report
    debugPrint('text 1.3 scroll extent: ${_scrollExtent(tester)}');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
    await tester.pump(const Duration(milliseconds: 800));
    await _shoot(tester, 'play_step25_text130_scrolled_light');
  });

  for (final locale in ['it-IT', 'de-DE', 'ru-RU']) {
    testWidgets('play in $locale', skip: skip, (tester) async {
      loadStrings(locale);
      addTearDown(loadStrings);
      setStoreServicesForTest(FakeSubscriptionStore(prices: _euroPrices));
      await _pumpScreen(tester, const SupporterPage());
      debugPrint('$locale scroll extent: ${_scrollExtent(tester)}');
      await _shoot(tester, 'play_step25_${locale}_light');
    });
  }

  testWidgets('play apk not installed by play', skip: skip, (tester) async {
    setStoreServicesForTest(
      FakeSubscriptionStore(kind: SupporterKind.installFromPlay),
    );
    await _pumpScreen(tester, const SupporterPage());
    expect(_scrollExtent(tester), 0, reason: 'scrolls at default size');
    await _shoot(tester, 'play_not_from_play_light');
  });

  testWidgets('f-droid donation', skip: skip, (tester) async {
    setStoreServicesForTest(const FossStoreServices());
    await _pumpScreen(tester, const SupporterPage());
    expect(_scrollExtent(tester), 0, reason: 'scrolls at default size');
    await _shoot(tester, 'foss_step25_light');
  });
}
