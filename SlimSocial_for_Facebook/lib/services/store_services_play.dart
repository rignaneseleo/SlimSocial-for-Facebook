import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:slimsocial_for_facebook/consts.dart';
import 'package:slimsocial_for_facebook/services/store_services.dart';
import 'package:slimsocial_for_facebook/utils/telemetry.dart';
import 'package:slimsocial_for_facebook/utils/utils.dart';

/// The Play Store implementation: real billing, real rating sheet.
///
/// This is the only file in `lib/` allowed to import `in_app_purchase` or
/// `in_app_review`. `scripts/fdroid_prepare.sh` deletes it, so nothing else
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

  Future<void> _launchPurchase(String idItem) async {
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
    final started =
        await InAppPurchase.instance.buyConsumable(purchaseParam: purchaseParam);
    if (!started) {
      Telemetry.captureIssue('billing.flow_not_started');
      showToast("error_trylater".tr());
    }

    return;
  }

  @override
  void dispose() {
    _paymentSubscription?.cancel();
    _paymentSubscription = null;
  }
}
