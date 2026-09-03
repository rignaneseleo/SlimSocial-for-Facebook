import 'package:flutter/foundation.dart';
import 'package:slimsocial_for_facebook/services/store_binding.dart';
import 'package:slimsocial_for_facebook/services/store_services.dart';

StoreServices? _instance;

/// The store this build talks to.
///
/// Built on first use from `store_binding.dart`, which is the file the F-Droid
/// build replaces. Screens import this, never an implementation.
StoreServices get storeServices => _instance ??= createStoreServices();

/// Puts a stand-in in place of the real store for one test.
@visibleForTesting
void setStoreServicesForTest(StoreServices value) => _instance = value;

/// Undoes [setStoreServicesForTest]. Call it in `tearDown`: the instance is a
/// top-level global, so a leftover stand-in would follow into the next test.
@visibleForTesting
void resetStoreServicesForTest() => _instance = null;
