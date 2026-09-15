import 'package:flutter/foundation.dart';
import 'package:slimsocial_for_facebook/services/supporter.dart';

/// Everything this app asks an app store to do.
///
/// The two things behind it — in-app billing and the store's own rating sheet
/// — are proprietary, and the F-Droid build must not contain them. So no
/// screen calls them directly: screens call this interface, and exactly one
/// file decides which implementation they get.
///
/// That file is `store_binding.dart`. The F-Droid build replaces it with
/// `store_binding_foss.dart` and deletes `store_services_play.dart`, which is
/// the only file in `lib/` that imports `in_app_purchase` or `in_app_review`.
/// `scripts/fdroid_prepare.sh` does both, and `test/fdroid_build_test.dart`
/// fails if a proprietary import ever appears anywhere else.
abstract interface class StoreServices {
  /// Whether donations can be taken inside the app.
  ///
  /// False in the F-Droid build, where the settings screen offers an external
  /// donation link instead of in-app billing.
  bool get canPurchase;

  /// Where to send someone who wants to install the app.
  ///
  /// Per store, because the Play build sharing an F-Droid link (or the other
  /// way round) sends people to a page that will not update the copy they
  /// already have.
  String get appListingUrl;

  /// Whether the store can show its own rating sheet.
  ///
  /// False in the F-Droid build: F-Droid has no ratings, so nothing is offered
  /// in place of the tile and the rating dialog simply thanks the user.
  bool get canRequestReview;

  /// Asks the store to show its rating sheet. Does nothing when
  /// [canRequestReview] is false, and never throws.
  Future<void> requestReview();

  /// Runs the donation flow for [productId], toasting the outcome.
  ///
  /// The whole flow lives behind this call — product lookup, the purchase
  /// stream, and completing the purchase — because every part of it is
  /// proprietary. Does nothing when [canPurchase] is false, and never throws.
  Future<void> donate(String productId);

  /// What the supporter screen sells in this build.
  ///
  /// [SupporterKind.subscription] in a Play build installed by the Play
  /// Store, [SupporterKind.installFromPlay] in a Play build installed any
  /// other way, and [SupporterKind.donation] in the F-Droid build.
  SupporterKind get supporterKind;

  /// Whether this install has an active supporter subscription.
  ///
  /// Starts from the value saved on the device, so it is right offline, and
  /// is corrected by [restoreSupporter] and by purchases as they arrive.
  /// Always false unless [supporterKind] is [SupporterKind.subscription].
  ValueListenable<bool> get isSupporter;

  /// The prices already known without asking the store, or null.
  ///
  /// Fixed euro amounts for a donation; for a subscription, the prices from
  /// the last successful [supporterPrices] in this session. Null for
  /// [SupporterKind.installFromPlay], which shows no price.
  Map<SupporterTier, SupporterPrice>? get knownSupporterPrices;

  /// The localized price for every [SupporterTier].
  ///
  /// Empty when the prices could not be loaded, or when a tier is missing in
  /// Play Console: the screen must not offer a price it cannot show. Never
  /// throws.
  Future<Map<SupporterTier, SupporterPrice>> supporterPrices();

  /// Starts support at [tier]: Play's subscription sheet, or the donation page
  /// in the F-Droid build. Completes when the outcome is known. Never throws.
  Future<SupporterPurchaseResult> support(SupporterTier tier);

  /// Asks Play for this account's purchases, acknowledges a supporter
  /// subscription that was never acknowledged, and updates [isSupporter].
  ///
  /// Runs silently on app start and when Settings opens, and on demand from
  /// the Restore link. [SupporterRestoreResult.failed] for a donation. Never
  /// throws.
  Future<SupporterRestoreResult> restoreSupporter();

  /// Stops listening for purchases.
  ///
  /// The store listens for the whole life of the app, because a purchase can
  /// be confirmed after the screen that started it has closed. So no screen
  /// calls this; it is for tests. Safe to call more than once.
  void dispose();
}
