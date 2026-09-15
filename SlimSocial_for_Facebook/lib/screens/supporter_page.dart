import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:slimsocial_for_facebook/consts.dart';
import 'package:slimsocial_for_facebook/services/store.dart';
import 'package:slimsocial_for_facebook/services/supporter.dart';
import 'package:slimsocial_for_facebook/widgets/supporter_heart.dart';

/// "Keep SlimSocial free and independent": pick a yearly price and support.
///
/// Nothing in the app is locked behind it. What it offers depends on the build
/// ([SupporterKind]): a Play subscription, a pointer to the Play listing for a
/// Play apk that did not come from Play, or a one-time donation on F-Droid.
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
    //a purchase can land after support() gave up waiting (a slow payment
    //sheet, a pending payment clearing): thank the user when it does
    storeServices.isSupporter.addListener(_onSupporterChanged);
    if (_prices == null && _kind == SupporterKind.subscription) {
      unawaited(_loadPrices());
    }
  }

  @override
  void dispose() {
    storeServices.isSupporter.removeListener(_onSupporterChanged);
    super.dispose();
  }

  void _onSupporterChanged() {
    if (storeServices.isSupporter.value && !_thanks && mounted) {
      setState(() => _thanks = true);
    }
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
    return CustomScrollView(
      key: const ValueKey('offer'),
      slivers: [
        //fills the screen when the content is shorter; the two spacers take
        //the spare height and collapse to nothing when it is taller, and the
        //page then scrolls (large text on a small phone)
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  //lines the icon's glyph up with the headline below
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
                _StoryHeader(palette: palette),
                const SizedBox(height: 16),
                const Spacer(),
                _card(palette, subscription),
                const SizedBox(height: 24),
                const Spacer(flex: 2),
                _cta(palette, _kind),
                const SizedBox(height: 4),
                if (subscription) ...[
                  TextButton(
                    onPressed: _busy ? null : _tip,
                    style: TextButton.styleFrom(
                      foregroundColor: palette.primary,
                      minimumSize: const Size(48, 48),
                      shape: const StadiumBorder(),
                      textStyle: SupporterType.forButton(
                        context,
                        SupporterType.tip,
                      ),
                    ),
                    child: Text('supporter_tip'.tr()),
                  ),
                  Text(
                    'supporter_renews'.tr(),
                    textAlign: TextAlign.center,
                    style: SupporterType.small.copyWith(
                      fontWeight: FontWeight.w400,
                      color: palette.muted,
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -6),
                    child: _legal(palette, subscription),
                  ),
                ] else
                  _legal(palette, subscription),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _tip() => storeServices.donate(kTipProductId);

  Widget _card(SupporterPalette palette, bool subscription) {
    final prices = _prices;
    final installFromPlay = _kind == SupporterKind.installFromPlay;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Column(
          children: [
            Text(
              'supporter_pay_what_you_want'.tr(),
              textAlign: TextAlign.center,
              style: SupporterType.title.copyWith(color: palette.ink),
            ),
            const SizedBox(height: 4),
            Text(
              (_kind == SupporterKind.donation
                      ? 'supporter_one_time_donation'
                      : 'supporter_cancel_any_time')
                  .tr()
                  .toUpperCase(),
              textAlign: TextAlign.center,
              style: SupporterType.caption.copyWith(color: palette.muted),
            ),
            const SizedBox(height: 12),
            _HeartDisc(tier: _tier),
            if (installFromPlay) ...[
              const SizedBox(height: 8),
              _InstallFromPlay(
                palette: palette,
                onOpen: () => storeServices.support(_tier),
              ),
              SupporterSlider(
                tier: _tier,
                prices: null,
                palette: palette,
                onChanged: (_) {},
              ),
            ] else if (_pricesFailed) ...[
              const SizedBox(height: 8),
              _PricesFailed(palette: palette, onRetry: _loadPrices),
            ] else ...[
              const SizedBox(height: 8),
              _PriceLine(
                prices: prices,
                tier: _tier,
                palette: palette,
                yearly: subscription,
              ),
              const SizedBox(height: 4),
              _Message(tier: _tier, palette: palette),
              const SizedBox(height: 4),
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

  Widget _cta(SupporterPalette palette, SupporterKind kind) {
    final subscription = kind == SupporterKind.subscription;
    final prices = kind == SupporterKind.installFromPlay ? null : _prices;
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
        _pricesFailed || kind == SupporterKind.installFromPlay
            ? 'supporter_tile_title'.tr()
            : 'supporter_loading'.tr(),
      );
    } else {
      label = _CountingPrice(
        prices: prices,
        tier: _tier,
        builder:
            (price) => Text(
              (subscription ? 'supporter_cta' : 'supporter_cta_donate').tr(
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

    return SupporterPrimaryButton(
      key: const ValueKey('supporter_cta'),
      palette: palette,
      onPressed: prices == null || _busy ? null : _support,
      child: label,
    );
  }

  Widget _legal(SupporterPalette palette, bool subscription) {
    final style = TextButton.styleFrom(
      foregroundColor: palette.muted,
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      textStyle: SupporterType.forButton(context, SupporterType.small),
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
          Text('·', style: SupporterType.small.copyWith(color: palette.muted)),
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

/// The supporter screen's type scale: four sizes (26, 16, 14 and 15 for the
/// body, 12), each with its weight and line height.
abstract final class SupporterType {
  static const TextStyle display = TextStyle(
    fontSize: 26,
    height: 1.10,
    letterSpacing: -0.5,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle title = TextStyle(
    fontSize: 16,
    height: 1.2,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle body = TextStyle(fontSize: 15, height: 1.40);

  static const TextStyle support = TextStyle(fontSize: 14, height: 1.40);

  static const TextStyle tip = TextStyle(
    fontSize: 14,
    height: 1.40,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    height: 1.2,
    letterSpacing: 1.2,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle small = TextStyle(
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w500,
  );

  /// [style] for a button label. A button's text style replaces the inherited
  /// one instead of merging with it, so the theme's font has to be put back.
  static TextStyle forButton(BuildContext context, TextStyle style) =>
      Theme.of(context).textTheme.bodyMedium!.merge(style);
}

/// The full-width filled button of the supporter screens.
class SupporterPrimaryButton extends StatelessWidget {
  const SupporterPrimaryButton({
    required this.palette,
    required this.onPressed,
    required this.child,
    super.key,
  });

  final SupporterPalette palette;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: palette.primary,
        foregroundColor: palette.onPrimary,
        disabledBackgroundColor: palette.primary.withValues(alpha: 0.38),
        disabledForegroundColor: palette.onPrimary.withValues(alpha: 0.9),
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        elevation: 0,
        textStyle: SupporterType.forButton(context, SupporterType.title),
      ),
      child: child,
    );
  }
}

/// The hand and heart, with the disc drawn 88dp wide (96 did not leave room
/// for the Russian and Italian headline on a 390x844 phone).
///
/// The art is 120x128 with its disc at the bottom; the 8 units above the disc
/// are room for the heart to rise into. Laid out as a square as wide as the
/// disc, with that headroom drawn over the gap above it.
class _HeartDisc extends StatelessWidget {
  const _HeartDisc({required this.tier});

  final SupporterTier tier;

  static const double disc = 88;

  @override
  Widget build(BuildContext context) {
    final scale = disc / SupporterHeart.size.width;
    final art = SupporterHeart.size * scale;
    return SizedBox(
      width: disc,
      height: disc,
      child: OverflowBox(
        alignment: Alignment.bottomCenter,
        minWidth: art.width,
        maxWidth: art.width,
        minHeight: art.height,
        maxHeight: art.height,
        child: FittedBox(child: SupporterHeart(tier: tier)),
      ),
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
    if (prices == null) {
      return Container(
        key: const ValueKey('supporter_price_placeholder'),
        width: 104,
        height: 28,
        decoration: BoxDecoration(
          color: palette.line,
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }

    //scales down rather than overflowing: a long local price at large text
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          _CountingPrice(
            prices: prices,
            tier: tier,
            builder:
                (price) => Text(
                  price,
                  key: const ValueKey('supporter_price'),
                  style: SupporterType.display.copyWith(
                    color: palette.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
          ),
          if (yearly) ...[
            const SizedBox(width: 4),
            Text(
              'supporter_per_year'.tr(),
              style: SupporterType.small.copyWith(color: palette.muted),
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
          style: SupporterType.support.copyWith(color: palette.muted),
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

  /// The whole amount when it has no cents ("25"), else Play's string.
  static String tickText(SupporterPrice price) =>
      price.raw == price.raw.roundToDouble()
          ? price.raw.toInt().toString()
          : price.formatted;

  @override
  Widget build(BuildContext context) {
    final prices = this.prices;
    final enabled = prices != null;
    final inactiveDot = palette.ink.withValues(alpha: 0.3);
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6,
            activeTrackColor: palette.primary,
            inactiveTrackColor: palette.track,
            disabledActiveTrackColor: palette.track,
            disabledInactiveTrackColor: palette.track,
            thumbColor: palette.primary,
            overlayColor: palette.primary.withValues(alpha: 0.12),
            tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 2),
            activeTickMarkColor: palette.onPrimary.withValues(alpha: 0.5),
            inactiveTickMarkColor: inactiveDot,
            disabledActiveTickMarkColor: inactiveDot,
            disabledInactiveTickMarkColor: inactiveDot,
            trackShape: const _EvenTrack(),
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
        _LiftedLabels(
          textDirection: Directionality.of(context),
          children: [
            for (final step in SupporterTier.values)
              LayoutId(
                id: step,
                child: _StepLabel(
                  key: ValueKey('supporter_step_${step.name}'),
                  price: prices?[step],
                  selected: step == tier,
                  palette: palette,
                  onTap: enabled ? () => onChanged(step) : null,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// The price labels: each a 48dp target centred under its stop, lifted 16dp
/// into the slider's empty lower margin, so the row takes 32dp of height.
class _LiftedLabels extends CustomMultiChildLayout {
  _LiftedLabels({required TextDirection textDirection, required super.children})
    : super(delegate: _LabelsDelegate(textDirection));

  @override
  RenderCustomMultiChildLayoutBox createRenderObject(BuildContext context) =>
      _RenderLiftedLabels(delegate: delegate);
}

class _RenderLiftedLabels extends RenderCustomMultiChildLayoutBox {
  _RenderLiftedLabels({required super.delegate});

  //the lifted part of each target lies above this box; hit-test the children
  //directly so a tap there still lands
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (hitTestChildren(result, position: position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }
}

class _LabelsDelegate extends MultiChildLayoutDelegate {
  _LabelsDelegate(this.textDirection);

  final TextDirection textDirection;

  static const double _target = 48;
  static const double _lift = 16;

  //the slider insets its track by the overlay radius
  static const double _inset = 24;

  @override
  Size getSize(BoxConstraints constraints) => constraints.constrain(
    Size(
      constraints.maxWidth.isFinite ? constraints.maxWidth : 0,
      _target - _lift,
    ),
  );

  @override
  void performLayout(Size size) {
    final gap = (size.width - 2 * _inset) / (SupporterTier.values.length - 1);
    final width = gap.clamp(_target, 88.0);
    final rtl = textDirection == TextDirection.rtl;
    for (final step in SupporterTier.values) {
      layoutChild(step, BoxConstraints.tightFor(width: width, height: _target));
      final centre =
          rtl
              ? size.width - _inset - step.index * gap
              : _inset + step.index * gap;
      positionChild(step, Offset(centre - width / 2, -_lift));
    }
  }

  @override
  bool shouldRelayout(_LabelsDelegate oldDelegate) =>
      oldDelegate.textDirection != textDirection;
}

class _StepLabel extends StatelessWidget {
  const _StepLabel({
    required this.price,
    required this.selected,
    required this.palette,
    required this.onTap,
    super.key,
  });

  final SupporterPrice? price;
  final bool selected;
  final SupporterPalette palette;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final price = this.price;
    return Semantics(
      button: true,
      selected: selected,
      label:
          price == null
              ? null
              : 'supporter_price_per_year'.tr(args: [price.formatted]),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Center(
          child:
              price == null
                  ? Container(
                    width: 24,
                    height: 12,
                    decoration: BoxDecoration(
                      color: palette.line,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )
                  : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      SupporterSlider.tickText(price),
                      style: SupporterType.small.copyWith(
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? palette.ink : palette.muted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
        ),
      ),
    );
  }
}

/// The top of the screen: the developer's story as the headline, then who
/// wrote it.
class _StoryHeader extends StatelessWidget {
  const _StoryHeader({required this.palette});

  final SupporterPalette palette;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        //both lines are one heading for a screen reader
        MergeSemantics(
          child: Semantics(
            header: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'supporter_headline'.tr(),
                  key: const ValueKey('supporter_headline'),
                  style: SupporterType.display.copyWith(color: palette.ink),
                ),
                Text(
                  'supporter_headline_accent'.tr(),
                  style: SupporterType.display.copyWith(color: palette.accent),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'supporter_body'.tr(),
          style: SupporterType.body.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 24,
          child: Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palette.container,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    'L',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: palette.onContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'supporter_signed'.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SupporterType.support.copyWith(color: palette.muted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// In a Play apk that did not come from Play: why nothing can be bought, and
/// the way to fix it.
class _InstallFromPlay extends StatelessWidget {
  const _InstallFromPlay({required this.palette, required this.onOpen});

  final SupporterPalette palette;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'supporter_install_from_play'.tr(),
          key: const ValueKey('supporter_install_from_play'),
          textAlign: TextAlign.center,
          style: SupporterType.support.copyWith(color: palette.ink),
        ),
        TextButton(
          key: const ValueKey('supporter_open_play'),
          onPressed: onOpen,
          style: TextButton.styleFrom(
            foregroundColor: palette.primary,
            minimumSize: const Size(48, 48),
            textStyle: SupporterType.forButton(context, SupporterType.tip),
          ),
          child: Text('supporter_open_play'.tr()),
        ),
      ],
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Text(
            'supporter_prices_failed'.tr(),
            key: const ValueKey('supporter_prices_failed'),
            textAlign: TextAlign.center,
            style: SupporterType.support.copyWith(color: palette.ink),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: palette.primary,
              minimumSize: const Size(48, 48),
              textStyle: SupporterType.forButton(context, SupporterType.tip),
            ),
            child: Text('retry'.tr()),
          ),
        ],
      ),
    );
  }
}

/// The rounded track with the active part as tall as the inactive one.
class _EvenTrack extends RoundedRectSliderTrackShape {
  const _EvenTrack();

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    super.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      textDirection: textDirection,
      thumbCenter: thumbCenter,
      secondaryOffset: secondaryOffset,
      isDiscrete: isDiscrete,
      isEnabled: isEnabled,
      additionalActiveTrackHeight: 0,
    );
  }
}

/// A slider thumb: a filled circle with a 3dp ring and no shadow.
class _RingThumb extends SliderComponentShape {
  const _RingThumb({required this.fill, required this.ring});

  final Color fill;
  final Color ring;

  static const double _radius = 14;
  static const double _ring = 3;

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
    final radius = _radius * (1 + 0.12 * activationAnimation.value);
    context.canvas
      ..drawCircle(center, radius, Paint()..color = fill)
      ..drawCircle(
        center,
        radius - _ring / 2,
        Paint()
          ..color =
              enableAnimation.value > 0.5 ? ring : ring.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _ring,
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
    final scheme = Theme.of(context).colorScheme;
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: palette.warmGround,
                    shape: BoxShape.circle,
                  ),
                  child: ScaleTransition(
                    scale: _scale.animate(_beat),
                    child: Icon(Icons.favorite, size: 48, color: palette.warm),
                  ),
                ),
                const SizedBox(height: 24),
                Semantics(
                  header: true,
                  child: Text(
                    'supporter_thanks_title'.tr(),
                    textAlign: TextAlign.center,
                    style: SupporterType.display.copyWith(color: palette.ink),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'supporter_thanks_body'.tr(),
                  textAlign: TextAlign.center,
                  style: SupporterType.body.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                SupporterPrimaryButton(
                  palette: palette,
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text('supporter_back'.tr()),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed:
                      () => openExternally(Uri.parse(kSupporterManageUrl)),
                  style: TextButton.styleFrom(
                    foregroundColor: palette.muted,
                    minimumSize: const Size(48, 48),
                    textStyle: SupporterType.forButton(
                      context,
                      SupporterType.small.copyWith(fontWeight: FontWeight.w400),
                    ),
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
      ],
    );
  }
}
