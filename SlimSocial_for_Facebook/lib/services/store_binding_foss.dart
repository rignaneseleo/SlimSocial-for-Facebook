import 'package:slimsocial_for_facebook/services/store_services.dart';
import 'package:slimsocial_for_facebook/services/store_services_foss.dart';

/// The F-Droid replacement for `store_binding.dart` — see that file.
///
/// It is not imported by anything: `scripts/fdroid_prepare.sh` copies it over
/// `store_binding.dart`. It is kept in the Play build so that a change to the
/// binding's shape breaks the analyzer here, in the same commit, rather than
/// on F-Droid's build server weeks later.
StoreServices createStoreServices() => const FossStoreServices();
