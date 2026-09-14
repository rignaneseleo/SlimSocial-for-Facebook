import 'package:flutter/foundation.dart';
import 'package:slimsocial_for_facebook/consts.dart';
import 'package:slimsocial_for_facebook/services/store_services.dart';
import 'package:slimsocial_for_facebook/services/supporter.dart';

/// Where F-Droid donations go. Same address as the `funding:` entry in
/// pubspec.yaml.
const String kPayPalDonationUrl = "https://www.paypal.me/LeonardoRignanese";

/// The fixed prices of a [SupporterKind.donation].
const Map<SupporterTier, SupporterPrice> kDonationPrices = {
  SupporterTier.small: SupporterPrice(formatted: '10 €', raw: 10),
  SupporterTier.medium: SupporterPrice(formatted: '25 €', raw: 25),
  SupporterTier.large: SupporterPrice(formatted: '50 €', raw: 50),
};

/// PayPal.me with the amount filled in, e.g. `.../LeonardoRignanese/25EUR`.
Uri paypalDonationUri(SupporterTier tier) =>
    Uri.parse('$kPayPalDonationUrl/${tier.nominalEuros}EUR');

/// The build with no proprietary store behind it — F-Droid, or any apk built
/// straight from source.
///
/// Billing and the rating sheet are no-ops rather than throws. The screens ask
/// [canPurchase] and [canRequestReview] first and offer something else
/// instead, so these bodies only ever run if a caller forgets; a donation tile
/// that quietly does nothing is a smaller failure than a crash. Support goes
/// to PayPal instead ([SupporterKind.donation]).
///
/// The PayPal address lives only in this file. Google Play forbids a Play app
/// to offer a payment method outside Play billing. This file stays in the
/// Play source tree (the analyzer and the tests read it), but nothing the Play
/// build runs imports it, so the address is not compiled into the Play apk.
/// It is the F-Droid *binding* that is swapped in, not this class.
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
