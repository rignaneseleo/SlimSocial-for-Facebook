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
  /// donation link instead of the coffee and pizza tiles.
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

  /// Drops anything the donation flow is still holding.
  ///
  /// Called from the settings screen's `dispose`. Safe to call more than once.
  void dispose();
}
