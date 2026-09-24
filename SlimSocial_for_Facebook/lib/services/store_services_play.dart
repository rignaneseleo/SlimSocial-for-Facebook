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

/// The Play Store implementation: real billing, real rating sheet.
///
/// This is the only file in `lib/` allowed to import `in_app_purchase` (and its
/// Android half, `in_app_purchase_android`) or `in_app_review`.
/// `scripts/fdroid_prepare.sh` deletes it, so nothing else may reference the
/// classes it names — not even in a type annotation.
///
/// It never offers a way to pay outside Play billing: Google Play policy
/// forbids it in a Play app. An install that cannot reach Play billing is sent
/// to the Play listing instead.
class PlayStoreServices implements StoreServices {
  PlayStoreServices({
    @visibleForTesting Stream<List<PurchaseDetails>>? purchaseStream,
    @visibleForTesting Future<bool> Function(ProductDetails)? buySubscription,
    @visibleForTesting bool Function()? installedByPlay,
    @visibleForTesting Future<bool> Function(Uri)? openUrl,
    @visibleForTesting
    Future<ProductDetailsResponse> Function(Set<String>)? queryProducts,
    @visibleForTesting Duration productRetryDelay = const Duration(seconds: 1),
  }) : _purchaseStream = purchaseStream,
       _buySubscription = buySubscription ?? _buyWithPlay,
       _installedByPlay = installedByPlay ?? _installerIsPlay,
       _openUrl = openUrl ?? openExternally,
       _queryProducts = queryProducts ?? _queryWithPlay,
       _productRetryDelay = productRetryDelay;

  final Stream<List<PurchaseDetails>>? _purchaseStream;
  final Future<bool> Function(ProductDetails) _buySubscription;
  final bool Function() _installedByPlay;
  final Future<bool> Function(Uri) _openUrl;
  final Future<ProductDetailsResponse> Function(Set<String>) _queryProducts;
  final Duration _productRetryDelay;

  static Future<ProductDetailsResponse> _queryWithPlay(Set<String> ids) =>
      InAppPurchase.instance.queryProductDetails(ids);

  static Future<bool> _buyWithPlay(ProductDetails product) =>
  //buyNonConsumable picks the base plan's offer token off the product
  InAppPurchase.instance.buyNonConsumable(
    purchaseParam: PurchaseParam(productDetails: product),
  );

  //Google Play is the only installer whose store app answers the billing
  //handshake. Anything else leaves the flow half built.
  static const String _playStoreInstaller = 'com.android.vending';

  //SLIMSOCIAL-5: Play's billing handoff goes through Google's own
  //ProxyBillingActivity, which crashes on a null PendingIntent when the install
  //did not come from the Play Store. The crash is inside that activity, so no
  //Dart try/catch can reach it — the only defence is to never start the
  //handoff. Every event on that crash carried isSideLoaded:true.
  static bool _installerIsPlay() =>
      Platform.isAndroid && packageInfo.installerStore == _playStoreInstaller;

  /// Whether Play billing can be used on this install. Checked on every call:
  /// nothing about the install changes while the app runs, and it is cheap.
  bool get _fromPlay => _installedByPlay();

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

  // ---------------------------------------------------------------------------
  // The purchase stream.

  //One listener for the life of the app, for the tip and the subscription
  //both. A purchase can be confirmed after the screen that started it has
  //closed (a pending payment clears hours later), and one that is never heard
  //is never acknowledged, so Play refunds it. Only [dispose] cancels it.
  // ignore: cancel_subscriptions
  StreamSubscription<List<PurchaseDetails>>? _purchases;

  void _listen() {
    _purchases ??= (_purchaseStream ?? InAppPurchase.instance.purchaseStream)
        .listen(
          (purchases) async {
            for (final purchase in purchases) {
              await _onPurchase(purchase);
            }
          },
          onError: (Object error, StackTrace stack) {
            Telemetry.captureError(error, stack, hint: 'purchase stream');
            if (_supporterInFlight) {
              _finishSupporterPurchase(SupporterPurchaseResult.error);
            } else {
              showToast("error_trylater".tr());
            }
          },
        );
  }

  Future<void> _onPurchase(PurchaseDetails purchase) async {
    //When Play answers a flow with no purchase in it (the user backed out, the
    //item is already owned, billing is unavailable), the plugin reports it
    //with an empty product id. It can only belong to the flow that is open,
    //and while a subscription flow is open the tip button is disabled.
    final forSupporter =
        purchase.productID == kSupporterProductId ||
        (purchase.productID.isEmpty && _supporterInFlight);
    if (forSupporter) {
      await _handleSupporterPurchase(purchase);
    } else if (purchase.productID.isNotEmpty || _tipInFlight) {
      await _handleTip(purchase);
    }
    //else: an empty report with no flow open, e.g. the echo of a refusal that
    //support() has already handled. Nothing to say.
  }

  // ---------------------------------------------------------------------------
  // The one-time tip.

  //whether a tip's billing sheet is open
  bool _tipInFlight = false;

  @override
  Future<void> donate(String productId) async {
    try {
      await _launchTip(productId);
    } on Object catch (e, stack) {
      //Nothing used to catch here, so a throw anywhere in the billing flow left
      //the user staring at a screen that did nothing.
      Telemetry.captureError(e, stack, hint: 'donation flow');
      showToast("error_trylater".tr());
    }
  }

  Future<void> _launchTip(String idItem) async {
    if (!_fromPlay) {
      //This is the Play apk installed some other way; see [_installerIsPlay].
      //A Play build may offer no payment outside Play billing, so the only
      //way on is to install from Play.
      Telemetry.captureIssue('billing.not_play_install');
      await _openUrl(Uri.parse(kPlayStoreUrl));
      return;
    }

    //get the product
    final response = await InAppPurchase.instance.queryProductDetails({idItem});
    if (response.error != null) {
      Telemetry.captureIssue('billing.query_failed');
      showToast("error_trylater".tr());
      return;
    }
    final product = response.productDetails.firstOrNull;
    if (response.notFoundIDs.isNotEmpty || product == null) {
      debugPrint("Product not found");
      showToast("error_trylater".tr());
      return;
    }

    _listen();

    //One breadcrumb before the handoff. SLIMSOCIAL-5 is a crash inside Google's
    //own ProxyBillingActivity.onCreate, which Dart cannot catch; this is what
    //tells us on the next occurrence whether the app ever asked for it.
    Telemetry.addBreadcrumb('billing.flow_launching');

    //buyConsumable returns false when launchBillingFlow came back non-OK.
    //Discarding it meant a declined flow looked identical to a successful one.
    _tipInFlight = true;
    final started = await InAppPurchase.instance.buyConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
    if (!started) {
      _tipInFlight = false;
      Telemetry.captureIssue('billing.flow_not_started');
      showToast("error_trylater".tr());
    }
  }

  Future<void> _handleTip(PurchaseDetails purchase) async {
    if (purchase.status != PurchaseStatus.pending) _tipInFlight = false;
    switch (purchase.status) {
      case PurchaseStatus.pending:
      case PurchaseStatus.canceled:
        break;
      case PurchaseStatus.error:
        showToast("error_trylater".tr());
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        showToast("${"thankyou".tr()} ❤️");
    }
    if (purchase.status != PurchaseStatus.pending &&
        purchase.pendingCompletePurchase) {
      await InAppPurchase.instance.completePurchase(purchase);
    }
  }

  // ---------------------------------------------------------------------------
  // The yearly supporter subscription.

  //the purchase the screen is waiting on, if any
  Completer<SupporterPurchaseResult>? _supporterPurchase;

  bool get _supporterInFlight {
    final waiting = _supporterPurchase;
    return waiting != null && !waiting.isCompleted;
  }

  //the Play offer behind each tier, from the last successful price query
  final Map<SupporterTier, ProductDetails> _supporterOffers = {};
  Map<SupporterTier, SupporterPrice>? _loadedPrices;

  late final ValueNotifier<bool> _isSupporter = ValueNotifier(
    sp.getBool(SpKeys.supporterActive) ?? false,
  );

  @override
  SupporterKind get supporterKind =>
      _fromPlay ? SupporterKind.subscription : SupporterKind.installFromPlay;

  @override
  Map<SupporterTier, SupporterPrice>? get knownSupporterPrices =>
      _fromPlay ? _loadedPrices : null;

  @override
  ValueListenable<bool> get isSupporter => _isSupporter;

  void _setSupporter(bool value) {
    _isSupporter.value = value;
    unawaited(sp.setBool(SpKeys.supporterActive, value));
  }

  Future<void> _handleSupporterPurchase(PurchaseDetails purchase) async {
    switch (purchase.status) {
      case PurchaseStatus.pending:
        _finishSupporterPurchase(SupporterPurchaseResult.pending);
        return;
      case PurchaseStatus.canceled:
        _finishSupporterPurchase(SupporterPurchaseResult.cancelled);
      case PurchaseStatus.error:
        if (_isAlreadyOwned(purchase)) {
          //Play will not sell what the account already has: it is a supporter
          final restored = await restoreSupporter();
          _finishSupporterPurchase(
            restored == SupporterRestoreResult.found
                ? SupporterPurchaseResult.purchased
                : SupporterPurchaseResult.error,
          );
        } else {
          Telemetry.captureIssue(
            'billing.supporter_purchase_error',
            data: {'code': purchase.error?.message},
          );
          _finishSupporterPurchase(SupporterPurchaseResult.error);
        }
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

  //in_app_purchase_android puts the BillingResponse name in the message
  static bool _isAlreadyOwned(PurchaseDetails purchase) =>
      purchase.error?.message.contains('itemAlreadyOwned') ?? false;

  void _finishSupporterPurchase(SupporterPurchaseResult result) {
    final waiting = _supporterPurchase;
    if (waiting == null || waiting.isCompleted) return;
    waiting.complete(result);
  }

  /// Uses [offers] as if Play had returned them, for tests.
  @visibleForTesting
  void debugUseOffers(Map<SupporterTier, ProductDetails> offers) {
    _supporterOffers
      ..clear()
      ..addAll(offers);
    _loadedPrices = _pricesOf(offers);
  }

  static Map<SupporterTier, SupporterPrice> _pricesOf(
    Map<SupporterTier, ProductDetails> offers,
  ) => {
    for (final entry in offers.entries)
      entry.key: SupporterPrice(
        formatted: entry.value.price,
        raw: entry.value.rawPrice,
      ),
  };

  static bool _isIncomplete(ProductDetailsResponse response) =>
      response.notFoundIDs.isNotEmpty || response.productDetails.isEmpty;

  @override
  Future<Map<SupporterTier, SupporterPrice>> supporterPrices() async {
    if (!_fromPlay) return const {};
    try {
      var response = await _queryProducts({kSupporterProductId});
      //in_app_purchase_android drops Play's response code and lists every id
      //it got nothing back for as not found, so a query that failed on the
      //way (billing service reconnecting, network down) reads the same as a
      //product that does not exist. A second query tells the two apart.
      if (response.error == null && _isIncomplete(response)) {
        await Future<void>.delayed(_productRetryDelay);
        response = await _queryProducts({kSupporterProductId});
      }
      if (response.error != null) {
        //mostly offline; not worth an issue per user
        Telemetry.addBreadcrumb('billing.supporter_query_failed');
        return const {};
      }
      if (_isIncomplete(response)) {
        Telemetry.captureIssue('billing.supporter_product_missing');
        return const {};
      }

      final offers = <SupporterTier, ProductDetails>{};
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

      debugUseOffers(offers);
      return _loadedPrices!;
    } on Object catch (e, stack) {
      Telemetry.captureError(e, stack, hint: 'supporter prices');
      return const {};
    }
  }

  @override
  Future<SupporterPurchaseResult> support(SupporterTier tier) async {
    if (!_fromPlay) {
      //the screen disables its button here; this is the same way on
      await _openUrl(Uri.parse(kPlayStoreUrl));
      return SupporterPurchaseResult.openedExternally;
    }
    try {
      if (!_supporterOffers.containsKey(tier)) await supporterPrices();
      final product = _supporterOffers[tier];
      if (product == null) return SupporterPurchaseResult.error;

      _listen();
      _finishSupporterPurchase(SupporterPurchaseResult.cancelled);
      final waiting = _supporterPurchase = Completer();

      Telemetry.addBreadcrumb('billing.supporter_flow_launching');
      final started = await _buySubscription(product);
      if (!started) {
        _finishSupporterPurchase(SupporterPurchaseResult.error);
        //Play refuses to sell what the account already has, and that is
        //the most likely refusal here: check before calling it an error
        if (await restoreSupporter() == SupporterRestoreResult.found) {
          return SupporterPurchaseResult.purchased;
        }
        Telemetry.captureIssue('billing.supporter_flow_not_started');
        return SupporterPurchaseResult.error;
      }

      //Play reports every outcome on the stream, empty ones included (see
      //[_onPurchase]). The timeout only frees the button if a report is lost;
      //a purchase that lands later still reaches [isSupporter].
      return await waiting.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () => SupporterPurchaseResult.cancelled,
      );
    } on Object catch (e, stack) {
      Telemetry.captureError(e, stack, hint: 'supporter flow');
      return SupporterPurchaseResult.error;
    }
  }

  @override
  Future<SupporterRestoreResult> restoreSupporter() async {
    if (!_fromPlay) return SupporterRestoreResult.failed;
    //this runs on every start, so it is also where a purchase that completes
    //later (a pending payment clearing) starts being heard
    _listen();
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
    _purchases?.cancel();
    _purchases = null;
  }
}
