import 'package:flutter/foundation.dart';
import 'package:slimsocial_for_facebook/consts.dart';
import 'package:slimsocial_for_facebook/services/store_services.dart';
import 'package:slimsocial_for_facebook/services/supporter.dart';

/// The build with no proprietary store behind it — F-Droid, or any apk built
/// straight from source.
///
/// Billing and the rating sheet are no-ops rather than throws. The screens ask
/// [canPurchase] and [canRequestReview] first and offer something else
/// instead, so these bodies only ever run if a caller forgets; a donation tile
/// that quietly does nothing is a smaller failure than a crash. Support goes
/// to PayPal instead ([SupporterKind.donation]).
///
/// This file imports no store SDK, and stays in the Play build too — it is
/// the F-Droid *binding* that is swapped in, not this class.
class FossStoreServices implements StoreServices {
  const FossStoreServices({this.openUrl = openExternally});

  /// Opens a page outside the app. Replaced in tests.
  final Future<bool> Function(Uri) openUrl;

  @override
  String get appListingUrl => kFDroidStoreUrl;

  @override
  bool get canPurchase => false;

  @override
  bool get canRequestReview => false;

  @override
  Future<void> requestReview() async {}

  @override
  Future<void> donate(String productId) async {}

  // The supporter screen takes a one-time PayPal donation here: no billing,
  // so no subscription, no restore and no supporter state.

  @override
  SupporterKind get supporterKind => SupporterKind.donation;

  //never true: a PayPal payment cannot be seen from the app
  static final ValueNotifier<bool> _notSupporter = ValueNotifier(false);

  @override
  ValueListenable<bool> get isSupporter => _notSupporter;

  @override
  Map<SupporterTier, SupporterPrice> get knownSupporterPrices =>
      kDonationPrices;

  @override
  Future<Map<SupporterTier, SupporterPrice>> supporterPrices() async =>
      kDonationPrices;

  @override
  Future<SupporterPurchaseResult> support(SupporterTier tier) async {
    final opened = await openUrl(paypalDonationUri(tier));
    return opened
        ? SupporterPurchaseResult.openedExternally
        : SupporterPurchaseResult.error;
  }

  @override
  Future<SupporterRestoreResult> restoreSupporter() async =>
      SupporterRestoreResult.failed;

  @override
  void dispose() {}
}
