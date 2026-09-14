import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:slimsocial_for_facebook/screens/supporter_page.dart';
import 'package:slimsocial_for_facebook/services/store.dart';
import 'package:slimsocial_for_facebook/services/supporter.dart';
import 'package:slimsocial_for_facebook/widgets/supporter_heart.dart';

/// The highlighted tile at the top of Settings.
///
/// "Become a supporter" opens [SupporterPage]. Once Play reports an active
/// subscription it thanks the user and opens Play's page to manage it.
class SupporterTile extends StatelessWidget {
  const SupporterTile({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = SupporterPalette.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: storeServices.isSupporter,
      builder: (context, supporter, _) {
        final title =
            supporter
                ? 'supporter_tile_thanks'.tr()
                : 'supporter_tile_title'.tr();
        final subtitle =
            supporter
                ? 'supporter_tile_manage'.tr()
                : 'supporter_tile_subtitle'.tr();

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Material(
            color: palette.container,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const ValueKey('supporter_tile'),
              onTap: () {
                if (supporter) {
                  openExternally(Uri.parse(kSupporterManageUrl));
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SupporterPage(),
                    ),
                  );
                }
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        supporter ? Icons.favorite : Icons.volunteer_activism,
                        color: palette.onContainer,
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: palette.onContainer,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 13,
                                color: palette.onContainer.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        supporter ? Icons.open_in_new : Icons.chevron_right,
                        size: 20,
                        color: palette.onContainer.withValues(alpha: 0.8),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
