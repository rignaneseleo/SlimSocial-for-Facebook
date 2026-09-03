import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The pub packages F-Droid will not ship, because they are proprietary:
/// `in_app_purchase` is Google Play Billing and `in_app_review` is Play Core.
///
/// Keep this list in step with `PROPRIETARY_PACKAGES` in
/// `scripts/fdroid_prepare.sh`. The test below asserts the script names the
/// same set, so the two cannot drift apart unnoticed.
const List<String> kProprietaryPackages = ['in_app_purchase', 'in_app_review'];

/// The single file allowed to import them. The script deletes it.
const String kPlayImplPath = 'lib/services/store_services_play.dart';

/// The file the script replaces, and what it replaces it with.
const String kBindingPath = 'lib/services/store_binding.dart';
const String kBindingFossPath = 'lib/services/store_binding_foss.dart';

const String kScriptPath = 'scripts/fdroid_prepare.sh';

List<File> _dartFilesUnder(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

void main() {
  group('the F-Droid build is still possible', () {
    test('only the Play implementation imports a proprietary package', () {
      final offenders = <String>[];

      for (final file in _dartFilesUnder('lib')) {
        if (file.path == kPlayImplPath) continue;
        final source = file.readAsStringSync();
        for (final package in kProprietaryPackages) {
          if (source.contains('package:$package/')) {
            offenders.add('${file.path} imports $package');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'F-Droid builds by deleting $kPlayImplPath, so a proprietary '
            'import anywhere else stops the app compiling there. Put the call '
            'behind StoreServices instead.\n${offenders.join('\n')}',
      );
    });

    test('the Play implementation is the file the script deletes', () {
      //the guard above is only worth anything while the exemption it grants
      //matches the file the script actually removes
      expect(File(kPlayImplPath).existsSync(), isTrue);
      expect(
        File(kScriptPath).readAsStringSync(),
        contains(kPlayImplPath),
        reason: '$kScriptPath must delete $kPlayImplPath',
      );
    });

    test('the script and this test name the same packages', () {
      final script = File(kScriptPath).readAsStringSync();
      for (final package in kProprietaryPackages) {
        expect(
          script,
          contains(package),
          reason: '$package is guarded here but not stripped by $kScriptPath',
        );
      }
    });

    test('the F-Droid binding exists and pulls in no proprietary code', () {
      final foss = File(kBindingFossPath);
      expect(foss.existsSync(), isTrue);

      final source = foss.readAsStringSync();
      expect(
        source.contains('store_services_play.dart'),
        isFalse,
        reason: '$kBindingFossPath must not reach the Play implementation: '
            'the script deletes it',
      );
      expect(
        File(kBindingPath).existsSync(),
        isTrue,
        reason: 'the script copies $kBindingFossPath over $kBindingPath',
      );
    });

    test('both bindings expose the same entry point', () {
      //they are swapped for each other, so a rename in one and not the other
      //breaks only the build that is not being run here
      const entryPoint = 'StoreServices createStoreServices()';
      expect(File(kBindingPath).readAsStringSync(), contains(entryPoint));
      expect(File(kBindingFossPath).readAsStringSync(), contains(entryPoint));
    });
  });
}
