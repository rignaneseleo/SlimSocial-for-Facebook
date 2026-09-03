import 'package:slimsocial_for_facebook/services/store_services.dart';
import 'package:slimsocial_for_facebook/services/store_services_play.dart';

/// The one file that decides which store this build talks to.
///
/// It is deliberately tiny and does nothing else, because it is *replaced*
/// wholesale: `scripts/fdroid_prepare.sh` copies `store_binding_foss.dart`
/// over it and deletes `store_services_play.dart`. Keep the two bindings
/// identical apart from the implementation they name, and put no logic here
/// that the F-Droid build would then lose.
StoreServices createStoreServices() => PlayStoreServices();
