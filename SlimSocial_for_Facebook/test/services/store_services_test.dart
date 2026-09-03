import 'package:flutter_test/flutter_test.dart';
import 'package:slimsocial_for_facebook/consts.dart';
import 'package:slimsocial_for_facebook/services/store_binding_foss.dart'
    as foss;
import 'package:slimsocial_for_facebook/services/store_services.dart';
import 'package:slimsocial_for_facebook/services/store_services_foss.dart';

void main() {
  group('FossStoreServices', () {
    const store = FossStoreServices();

    test('offers neither billing nor a rating sheet', () {
      expect(store.canPurchase, isFalse);
      expect(store.canRequestReview, isFalse);
    });

    test('points at F-Droid, not Play', () {
      //sharing a Play link out of an F-Droid build sends people to a listing
      //that will never update the copy they installed
      expect(store.appListingUrl, kFDroidStoreUrl);
      expect(store.appListingUrl, isNot(kPlayStoreUrl));
    });

    test('its no-ops complete rather than throw', () async {
      //the screens gate on the two flags above, so these bodies only run if a
      //caller forgets — and a tile that does nothing beats a crash
      await expectLater(store.requestReview(), completes);
      await expectLater(store.donate('donation_2'), completes);
      expect(store.dispose, returnsNormally);
    });
  });

  group('the F-Droid binding', () {
    test('builds a store with no proprietary calls behind it', () {
      final store = foss.createStoreServices();
      expect(store, isA<StoreServices>());
      expect(store, isA<FossStoreServices>());
      expect(store.canPurchase, isFalse);
      expect(store.canRequestReview, isFalse);
    });
  });
}
