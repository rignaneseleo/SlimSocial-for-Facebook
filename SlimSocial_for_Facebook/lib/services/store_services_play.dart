import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:slimsocial_for_facebook/consts.dart';
import 'package:slimsocial_for_facebook/main.dart';
import 'package:slimsocial_for_facebook/services/store_services.dart';
import 'package:slimsocial_for_facebook/services/supporter.dart';
import 'package:slimsocial_for_facebook/utils/telemetry.dart';
import 'package:slimsocial_for_facebook/utils/utils.dart';
import 'package:url_launcher/url_launcher.dart';

/// The Play Store implementation: real billing, real rating sheet.
///
/// This is the only file in `lib/` allowed to import `in_app_purchase` (and its
/// Android half, `in_app_purchase_android`) or `in_app_review`. `scripts/fdroid_prepare.sh` deletes it, so nothing else
/// may reference the classes it names — not even in a type annotation.
class PlayStoreServices implements StoreServices {
  StreamSubscription<List<PurchaseDetails>>? _paymentSubscription;

  @override
  String get appListingUrl => kPlayStoreUrl;

  @override
  bool get canPurchase => true;

  @override
  bool get canRequestReview => true;

  @override
  Future<void> requestReview() async {
    try {
      final inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
      }
    }
    //deliberately everything: a rating sheet that fails to open must not take
    //down the screen that asked for it
    // ignore: avoid_catches_without_on_clauses
    catch (e, stack) {
      Telemetry.captureError(e, stack, hint: 'review request');
    }
  }

  @override
  Future<void> donate(String productId) async {
    try {
      await _launchPurchase(productId);
    } on Object catch (e, stack) {
      //Nothing used to catch here, so a throw anywhere in the billing flow left
      //the user staring at a screen that did nothing.
      Telemetry.captureError(e, stack, hint: 'donation flow');
      showToast("error_trylater".tr());
    }
  }

  //Google Play is the only installer whose store app answers the billing
  //handshake. Anything else leaves the flow half built.
  static const String _playStoreInstaller = 'com.android.vending';

  Future<void> _launchPurchase(String idItem) async {
    //SLIMSOCIAL-5: buyConsumable hands off to Google's own ProxyBillingActivity,
    //which crashes on a null PendingIntent when the install did not come from
    //the Play Store. The crash is inside that activity, so no Dart try/catch can
    //reach it — the only defence is to never start the handoff. Every event on
    //that crash carried isSideLoaded:true.
    //
    //This is the sideloaded *Play* apk. The F-Droid build never reaches here:
    //it has no billing compiled in, so its settings screen offers the same
    //PayPal link outright rather than a tile that ends up here.
    if (Platform.isAndroid &&
        packageInfo.installerStore != _playStoreInstaller) {
      Telemetry.captureIssue('billing.not_play_install');
      //these users still want to donate, so send them to PayPal instead
      await launchUrl(Uri.parse(kPayPalDonationUrl));
      return;
    }

    //get the product
    final response = await InAppPurchase.instance.queryProductDetails({idItem});
    if (response.error != null) {
      Telemetry.captureIssue('billing.query_failed');
      showToast("error_trylater".tr());
      return;
    }
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint("Product not found");
      showToast("error_trylater".tr());
      return;
    }

    //set the listener
    final purchaseUpdated = InAppPurchase.instance.purchaseStream;

    _paymentSubscription ??= purchaseUpdated.listen(
      (List<PurchaseDetails> purchaseDetailsList) {
        // handle  purchaseDetailsList
        purchaseDetailsList.forEach((PurchaseDetails purchaseDetails) async {
          //the subscription has its own listener, with its own messages
          if (purchaseDetails.productID == kSupporterProductId) return;
          if (purchaseDetails.status == PurchaseStatus.pending) {
          } else {
            if (purchaseDetails.status == PurchaseStatus.error) {
              showToast("error_trylater".tr());
            } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                purchaseDetails.status == PurchaseStatus.restored) {
              showToast("${"thankyou".tr()} ❤️");
            }
            if (purchaseDetails.pendingCompletePurchase) {
              await InAppPurchase.instance.completePurchase(purchaseDetails);
            }
          }
        });
      },
      onDone: () {
        showToast("${"thankyou".tr()} ❤️");
        debugPrint("Close subscription");
      },
      onError: (dynamic error) {
        debugPrint("Payment error: $error");
        showToast("error_trylater".tr());
      },
    );

    //show the dialog
    final product = response.productDetails.firstOrNull;
    if (product == null) {
      showToast("error_trylater".tr());
      return;
    }
    final purchaseParam = PurchaseParam(productDetails: product);

    //One breadcrumb before the handoff. SLIMSOCIAL-5 is a crash inside Google's
    //own ProxyBillingActivity.onCreate, which Dart cannot catch; this is what
    //tells us on the next occurrence whether the app ever asked for it.
    Telemetry.addBreadcrumb('billing.flow_launching');

    //buyConsumable returns false when launchBillingFlow came back non-OK.
    //Discarding it meant a declined flow looked identical to a successful one.
    final started = await InAppPurchase.instance.buyConsumable(
      purchaseParam: purchaseParam,
    );
    if (!started) {
      Telemetry.captureIssue('billing.flow_not_started');
      showToast("error_trylater".tr());
    }

    return;
  }

  // ---------------------------------------------------------------------------
  // The yearly supporter subscription.

  //Kept apart from [_paymentSubscription]: that one is cancelled when the
  //settings screen closes, while a subscription can be confirmed at any time
  //(a pending payment clears hours later), so this one lives with the app.
  // ignore: cancel_subscriptions
  StreamSubscription<List<PurchaseDetails>>? _supporterSubscription;

  //the purchase the screen is waiting on, if any
  Completer<SupporterPurchaseResult>? _supporterPurchase;

  //the Play offer behind each tier, from the last successful price query
  final Map<SupporterTier, GooglePlayProductDetails> _supporterOffers = {};

  late final ValueNotifier<bool> _isSupporter = ValueNotifier(
    sp.getBool(SpKeys.supporterActive) ?? false,
  );

  //SLIMSOCIAL-5 again: only a Play Store install can open Play's billing sheet
  bool get _canSubscribe =>
      Platform.isAndroid && packageInfo.installerStore == _playStoreInstaller;

  @override
  SupporterKind get supporterKind =>
      _canSubscribe ? SupporterKind.subscription : SupporterKind.donation;

  Map<SupporterTier, SupporterPrice>? _loadedPrices;

  @override
  Map<SupporterTier, SupporterPrice>? get knownSupporterPrices =>
      _canSubscribe ? _loadedPrices : kDonationPrices;

  @override
  ValueListenable<bool> get isSupporter => _isSupporter;

  void _setSupporter(bool value) {
    _isSupporter.value = value;
    unawaited(sp.setBool(SpKeys.supporterActive, value));
  }

  void _listenForSupporterPurchases() {
    _supporterSubscription ??= InAppPurchase.instance.purchaseStream.listen(
      (purchases) async {
        for (final purchase in purchases) {
          if (purchase.productID != kSupporterProductId) continue;
          await _handleSupporterPurchase(purchase);
        }
      },
      onError: (Object error, StackTrace stack) {
        Telemetry.captureError(error, stack, hint: 'supporter purchase stream');
        _finishSupporterPurchase(SupporterPurchaseResult.error);
      },
    );
  }

  Future<void> _handleSupporterPurchase(PurchaseDetails purchase) async {
    switch (purchase.status) {
      case PurchaseStatus.pending:
        _finishSupporterPurchase(SupporterPurchaseResult.pending);
        return;
      case PurchaseStatus.canceled:
        _finishSupporterPurchase(SupporterPurchaseResult.cancelled);
      case PurchaseStatus.error:
        Telemetry.captureIssue(
          'billing.supporter_purchase_error',
          data: {'code': purchase.error?.code},
        );
        _finishSupporterPurchase(SupporterPurchaseResult.error);
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        _setSupporter(true);
        _finishSupporterPurchase(SupporterPurchaseResult.purchased);
    }
    //Play refunds a subscription that is not acknowledged within three days
    if (purchase.pendingCompletePurchase) {
      try {
        await InAppPurchase.instance.completePurchase(purchase);
      } on Object catch (e, stack) {
        Telemetry.captureError(e, stack, hint: 'supporter acknowledge');
      }
    }
  }

  void _finishSupporterPurchase(SupporterPurchaseResult result) {
    final waiting = _supporterPurchase;
    if (waiting == null || waiting.isCompleted) return;
    waiting.complete(result);
  }

  @override
  Future<Map<SupporterTier, SupporterPrice>> supporterPrices() async {
    if (!_canSubscribe) return kDonationPrices;
    try {
      final response = await InAppPurchase.instance.queryProductDetails({
        kSupporterProductId,
      });
      if (response.error != null) {
        //mostly offline; not worth an issue per user
        Telemetry.addBreadcrumb('billing.supporter_query_failed');
        return const {};
      }
      if (response.notFoundIDs.isNotEmpty) {
        Telemetry.captureIssue('billing.supporter_product_missing');
        return const {};
      }

      final offers = <SupporterTier, GooglePlayProductDetails>{};
      for (final product
          in response.productDetails.whereType<GooglePlayProductDetails>()) {
        final index = product.subscriptionIndex;
        final details = product.productDetails.subscriptionOfferDetails;
        if (index == null || details == null || index >= details.length) {
          continue;
        }
        final offer = details[index];
        //a promotional offer on top of a base plan carries an offer id; the
        //slider sells the plain base plan
        if (offer.offerId != null) continue;
        final tier = SupporterTier.fromBasePlanId(offer.basePlanId);
        if (tier != null) offers[tier] = product;
      }

      if (offers.length != SupporterTier.values.length) {
        //a base plan not yet active in Play Console
        Telemetry.captureIssue(
          'billing.supporter_plan_missing',
          data: {'found': offers.keys.map((t) => t.basePlanId).join(',')},
        );
        return const {};
      }

      _supporterOffers
        ..clear()
        ..addAll(offers);
      return _loadedPrices = {
        for (final entry in offers.entries)
          entry.key: SupporterPrice(
            formatted: entry.value.price,
            raw: entry.value.rawPrice,
          ),
      };
    } on Object catch (e, stack) {
      Telemetry.captureError(e, stack, hint: 'supporter prices');
      return const {};
    }
  }

  @override
  Future<SupporterPurchaseResult> support(SupporterTier tier) async {
    if (!_canSubscribe) {
      return await openExternally(paypalDonationUri(tier))
          ? SupporterPurchaseResult.openedExternally
          : SupporterPurchaseResult.error;
    }
    try {
      if (!_supporterOffers.containsKey(tier)) await supporterPrices();
      final product = _supporterOffers[tier];
      if (product == null) return SupporterPurchaseResult.error;

      _listenForSupporterPurchases();
      _finishSupporterPurchase(SupporterPurchaseResult.cancelled);
      final waiting = _supporterPurchase = Completer();

      Telemetry.addBreadcrumb('billing.supporter_flow_launching');
      //buyNonConsumable picks the base plan's offer token off the product
      final started = await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) {
        //Play refuses to sell what the account already has, and that is
        //the most likely refusal here: check before calling it an error
        if (await restoreSupporter() == SupporterRestoreResult.found) {
          return SupporterPurchaseResult.purchased;
        }
        Telemetry.captureIssue('billing.supporter_flow_not_started');
        return SupporterPurchaseResult.error;
      }

      //Play always reports back; the timeout only stops a lost report from
      //leaving the button busy for good
      return await waiting.future.timeout(
        const Duration(minutes: 15),
        onTimeout: () => SupporterPurchaseResult.cancelled,
      );
    } on Object catch (e, stack) {
      Telemetry.captureError(e, stack, hint: 'supporter flow');
      return SupporterPurchaseResult.error;
    }
  }

  @override
  Future<SupporterRestoreResult> restoreSupporter() async {
    if (!_canSubscribe) return SupporterRestoreResult.failed;
    //this runs on every start, so it is also where a purchase that completes
    //later (a pending payment clearing) starts being heard
    _listenForSupporterPurchases();
    try {
      final addition =
          InAppPurchase.instance
              .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await addition.queryPastPurchases();
      if (response.error != null) {
        //mostly offline; it runs on every start, so not an issue per user
        Telemetry.addBreadcrumb('billing.supporter_restore_failed');
        return SupporterRestoreResult.failed;
      }

      //Play lists only subscriptions that are still active
      final active =
          response.pastPurchases
              .where(
                (p) =>
                    p.productID == kSupporterProductId &&
                    p.status == PurchaseStatus.purchased,
              )
              .toList();
      for (final purchase in active) {
        if (purchase.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchase);
        }
      }

      _setSupporter(active.isNotEmpty);
      return active.isEmpty
          ? SupporterRestoreResult.notFound
          : SupporterRestoreResult.found;
    } on Object catch (e, stack) {
      Telemetry.captureError(e, stack, hint: 'supporter restore');
      return SupporterRestoreResult.failed;
    }
  }

  @override
  void dispose() {
    _paymentSubscription?.cancel();
    _paymentSubscription = null;
  }
}
