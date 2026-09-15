import 'dart:convert';
import 'dart:io';

// The widget tests need real strings (the CTA carries the price). Loading
// them straight into easy_localization is synchronous, where the
// EasyLocalization widget would load them off the asset bundle asynchronously.
// Both classes live under src/ only.
// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// Same reason as the import above.
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slimsocial_for_facebook/services/store_services.dart';
import 'package:slimsocial_for_facebook/services/supporter.dart';
import 'package:slimsocial_for_facebook/style/color_schemes.g.dart';

/// Loads [code] (e.g. `en-US`) with en-US behind it, as the app does.
void loadStrings([String code = 'en-US']) {
  Map<String, dynamic> read(String c) =>
      jsonDecode(File('assets/lang/$c.json').readAsStringSync())
          as Map<String, dynamic>;
  final parts = code.split('-');
  Localization.load(
    Locale(parts[0], parts[1]),
    translations: Translations(read(code)),
    fallbackTranslations: Translations(read('en-US')),
  );
}

/// Loads Roboto and the Material icons from the Flutter SDK, so text has real
/// widths (the test default, Ahem, draws every glyph as a wide box) and the
/// layout checks mean what they say on a phone.
Future<void> loadRealFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final root =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final dir = '$root/bin/cache/artifacts/material_fonts';

  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      final bytes = File('$dir/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  await family('Roboto', [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
  ]);
  await family('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

/// Prices the way Play formats them, deliberately not the nominal euros.
const Map<SupporterTier, SupporterPrice> kFakePlayPrices = {
  SupporterTier.small: SupporterPrice(formatted: r'US$10.99', raw: 10.99),
  SupporterTier.medium: SupporterPrice(formatted: r'US$26.99', raw: 26.99),
  SupporterTier.large: SupporterPrice(formatted: r'US$52.99', raw: 52.99),
};

/// A Play build with a scripted outcome for every call.
class FakeSubscriptionStore implements StoreServices {
  FakeSubscriptionStore({
    this.prices = kFakePlayPrices,
    this.purchaseResult = SupporterPurchaseResult.purchased,
    this.restoreResult = SupporterRestoreResult.notFound,
    bool supporter = false,
    this.kind = SupporterKind.subscription,
  }) : isSupporter = ValueNotifier(supporter);

  /// [SupporterKind.installFromPlay] stands in for a Play apk that did not
  /// come from Play.
  final SupporterKind kind;

  Map<SupporterTier, SupporterPrice> prices;
  SupporterPurchaseResult purchaseResult;
  SupporterRestoreResult restoreResult;

  final List<SupporterTier> supported = [];
  final List<String> donated = [];
  int priceQueries = 0;
  int restores = 0;

  @override
  final ValueNotifier<bool> isSupporter;

  @override
  SupporterKind get supporterKind => kind;

  @override
  Map<SupporterTier, SupporterPrice>? get knownSupporterPrices => null;

  @override
  Future<Map<SupporterTier, SupporterPrice>> supporterPrices() async {
    priceQueries++;
    return prices;
  }

  @override
  Future<SupporterPurchaseResult> support(SupporterTier tier) async {
    supported.add(tier);
    if (purchaseResult == SupporterPurchaseResult.purchased) {
      isSupporter.value = true;
    }
    return purchaseResult;
  }

  @override
  Future<SupporterRestoreResult> restoreSupporter() async {
    restores++;
    if (restoreResult == SupporterRestoreResult.found) isSupporter.value = true;
    return restoreResult;
  }

  @override
  String get appListingUrl => 'https://example.invalid';

  @override
  bool get canPurchase => true;

  @override
  bool get canRequestReview => false;

  @override
  Future<void> requestReview() async {}

  @override
  Future<void> donate(String productId) async => donated.add(productId);

  @override
  void dispose() {}
}

/// The app's own themes, which the screen reads its colours from.
ThemeData appTheme({required bool dark}) => ThemeData(
  useMaterial3: false,
  colorScheme: dark ? darkColorScheme : lightColorScheme,
);

/// [child] as the second route, so the close and back buttons have somewhere
/// to go.
Widget testApp(
  Widget child, {
  bool dark = false,
  bool still = true,
  double textScale = 1,
  Key? boundaryKey,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: appTheme(dark: false),
    darkTheme: appTheme(dark: true),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    builder: (context, app) {
      final media = MediaQuery.of(context);
      return MediaQuery(
        data: media.copyWith(
          disableAnimations: still,
          textScaler: TextScaler.linear(textScale),
        ),
        child: RepaintBoundary(key: boundaryKey, child: app),
      );
    },
    home: const Scaffold(body: SizedBox.shrink()),
    onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => child),
    initialRoute: '/supporter',
  );
}

/// A 390x844 phone at 3x, or a phone of [size].
void usePhone(
  WidgetTester tester, {
  double top = 0,
  double bottom = 0,
  Size size = const Size(390, 844),
}) {
  const ratio = 3.0;
  tester.view
    ..physicalSize = size * ratio
    ..devicePixelRatio = ratio
    ..padding = FakeViewPadding(top: top * ratio, bottom: bottom * ratio)
    ..viewPadding = FakeViewPadding(top: top * ratio, bottom: bottom * ratio);
  addTearDown(tester.view.reset);
}
