import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:slimsocial_for_facebook/consts.dart';
import 'package:slimsocial_for_facebook/services/store.dart';
import 'package:slimsocial_for_facebook/services/supporter.dart';
import 'package:slimsocial_for_facebook/widgets/supporter_heart.dart';

/// "Keep SlimSocial free and independent": pick a yearly price and support.
///
/// Nothing in the app is locked behind it. What it sells depends on the build
/// ([SupporterKind]): a Play subscription, or a one-time PayPal donation.
class SupporterPage extends StatefulWidget {
  const SupporterPage({super.key});

  @override
  State<SupporterPage> createState() => _SupporterPageState();
}

class _SupporterPageState extends State<SupporterPage> {
  SupporterTier _tier = SupporterTier.initial;

  /// Null while loading.
  Map<SupporterTier, SupporterPrice>? _prices =
      storeServices.knownSupporterPrices;
  bool _pricesFailed = false;
  bool _busy = false;
  bool _thanks = storeServices.isSupporter.value;

  SupporterKind get _kind => storeServices.supporterKind;

  @override
  void initState() {
    super.initState();
    if (_prices == null) unawaited(_loadPrices());
  }

  Future<void> _loadPrices() async {
    setState(() {
      _prices = null;
      _pricesFailed = false;
    });
    final prices = await storeServices.supporterPrices();
    if (!mounted) return;
    setState(() {
      _prices = prices.isEmpty ? null : prices;
      _pricesFailed = prices.isEmpty;
    });
  }

  Future<void> _support() async {
    if (_busy || _prices == null) return;
    setState(() => _busy = true);
    final result = await storeServices.support(_tier);
    if (!mounted) return;
    setState(() => _busy = false);

    switch (result) {
      case SupporterPurchaseResult.purchased:
        setState(() => _thanks = true);
      case SupporterPurchaseResult.pending:
        _snack('supporter_payment_pending'.tr());
      case SupporterPurchaseResult.error:
        _snack(
          _kind == SupporterKind.subscription
              ? 'supporter_payment_failed'.tr()
              : 'error_trylater'.tr(),
          retry: _support,
        );
      case SupporterPurchaseResult.cancelled:
      case SupporterPurchaseResult.openedExternally:
        break;
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await storeServices.restoreSupporter();
    if (!mounted) return;
    setState(() => _busy = false);

    switch (result) {
      case SupporterRestoreResult.found:
        setState(() => _thanks = true);
      case SupporterRestoreResult.notFound:
        _snack('supporter_restore_none'.tr());
      case SupporterRestoreResult.failed:
        _snack('supporter_restore_failed'.tr(), retry: _restore);
    }
  }

  void _snack(String message, {VoidCallback? retry}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          action:
              retry == null
                  ? null
                  : SnackBarAction(
                    label: 'retry'.tr(),
                    //the scheme's primary is too dark on the snackbar
                    textColor: SupporterPalette.of(context).snackAction,
                    onPressed: retry,
                  ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final palette = SupporterPalette.of(context);
    final still = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: palette.ground,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: still ? Duration.zero : const Duration(milliseconds: 300),
          child:
              _thanks
                  ? const SupporterThanks(key: ValueKey('thanks'))
                  : _offer(context, palette),
        ),
      ),
    );
  }

  Widget _offer(BuildContext context, SupporterPalette palette) {
    final subscription = _kind == SupporterKind.subscription;
    return LayoutBuilder(
      key: const ValueKey('offer'),
      builder:
          (context, constraints) => SingleChildScrollView(
            //scrolls only when it has to: large text on a small phone
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
                //two groups pushed apart: the story on top, the actions at the
                //bottom within thumb reach, whatever the phone's height
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          //lines the icon's glyph up with the title below it
                          child: Transform.translate(
                            offset: const Offset(-12, 0),
                            child: IconButton(
                              icon: const Icon(Icons.close),
                              color: palette.muted,
                              tooltip: 'supporter_close'.tr(),
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),
                          ),
                        ),
                        Semantics(
                          header: true,
                          child: Text(
                            'supporter_title'.tr(),
                            style: TextStyle(
                              fontSize: 24,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                              color: palette.ink,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: '${'supporter_story'.tr()} '),
                              TextSpan(
                                //never split from its dash
                                text: 'supporter_signature'.tr().replaceAll(
                                  ' ',
                                  '\u00A0',
                                ),
                                style: TextStyle(color: palette.muted),
                              ),
                            ],
                          ),
                          style: TextStyle(
                            fontSize: 14.5,
                            height: 1.45,
                            color: palette.ink,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _card(palette, subscription),
                        const SizedBox(height: 14),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _cta(palette, subscription),
                        if (subscription) ...[
                          TextButton(
                            onPressed: _busy ? null : _tip,
                            style: TextButton.styleFrom(
                              foregroundColor: palette.primary,
                              minimumSize: const Size(48, 48),
                              shape: const StadiumBorder(),
                            ),
                            child: Text(
                              'supporter_tip'.tr(),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            'supporter_renews'.tr(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.muted,
                            ),
                          ),
                        ] else
                          const SizedBox(height: 4),
                        _legal(palette, subscription),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Future<void> _tip() => storeServices.donate(kTipProductId);

  Widget _card(SupporterPalette palette, bool subscription) {
    final prices = _prices;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.card,
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
        child: Column(
          children: [
            Text(
              'supporter_pay_what_you_want'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                height: 1.1,
                fontWeight: FontWeight.w700,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              (subscription
                      ? 'supporter_cancel_any_time'
                      : 'supporter_one_time_donation')
                  .tr()
                  .toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 1,
                fontWeight: FontWeight.w700,
                color: palette.muted,
              ),
            ),
            SupporterHeart(tier: _tier),
            if (_pricesFailed)
              _PricesFailed(palette: palette, onRetry: _loadPrices)
            else ...[
              const SizedBox(height: 4),
              _PriceLine(
                prices: prices,
                tier: _tier,
                palette: palette,
                yearly: subscription,
              ),
              const SizedBox(height: 2),
              _Message(tier: _tier, palette: palette),
              SupporterSlider(
                tier: _tier,
                prices: prices,
                palette: palette,
                onChanged: (tier) => setState(() => _tier = tier),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cta(SupporterPalette palette, bool subscription) {
    final prices = _prices;
    final Widget label;
    if (_busy) {
      label = SizedBox.square(
        dimension: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: palette.onPrimary,
        ),
      );
    } else if (prices == null) {
      label = Text(
        _pricesFailed ? 'supporter_tile_title'.tr() : 'supporter_loading'.tr(),
      );
    } else {
      label = _CountingPrice(
        prices: prices,
        tier: _tier,
        builder:
            (price) => Text(
              (subscription ? 'supporter_cta' : 'supporter_cta_paypal').tr(
                args: [price],
              ),
              key: const ValueKey('supporter_cta_label'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
      );
    }

    return ElevatedButton(
      key: const ValueKey('supporter_cta'),
      onPressed: prices == null || _busy ? null : _support,
      style: ElevatedButton.styleFrom(
        backgroundColor: palette.primary,
        foregroundColor: palette.onPrimary,
        disabledBackgroundColor: palette.primary.withValues(alpha: 0.38),
        disabledForegroundColor: palette.onPrimary.withValues(alpha: 0.9),
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        elevation: 0,
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      child: label,
    );
  }

  Widget _legal(SupporterPalette palette, bool subscription) {
    final style = TextButton.styleFrom(
      foregroundColor: palette.primary,
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          style: style,
          onPressed: () => openExternally(Uri.parse(kPrivacyPolicyUrl)),
          child: Text('supporter_privacy'.tr()),
        ),
        if (subscription) ...[
          Text('·', style: TextStyle(fontSize: 12, color: palette.muted)),
          TextButton(
            key: const ValueKey('supporter_restore'),
            style: style,
            onPressed: _busy ? null : _restore,
            child: Text('supporter_restore'.tr()),
          ),
        ],
      ],
    );
  }
}

/// Shows the price for [tier], counting from the previous one when it changes.
class _CountingPrice extends StatefulWidget {
  const _CountingPrice({
    required this.prices,
    required this.tier,
    required this.builder,
  });

  final Map<SupporterTier, SupporterPrice> prices;
  final SupporterTier tier;
  final Widget Function(String price) builder;

  @override
  State<_CountingPrice> createState() => _CountingPriceState();
}

class _CountingPriceState extends State<_CountingPrice> {
  late SupporterTier _from = widget.tier;

  @override
  void didUpdateWidget(_CountingPrice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tier != widget.tier) _from = oldWidget.tier;
  }

  @override
  Widget build(BuildContext context) {
    final from = widget.prices[_from]!;
    final to = widget.prices[widget.tier]!;
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.builder(to.formatted);
    }
    return TweenAnimationBuilder<double>(
      //a new key restarts the count from the old price
      key: ValueKey('${_from.name}-${widget.tier.name}'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => widget.builder(countedPrice(from, to, t)),
    );
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({
    required this.prices,
    required this.tier,
    required this.palette,
    required this.yearly,
  });

  final Map<SupporterTier, SupporterPrice>? prices;

  /// False for a one-time donation, which has no "/ year".
  final bool yearly;
  final SupporterTier tier;
  final SupporterPalette palette;

  @override
  Widget build(BuildContext context) {
    final prices = this.prices;
    final amount =
        prices == null
            ? Container(
              key: const ValueKey('supporter_price_placeholder'),
              width: 104,
              height: 30,
              decoration: BoxDecoration(
                color: palette.line,
                borderRadius: BorderRadius.circular(8),
              ),
            )
            : _CountingPrice(
              prices: prices,
              tier: tier,
              builder:
                  (price) => Text(
                    price,
                    key: const ValueKey('supporter_price'),
                    style: TextStyle(
                      fontSize: 30,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: palette.primary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
            );

    //scales down rather than overflowing: a long local price at large text
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          amount,
          if (yearly) ...[
            const SizedBox(width: 5),
            Text(
              'supporter_per_year'.tr(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: palette.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.tier, required this.palette});

  final SupporterTier tier;
  final SupporterPalette palette;

  static const Map<SupporterTier, String> _keys = {
    SupporterTier.small: 'supporter_msg_small',
    SupporterTier.medium: 'supporter_msg_medium',
    SupporterTier.large: 'supporter_msg_large',
  };

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      liveRegion: true,
      child: AnimatedSwitcher(
        duration: still ? Duration.zero : const Duration(milliseconds: 200),
        transitionBuilder:
            (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.2),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
        child: Text(
          _keys[tier]!.tr(),
          key: ValueKey(tier),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, height: 1.4, color: palette.muted),
        ),
      ),
    );
  }
}

/// The three-step slider with a tappable price under each step.
class SupporterSlider extends StatelessWidget {
  const SupporterSlider({
    required this.tier,
    required this.prices,
    required this.palette,
    required this.onChanged,
    super.key,
  });

  final SupporterTier tier;
  final Map<SupporterTier, SupporterPrice>? prices;
  final SupporterPalette palette;
  final ValueChanged<SupporterTier> onChanged;

  @override
  Widget build(BuildContext context) {
    final prices = this.prices;
    final enabled = prices != null;
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 8,
            activeTrackColor: palette.primary,
            inactiveTrackColor: palette.track,
            disabledActiveTrackColor: palette.track,
            disabledInactiveTrackColor: palette.track,
            thumbColor: palette.primary,
            overlayColor: palette.primary.withValues(alpha: 0.12),
            activeTickMarkColor: Colors.transparent,
            inactiveTickMarkColor: Colors.transparent,
            disabledActiveTickMarkColor: Colors.transparent,
            disabledInactiveTickMarkColor: Colors.transparent,
            trackShape: const RoundedRectSliderTrackShape(),
            thumbShape: _RingThumb(fill: palette.card, ring: palette.primary),
            overlayShape: const RoundSliderOverlayShape(),
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: Slider(
            key: const ValueKey('supporter_slider'),
            value: tier.index.toDouble(),
            max: (SupporterTier.values.length - 1).toDouble(),
            divisions: SupporterTier.values.length - 1,
            semanticFormatterCallback: (value) {
              final price = prices?[SupporterTier.values[value.round()]];
              return price == null
                  ? ''
                  : 'supporter_price_per_year'.tr(args: [price.formatted]);
            },
            onChanged:
                enabled
                    ? (value) {
                      final next = SupporterTier.values[value.round()];
                      if (next != tier) onChanged(next);
                    }
                    : null,
          ),
        ),
        Transform.translate(
          //the labels sit tight under the track; their 48dp targets overlap
          //the slider's empty lower margin, not the thumb
          offset: const Offset(0, -12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              //each label centred under its stop. The track is inset by the
              //thumb overlay's radius, as the slider lays it out
              const inset = 24.0;
              final width = constraints.maxWidth;
              final gap =
                  (width - 2 * inset) / (SupporterTier.values.length - 1);
              final labelWidth = gap.clamp(48.0, 88.0);
              final rtl = Directionality.of(context) == TextDirection.rtl;
              return SizedBox(
                height: 48,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final step in SupporterTier.values)
                      Positioned(
                        left:
                            (rtl
                                ? width - inset - step.index * gap
                                : inset + step.index * gap) -
                            labelWidth / 2,
                        width: labelWidth,
                        top: 0,
                        bottom: 0,
                        child: _StepLabel(
                          key: ValueKey('supporter_step_${step.name}'),
                          price: prices?[step]?.formatted,
                          selected: step == tier,
                          palette: palette,
                          onTap: enabled ? () => onChanged(step) : null,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StepLabel extends StatelessWidget {
  const _StepLabel({
    required this.price,
    required this.selected,
    required this.palette,
    required this.onTap,
    super.key,
  });

  final String? price;
  final bool selected;
  final SupporterPalette palette;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final price = this.price;
    return Semantics(
      button: true,
      selected: selected,
      label:
          price == null ? null : 'supporter_price_per_year'.tr(args: [price]),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Center(
              child:
                  price == null
                      ? Container(
                        width: 36,
                        height: 12,
                        decoration: BoxDecoration(
                          color: palette.line,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      )
                      : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: AnimatedScale(
                          scale: selected ? 1.15 : 1,
                          duration:
                              still
                                  ? Duration.zero
                                  : const Duration(milliseconds: 200),
                          child: Text(
                            price,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected ? palette.primary : palette.muted,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PricesFailed extends StatelessWidget {
  const _PricesFailed({required this.palette, required this.onRetry});

  final SupporterPalette palette;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Column(
        children: [
          Text(
            'supporter_prices_failed'.tr(),
            key: const ValueKey('supporter_prices_failed'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, height: 1.4, color: palette.ink),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: palette.primary,
              minimumSize: const Size(48, 48),
            ),
            child: Text('retry'.tr()),
          ),
        ],
      ),
    );
  }
}

/// A slider thumb: a filled circle with a ring, like the design.
class _RingThumb extends SliderComponentShape {
  const _RingThumb({required this.fill, required this.ring});

  final Color fill;
  final Color ring;

  static const double _radius = 14;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(_radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final radius = _radius * (1 + 0.12 * activationAnimation.value);
    canvas
      ..drawCircle(
        center + const Offset(0, 2),
        radius,
        Paint()
          ..color = const Color(0x40142A5A)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      )
      ..drawCircle(center, radius, Paint()..color = fill)
      ..drawCircle(
        center,
        radius - 1.5,
        Paint()
          ..color =
              enableAnimation.value > 0.5 ? ring : ring.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
  }
}

/// Shown after a purchase or a restore, and when a supporter opens the screen.
class SupporterThanks extends StatefulWidget {
  const SupporterThanks({super.key});

  @override
  State<SupporterThanks> createState() => _SupporterThanksState();
}

class _SupporterThanksState extends State<SupporterThanks>
    with SingleTickerProviderStateMixin {
  late final AnimationController _beat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  static final Animatable<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 1.15,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 20,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.15,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 20,
    ),
    TweenSequenceItem(tween: ConstantTween<double>(1), weight: 60),
  ]);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MediaQuery.disableAnimationsOf(context) && !_beat.isAnimating) {
      _beat.repeat(count: 2);
    }
  }

  @override
  void dispose() {
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = SupporterPalette.of(context);
    return LayoutBuilder(
      builder:
          (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        color: palette.warmGround,
                        shape: BoxShape.circle,
                      ),
                      child: ScaleTransition(
                        scale: _scale.animate(_beat),
                        child: Icon(
                          Icons.favorite,
                          size: 46,
                          color: palette.warm,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Semantics(
                      header: true,
                      child: Text(
                        'supporter_thanks_title'.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          color: palette.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'supporter_thanks_body'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.45,
                        color: palette.muted,
                      ),
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.primary,
                        foregroundColor: palette.onPrimary,
                        minimumSize: const Size.fromHeight(52),
                        shape: const StadiumBorder(),
                        elevation: 0,
                        textStyle: Theme.of(
                          context,
                        ).textTheme.labelLarge?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      child: Text('supporter_back'.tr()),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed:
                          () => openExternally(Uri.parse(kSupporterManageUrl)),
                      style: TextButton.styleFrom(
                        foregroundColor: palette.muted,
                        minimumSize: const Size(48, 48),
                        textStyle: Theme.of(
                          context,
                        ).textTheme.labelLarge?.copyWith(fontSize: 12),
                      ),
                      child: Text(
                        'supporter_manage_hint'.tr(),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}
