import 'package:slimsocial_for_facebook/consts.dart';
import 'package:slimsocial_for_facebook/services/store_services.dart';

/// The build with no proprietary store behind it — F-Droid, or any apk built
/// straight from source.
///
/// Every method is a no-op rather than a throw. The screens ask [canPurchase]
/// and [canRequestReview] first and offer something else instead, so these
/// bodies only ever run if a caller forgets; a donation tile that quietly does
/// nothing is a smaller failure than a crash.
///
/// This file imports nothing but the interface, and stays in the Play build
/// too — it is the F-Droid *binding* that is swapped in, not this class.
class FossStoreServices implements StoreServices {
  const FossStoreServices();

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

  @override
  void dispose() {}
}
