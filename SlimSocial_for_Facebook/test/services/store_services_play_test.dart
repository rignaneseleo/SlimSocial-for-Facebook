// The Play implementation, with the store SDK replaced at its seams.
//
// This file imports store_services_play.dart, which the F-Droid build deletes,
// so scripts/fdroid_prepare.sh deletes this test too.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slimsocial_for_facebook/consts.dart';
import 'package:slimsocial_for_facebook/main.dart' show sp;
import 'package:slimsocial_for_facebook/screens/supporter_page.dart';
import 'package:slimsocial_for_facebook/services/store.dart';
import 'package:slimsocial_for_facebook/services/store_services_play.dart';
import 'package:slimsocial_for_facebook/services/supporter.dart';

import '../screens/supporter_harness.dart';

ProductDetails _offer(String price, double raw) => ProductDetails(
  id: kSupporterProductId,
  title: 'Supporter',
  description: '',
  price: price,
  rawPrice: raw,
  currencyCode: 'EUR',
);

final Map<SupporterTier, ProductDetails> _offers = {
  SupporterTier.small: _offer('€10.00', 10),
  SupporterTier.medium: _offer('€25.00', 25),
  SupporterTier.large: _offer('€50.00', 50),
};

/// What in_app_purchase_android 0.5.2 reports when Play answers a flow with
/// no purchase in it: the user backed out, the item is already owned, billing
/// is unavailable.
PurchaseDetails _emptyReport(PurchaseStatus status, {String? response}) =>
    PurchaseDetails(
        purchaseID: '',
        productID: '',
        status: status,
        transactionDate: null,
        verificationData: PurchaseVerificationData(
          localVerificationData: '',
          serverVerificationData: '',
          source: 'google_play',
        ),
      )
      ..error =
          response == null
              ? null
              : IAPError(
                source: 'google_play',
                code: 'purchase_error',
                message: response,
              );

Finder _cta() => find.byKey(const ValueKey('supporter_cta'));

bool _ctaEnabled(WidgetTester tester) =>
    tester.widget<ElevatedButton>(_cta()).onPressed != null;

void main() {
  setUpAll(() async {
    loadStrings();
    await loadRealFonts();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sp = await SharedPreferences.getInstance();
  });

  tearDown(resetStoreServicesForTest);

  group('a Play apk not installed by Play', () {
    late List<Uri> opened;
    late PlayStoreServices store;

    setUp(() {
      opened = [];
      store = PlayStoreServices(
        installedByPlay: () => false,
        openUrl: (uri) async {
          opened.add(uri);
          return true;
        },
      );
    });

    test('only ever points to the Play listing, never to PayPal', () async {
      expect(store.supporterKind, SupporterKind.installFromPlay);
      expect(store.knownSupporterPrices, isNull);
      expect(await store.supporterPrices(), isEmpty);

      for (final tier in SupporterTier.values) {
        await store.support(tier);
      }
      await store.donate(kTipProductId);

      expect(opened, isNotEmpty);
      for (final uri in opened) {
        expect(uri.toString(), kPlayStoreUrl);
        expect(uri.host, isNot(contains('paypal')));
      }
    });

    testWidgets('the screen disables buying and offers Google Play', (
      tester,
    ) async {
      setStoreServicesForTest(store);
      usePhone(tester);
      await tester.pumpWidget(testApp(const SupporterPage()));
      await tester.pumpAndSettle();

      expect(
        find.text('Install SlimSocial from Google Play to support it.'),
        findsOneWidget,
      );
      expect(_ctaEnabled(tester), isFalse);
      final slider = tester.widget<Slider>(
        find.byKey(const ValueKey('supporter_slider')),
      );
      expect(slider.onChanged, isNull);
      expect(find.text('Or leave a one-time tip'), findsNothing);
      expect(find.text('Restore'), findsNothing);
      expect(find.textContaining('PayPal'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('supporter_open_play')));
      await tester.pumpAndSettle();
      expect(opened, [Uri.parse(kPlayStoreUrl)]);
    });
  });

  group('a Play install, while the billing sheet is open', () {
    late StreamController<List<PurchaseDetails>> reports;
    late PlayStoreServices store;

    setUp(() {
      reports = StreamController.broadcast();
      store = PlayStoreServices(
        installedByPlay: () => true,
        purchaseStream: reports.stream,
        buySubscription: (_) async => true,
      )..debugUseOffers(_offers);
    });

    tearDown(() async {
      store.dispose();
      await reports.close();
    });

    testWidgets('backing out frees the button again, silently', (tester) async {
      setStoreServicesForTest(store);
      usePhone(tester);
      await tester.pumpWidget(testApp(const SupporterPage()));
      await tester.pumpAndSettle();
      expect(_ctaEnabled(tester), isTrue);

      await tester.tap(_cta());
      await tester.pump();
      expect(_ctaEnabled(tester), isFalse, reason: 'busy while Play is open');

      reports.add([_emptyReport(PurchaseStatus.canceled)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(_ctaEnabled(tester), isTrue);
      expect(find.byType(SnackBar), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('an empty error report shows the payment error', (
      tester,
    ) async {
      setStoreServicesForTest(store);
      usePhone(tester);
      await tester.pumpWidget(testApp(const SupporterPage()));
      await tester.pumpAndSettle();

      await tester.tap(_cta());
      await tester.pump();
      reports.add([
        _emptyReport(
          PurchaseStatus.error,
          response: 'BillingResponse.billingUnavailable',
        ),
      ]);
      await tester.pumpAndSettle();

      expect(_ctaEnabled(tester), isTrue);
      expect(
        find.text('Payment did not go through. You were not charged.'),
        findsOneWidget,
      );
    });

    test('a purchase report makes the user a supporter', () async {
      final result = store.support(SupporterTier.large);
      await Future<void>.delayed(Duration.zero);
      reports.add([
        PurchaseDetails(
          productID: kSupporterProductId,
          status: PurchaseStatus.purchased,
          transactionDate: null,
          verificationData: PurchaseVerificationData(
            localVerificationData: '',
            serverVerificationData: '',
            source: 'google_play',
          ),
        ),
      ]);

      expect(await result, SupporterPurchaseResult.purchased);
      expect(store.isSupporter.value, isTrue);
      expect(sp.getBool(SpKeys.supporterActive), isTrue);
    });

    test('an empty report with no flow open is ignored', () async {
      //the echo of a refusal that support() already handled; a tip toast here
      //would need the platform and fail the test
      store.restoreSupporter().ignore();
      reports.add([_emptyReport(PurchaseStatus.error, response: 'x')]);
      await Future<void>.delayed(Duration.zero);
      expect(store.isSupporter.value, isFalse);
    });
  });
}
