import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slimsocial_for_facebook/screens/supporter_page.dart';
import 'package:slimsocial_for_facebook/services/store.dart';
import 'package:slimsocial_for_facebook/services/store_services_foss.dart';
import 'package:slimsocial_for_facebook/services/supporter.dart';
import 'package:slimsocial_for_facebook/widgets/supporter_tile.dart';

import 'supporter_harness.dart';

Finder _cta() => find.byKey(const ValueKey('supporter_cta_label'));

String _ctaText(WidgetTester tester) => tester.widget<Text>(_cta()).data!;

Future<void> _open(WidgetTester tester, {bool still = true}) async {
  usePhone(tester);
  await tester.pumpWidget(testApp(const SupporterPage(), still: still));
  if (still) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  setUpAll(() async {
    loadStrings();
    await loadRealFonts();
  });
  tearDown(resetStoreServicesForTest);

  group('SupporterPage on Play', () {
    late FakeSubscriptionStore store;

    setUp(() {
      store = FakeSubscriptionStore();
      setStoreServicesForTest(store);
    });

    testWidgets('opens on the middle step, priced by Play', (tester) async {
      await _open(tester);

      expect(_ctaText(tester), r'Support for US$26.99 / year');
      expect(find.text('You keep SlimSocial independent.'), findsOneWidget);
      expect(find.text('Keep SlimSocial free and independent'), findsOneWidget);
      expect(find.text('CANCEL ANY TIME'), findsOneWidget);
      expect(find.text('Restore'), findsOneWidget);
      expect(find.text('Or leave a one-time tip'), findsOneWidget);
    });

    testWidgets('a price label under the slider selects its step', (
      tester,
    ) async {
      await _open(tester);

      await tester.tap(find.byKey(const ValueKey('supporter_step_small')));
      await tester.pumpAndSettle();
      expect(_ctaText(tester), r'Support for US$10.99 / year');
      expect(find.text('Thank you. Every supporter counts.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('supporter_step_large')));
      await tester.pumpAndSettle();
      expect(_ctaText(tester), r'Support for US$52.99 / year');
      expect(find.text('You are a hero of the free web.'), findsOneWidget);
    });

    testWidgets('dragging the slider selects a step', (tester) async {
      await _open(tester);
      final slider = find.byKey(const ValueKey('supporter_slider'));

      await tester.drag(slider, const Offset(400, 0));
      await tester.pumpAndSettle();
      expect(_ctaText(tester), r'Support for US$52.99 / year');

      await tester.drag(slider, const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(_ctaText(tester), r'Support for US$10.99 / year');
    });

    testWidgets('the button buys the selected base plan', (tester) async {
      await _open(tester);
      await tester.tap(find.byKey(const ValueKey('supporter_step_large')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('supporter_cta')));
      await tester.pumpAndSettle();

      expect(store.supported, [SupporterTier.large]);
      expect(find.text('Thank you, supporter'), findsOneWidget);
      expect(find.text('Back to SlimSocial'), findsOneWidget);
    });

    testWidgets('a failed payment says so, and Try again retries', (
      tester,
    ) async {
      store.purchaseResult = SupporterPurchaseResult.error;
      await _open(tester);

      await tester.tap(find.byKey(const ValueKey('supporter_cta')));
      await tester.pumpAndSettle();

      expect(
        find.text('Payment did not go through. You were not charged.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(store.supported, hasLength(2));
    });

    testWidgets('a cancelled payment says nothing', (tester) async {
      store.purchaseResult = SupporterPurchaseResult.cancelled;
      await _open(tester);

      await tester.tap(find.byKey(const ValueKey('supporter_cta')));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Thank you, supporter'), findsNothing);
    });

    testWidgets('a pending payment explains the wait', (tester) async {
      store.purchaseResult = SupporterPurchaseResult.pending;
      await _open(tester);

      await tester.tap(find.byKey(const ValueKey('supporter_cta')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Your payment is pending. It will activate when Google confirms.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('prices that fail to load disable the button, with a retry', (
      tester,
    ) async {
      store.prices = const {};
      await _open(tester);

      expect(
        find.byKey(const ValueKey('supporter_prices_failed')),
        findsOneWidget,
      );
      final button = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('supporter_cta')),
      );
      expect(button.onPressed, isNull);

      store.prices = kFakePlayPrices;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(store.priceQueries, 2);
      expect(_ctaText(tester), r'Support for US$26.99 / year');
    });

    testWidgets('restore finds a subscription and thanks the user', (
      tester,
    ) async {
      store.restoreResult = SupporterRestoreResult.found;
      await _open(tester);

      await tester.ensureVisible(
        find.byKey(const ValueKey('supporter_restore')),
      );
      await tester.tap(find.byKey(const ValueKey('supporter_restore')));
      await tester.pumpAndSettle();

      expect(find.text('Thank you, supporter'), findsOneWidget);
    });

    testWidgets('restore that finds nothing says so', (tester) async {
      await _open(tester);

      await tester.ensureVisible(
        find.byKey(const ValueKey('supporter_restore')),
      );
      await tester.tap(find.byKey(const ValueKey('supporter_restore')));
      await tester.pumpAndSettle();

      expect(
        find.text('No active support found on this Google account.'),
        findsOneWidget,
      );
    });

    testWidgets('the tip goes to the existing one-time product', (
      tester,
    ) async {
      await _open(tester);

      await tester.tap(find.text('Or leave a one-time tip'));
      await tester.pumpAndSettle();

      expect(store.donated, [kTipProductId]);
    });

    testWidgets('moving through the steps with motion on paints cleanly', (
      tester,
    ) async {
      await _open(tester, still: false);

      for (final step in ['small', 'large', 'medium', 'large']) {
        await tester.tap(find.byKey(ValueKey('supporter_step_$step')));
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump(const Duration(milliseconds: 900));
      }
      await tester.pump(const Duration(seconds: 2));

      expect(tester.takeException(), isNull);
      expect(_ctaText(tester), r'Support for US$52.99 / year');
    });

    testWidgets('fits a 390x844 phone without scrolling', (tester) async {
      await _open(tester);

      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      expect(scrollable.position.maxScrollExtent, 0);
    });
  });

  group('SupporterPage on F-Droid', () {
    late List<Uri> opened;

    setUp(() {
      opened = [];
      setStoreServicesForTest(
        FossStoreServices(
          openUrl: (uri) async {
            opened.add(uri);
            return true;
          },
        ),
      );
    });

    testWidgets('offers a PayPal donation at fixed euro amounts', (
      tester,
    ) async {
      await _open(tester);

      expect(_ctaText(tester), 'Donate 25 € with PayPal');
      expect(find.text('ONE-TIME DONATION'), findsOneWidget);
      expect(find.text('Privacy'), findsOneWidget);
      //nothing that only makes sense for a subscription
      expect(find.text('CANCEL ANY TIME'), findsNothing);
      expect(find.text('Restore'), findsNothing);
      expect(find.text('Or leave a one-time tip'), findsNothing);
      expect(
        find.text('Renews every year until you cancel in Google Play.'),
        findsNothing,
      );
    });

    testWidgets('the button opens PayPal with the chosen amount', (
      tester,
    ) async {
      await _open(tester);

      await tester.tap(find.byKey(const ValueKey('supporter_cta')));
      await tester.pumpAndSettle();
      expect(opened, [
        Uri.parse('https://www.paypal.me/LeonardoRignanese/25EUR'),
      ]);

      await tester.tap(find.byKey(const ValueKey('supporter_step_large')));
      await tester.pumpAndSettle();
      expect(_ctaText(tester), 'Donate 50 € with PayPal');
      await tester.tap(find.byKey(const ValueKey('supporter_cta')));
      await tester.pumpAndSettle();
      expect(
        opened.last,
        Uri.parse('https://www.paypal.me/LeonardoRignanese/50EUR'),
      );
      //no supporter state: a PayPal payment cannot be seen from the app
      expect(find.text('Thank you, supporter'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('SupporterTile', () {
    Future<void> openTile(WidgetTester tester) async {
      usePhone(tester);
      await tester.pumpWidget(
        testApp(const Scaffold(body: Column(children: [SupporterTile()]))),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('invites support, and opens the screen', (tester) async {
      setStoreServicesForTest(FakeSubscriptionStore());
      await openTile(tester);

      expect(find.text('Become a supporter'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('supporter_tile')));
      await tester.pumpAndSettle();
      expect(find.byType(SupporterPage), findsOneWidget);
    });

    testWidgets('thanks a supporter and offers to manage', (tester) async {
      final store = FakeSubscriptionStore(supporter: true);
      setStoreServicesForTest(store);
      await openTile(tester);

      expect(find.text('Thank you, supporter'), findsOneWidget);
      expect(find.text('Manage subscription'), findsOneWidget);
    });

    testWidgets('is there in the F-Droid build too', (tester) async {
      setStoreServicesForTest(const FossStoreServices());
      await openTile(tester);

      expect(find.text('Become a supporter'), findsOneWidget);
    });
  });

  group('countedPrice', () {
    const from = SupporterPrice(formatted: '€10.00', raw: 10);
    const to = SupporterPrice(formatted: '€50.00', raw: 50);

    test("is exactly Play's string at both ends", () {
      expect(countedPrice(from, to, 0), '€10.00');
      expect(countedPrice(from, to, 1), '€50.00');
    });

    test("counts inside Play's own format", () {
      expect(countedPrice(from, to, 0.5), '€30.00');
      expect(
        countedPrice(
          const SupporterPrice(formatted: '10,00 €', raw: 10),
          const SupporterPrice(formatted: '25,00 €', raw: 25),
          0.4,
        ),
        '16,00 €',
      );
      expect(
        countedPrice(
          kDonationPrices[SupporterTier.small]!,
          kDonationPrices[SupporterTier.large]!,
          0.25,
        ),
        '20 €',
      );
    });
  });

  test('the PayPal link carries the step amount in euros', () {
    expect(
      paypalDonationUri(SupporterTier.small).toString(),
      'https://www.paypal.me/LeonardoRignanese/10EUR',
    );
  });
}
