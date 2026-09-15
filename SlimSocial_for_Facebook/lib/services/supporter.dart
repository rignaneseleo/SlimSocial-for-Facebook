/// The yearly "supporter" subscription, in the app's own words.
///
/// Nothing here names a store SDK type: the screens use these, and the Play
/// implementation translates them to Play Billing. That keeps the F-Droid
/// build (which has no billing) compiling — see `store_services.dart`.
library;

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// The Play subscription product. One product, one base plan per price.
const String kSupporterProductId = 'supporter';

/// The existing one-time consumable offered as a tip under the subscription.
const String kTipProductId = 'donation_1';

/// Where a supporter manages or cancels. Play's own subscriptions page, deep
/// linked to this product.
const String kSupporterManageUrl =
    'https://play.google.com/store/account/subscriptions'
    '?sku=$kSupporterProductId&package=it.rignanese.leo.slimfacebook';

/// The three prices on the slider, in slider order.
///
/// [basePlanId] must match the base plan ids in Play Console exactly.
/// [nominalEuros] is only a fallback for ordering and tests: the price shown
/// to the user always comes from Play, in the user's own currency.
enum SupporterTier {
  small('yearly-10', 10),
  medium('yearly-25', 25),
  large('yearly-50', 50);

  const SupporterTier(this.basePlanId, this.nominalEuros);

  final String basePlanId;
  final int nominalEuros;

  /// The step the screen opens on.
  static const SupporterTier initial = SupporterTier.medium;

  static SupporterTier? fromBasePlanId(String id) {
    for (final tier in values) {
      if (tier.basePlanId == id) return tier;
    }
    return null;
  }
}

/// One base plan's price as Play reports it.
class SupporterPrice {
  const SupporterPrice({required this.formatted, required this.raw});

  /// Play's own localized string, e.g. "€25.00" or "25,00 €".
  final String formatted;

  /// The same amount as a number, used only to count between two prices.
  final double raw;
}

/// What the supporter screen offers.
enum SupporterKind {
  /// A yearly Play subscription, with restore and a thank-you state.
  subscription,

  /// The Play build, installed some other way than by the Play Store (for
  /// example a copied apk). Play billing does not work there (SLIMSOCIAL-5),
  /// so the screen points to the Play listing.
  installFromPlay,

  /// A one-time donation outside any store, at a fixed euro amount. F-Droid
  /// only. No state afterwards.
  donation,
}

/// Opens [uri] in another app, such as the browser or Google Play. False when
/// nothing could open it. Never throws.
Future<bool> openExternally(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Object catch (e) {
    debugPrint('Could not open $uri: $e');
    return false;
  }
}

/// How a purchase attempt ended, as far as the screen needs to know.
enum SupporterPurchaseResult {
  /// Paid and acknowledged. The supporter flag is already set.
  purchased,

  /// Google has not confirmed the payment yet (for example cash at a shop).
  pending,

  /// The user closed the Play sheet. Nothing to say.
  cancelled,

  /// Anything else. The user was not charged.
  error,

  /// Handed off to an outside page. The app cannot know the outcome.
  openedExternally,
}

/// What a restore found.
enum SupporterRestoreResult {
  /// An active supporter subscription exists on this Google account.
  found,

  /// Play answered, and there is no active subscription.
  notFound,

  /// Play could not be asked.
  failed,
}

/// Replaces the number inside [to]'s formatted price with a value between
/// [from] and [to], so the price can count up or down.
///
/// Play formats prices per locale ("€25.00", "25,00 €", "US$25.00"), so the
/// number is swapped into Play's own string instead of being re-formatted. At
/// the ends of the count the string is exactly Play's.
String countedPrice(SupporterPrice from, SupporterPrice to, double t) {
  if (t >= 1) return to.formatted;
  if (t <= 0) return from.formatted;
  final match = RegExp(r'\d[\d.,\s  ]*\d|\d').firstMatch(to.formatted);
  if (match == null) return to.formatted;

  final value = (from.raw + (to.raw - from.raw) * t).round();
  final number = match.group(0)!;
  //keep Play's decimals, as zeros, so the width does not jump mid-count
  final decimals = RegExp(r'([.,])(\d{1,2})$').firstMatch(number);
  final text =
      decimals == null
          ? '$value'
          : '$value${decimals.group(1)}${'0' * decimals.group(2)!.length}';
  return to.formatted.replaceRange(match.start, match.end, text);
}
