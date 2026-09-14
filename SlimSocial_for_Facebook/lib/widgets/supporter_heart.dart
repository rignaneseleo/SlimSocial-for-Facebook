import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:slimsocial_for_facebook/services/supporter.dart';

/// The colours of the supporter screen and its Settings tile.
///
/// Derived from the app's colour scheme, with two corrections for dark mode:
/// the dark scheme's primary container is near black, so a disc or a tile in
/// it would vanish into the background. Those use a mid blue instead.
@immutable
class SupporterPalette {
  const SupporterPalette._({
    required this.ground,
    required this.card,
    required this.line,
    required this.ink,
    required this.muted,
    required this.primary,
    required this.onPrimary,
    required this.container,
    required this.onContainer,
    required this.track,
    required this.warm,
    required this.warmGround,
    required this.snackAction,
  });

  factory SupporterPalette.of(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ground = theme.scaffoldBackgroundColor;
    final dark = scheme.brightness == Brightness.dark;
    Color tint(double amount) =>
        Color.alphaBlend(scheme.primary.withValues(alpha: amount), ground);

    return SupporterPalette._(
      ground: ground,
      card: dark ? tint(0.06) : Colors.white,
      line: dark ? tint(0.16) : const Color(0xFFDCE1EC),
      ink: scheme.onSurface,
      muted: scheme.onSurface.withValues(alpha: dark ? 0.72 : 0.66),
      primary: scheme.primary,
      onPrimary: scheme.onPrimary,
      container: dark ? const Color(0xFF29457F) : scheme.primaryContainer,
      onContainer: dark ? scheme.primary : scheme.onPrimaryContainer,
      track: dark ? const Color(0xFF5B6478) : const Color(0xFF8A93A8),
      warm: dark ? const Color(0xFFF0B55A) : const Color(0xFFC97F14),
      warmGround: dark ? const Color(0xFF3A2A12) : const Color(0xFFFCEFD9),
      //M2 snackbars are dark on a light theme and light on a dark one
      snackAction: dark ? const Color(0xFF355CA8) : const Color(0xFFAFC6FF),
    );
  }

  final Color ground;
  final Color card;
  final Color line;
  final Color ink;
  final Color muted;
  final Color primary;
  final Color onPrimary;
  final Color container;
  final Color onContainer;
  final Color track;
  final Color warm;
  final Color warmGround;
  final Color snackAction;
}

/// The heart on the supporter screen: a hand holding a heart, in a disc.
///
/// The heart grows with the chosen [tier]: small and still at the lowest,
/// beating at the middle, bigger and faster with rays at the top. Moving up
/// sends small hearts up out of the hand. Everything holds still when the
/// system asks for reduced motion.
class SupporterHeart extends StatefulWidget {
  const SupporterHeart({required this.tier, super.key});

  final SupporterTier tier;

  static const Size size = Size(120, 128);

  @override
  State<SupporterHeart> createState() => _SupporterHeartState();
}

/// The heart red from the design. Decorative, so it is the same in both
/// themes.
const Color kSupporterHeartRed = Color(0xFFE8505B);

@immutable
class _Pose {
  const _Pose({
    required this.heartX,
    required this.heartY,
    required this.heartScale,
    required this.handY,
    required this.handTurn,
    required this.glow,
    required this.glowScale,
    required this.beat,
    required this.rays,
    required this.burst,
  });

  final double heartX;
  final double heartY;
  final double heartScale;
  final double handY;

  /// Radians.
  final double handTurn;
  final double glow;
  final double glowScale;

  /// One heartbeat, or null for a still heart.
  final Duration? beat;
  final bool rays;

  /// How many small hearts fly up when this step is reached from below.
  final int burst;

  static const Map<SupporterTier, _Pose> byTier = {
    SupporterTier.small: _Pose(
      heartX: 0,
      heartY: 3,
      heartScale: 0.62,
      handY: 1.5,
      handTurn: 0,
      glow: 0,
      glowScale: 0.6,
      beat: null,
      rays: false,
      burst: 0,
    ),
    SupporterTier.medium: _Pose(
      heartX: 0,
      heartY: -1,
      heartScale: 1,
      handY: 0,
      handTurn: 0,
      glow: 0.1,
      glowScale: 1.1,
      beat: Duration(milliseconds: 1400),
      rays: false,
      burst: 5,
    ),
    SupporterTier.large: _Pose(
      heartX: -1,
      heartY: -4,
      heartScale: 1.35,
      handY: -0.6,
      handTurn: -5 * math.pi / 180,
      glow: 0.16,
      glowScale: 1.5,
      beat: Duration(milliseconds: 900),
      rays: true,
      burst: 12,
    ),
  };
}

class _Particle {
  const _Particle({required this.dx, required this.scale, required this.delay});

  /// Sideways drift in logical pixels.
  final double dx;
  final double scale;

  /// Start, as a fraction of the whole burst.
  final double delay;
}

/// A spring-like ease that overshoots a little, like the design's
/// `cubic-bezier(.34,1.56,.64,1)`.
const Curve kSupporterSpring = Cubic(0.34, 1.56, 0.64, 1);

class _SupporterHeartState extends State<SupporterHeart>
    with TickerProviderStateMixin {
  late final AnimationController _morph = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
    value: 1,
  );
  late final AnimationController _beat = AnimationController(vsync: this);
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  late final AnimationController _burst = AnimationController(vsync: this);

  late _Pose _from = _Pose.byTier[widget.tier]!;
  late _Pose _to = _from;
  List<_Particle> _particles = const [];
  final math.Random _random = math.Random();
  bool _still = false;

  static final Animatable<double> _beatScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 1.14,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 15,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.14,
        end: 0.97,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 15,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 0.97,
        end: 1.08,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 15,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.08,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 15,
    ),
    TweenSequenceItem(tween: ConstantTween<double>(1), weight: 40),
  ]);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    if (still != _still) {
      _still = still;
      _syncLoops();
    } else if (!_beat.isAnimating && !_still) {
      _syncLoops();
    }
  }

  @override
  void didUpdateWidget(SupporterHeart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tier == widget.tier) return;

    final target = _Pose.byTier[widget.tier]!;
    final goingUp = widget.tier.index > oldWidget.tier.index;
    _from = _poseAt(_morph.value);
    _to = target;
    if (_still) {
      _morph.value = 1;
    } else {
      _morph.forward(from: 0);
      if (goingUp && target.burst > 0) _startBurst(target.burst);
    }
    _syncLoops();
  }

  void _syncLoops() {
    final beat = _to.beat;
    if (_still || beat == null) {
      _beat
        ..stop()
        ..value = 0;
    } else if (_beat.duration != beat || !_beat.isAnimating) {
      _beat.duration = beat;
      _beat.repeat();
    }

    if (_still || !_to.rays) {
      _blink
        ..stop()
        ..value = 0;
    } else if (!_blink.isAnimating) {
      _blink.repeat(reverse: true);
    }

    if (_still) {
      _burst
        ..stop()
        ..value = 1;
      _particles = const [];
    }
  }

  void _startBurst(int count) {
    const flightMs = 1000;
    const staggerMs = 55;
    final totalMs = flightMs + staggerMs * (count - 1);
    _particles = [
      for (var i = 0; i < count; i++)
        _Particle(
          dx: _random.nextDouble() * 100 - 50,
          scale: 0.6 + _random.nextDouble() * 0.8,
          delay: staggerMs * i / totalMs,
        ),
    ];
    _burst
      ..duration = Duration(milliseconds: totalMs)
      ..forward(from: 0);
  }

  _Pose _poseAt(double raw) {
    final t = kSupporterSpring.transform(raw.clamp(0, 1));
    double lerp(double a, double b) => a + (b - a) * t;
    return _Pose(
      heartX: lerp(_from.heartX, _to.heartX),
      heartY: lerp(_from.heartY, _to.heartY),
      heartScale: lerp(_from.heartScale, _to.heartScale),
      handY: lerp(_from.handY, _to.handY),
      handTurn: lerp(_from.handTurn, _to.handTurn),
      glow: lerp(_from.glow, _to.glow).clamp(0, 1),
      glowScale: lerp(_from.glowScale, _to.glowScale),
      beat: _to.beat,
      rays: _to.rays,
      burst: _to.burst,
    );
  }

  @override
  void dispose() {
    _morph.dispose();
    _beat.dispose();
    _blink.dispose();
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = SupporterPalette.of(context);
    return ExcludeSemantics(
      child: SizedBox.fromSize(
        size: SupporterHeart.size,
        child: CustomPaint(
          painter: _HeartPainter(
            repaint: Listenable.merge([_morph, _beat, _blink, _burst]),
            state: this,
            disc: palette.container,
            hand: palette.primary,
          ),
        ),
      ),
    );
  }
}

class _HeartPainter extends CustomPainter {
  _HeartPainter({
    required Listenable repaint,
    required this.state,
    required this.disc,
    required this.hand,
  }) : super(repaint: repaint);

  final _SupporterHeartState state;
  final Color disc;
  final Color hand;

  //The art is drawn in the 24-unit space of Material's volunteer_activism
  //icon, the same numbers as the design's SVG. That SVG sits 18,26 into the
  //120x128 stage at four pixels per unit.
  static const Offset _artOrigin = Offset(18, 26);
  static const double _artScale = 4;
  static const Offset _heartCentre = Offset(16, 8);
  static const Offset _glowCentre = Offset(16, 7.5);
  static const Offset _handPivot = Offset(3, 16);
  static const Offset _discCentre = Offset(60, 68);
  static const double _discRadius = 60;

  static final Path _cuff = Path()..addRect(const Rect.fromLTRB(1, 11, 5, 22));

  static final Path _palm =
      Path()
        ..moveTo(20, 17)
        ..lineTo(13, 17)
        ..lineTo(10.91, 16.27)
        ..lineTo(11.24, 15.33)
        ..lineTo(13, 16)
        ..lineTo(15.82, 16)
        ..cubicTo(16.47, 16, 17, 15.47, 17, 14.82)
        ..cubicTo(17, 14.33, 16.69, 13.89, 16.23, 13.71)
        ..lineTo(8.97, 11)
        ..lineTo(7, 11)
        ..lineTo(7, 20.02)
        ..lineTo(14, 22)
        ..lineTo(22.01, 19)
        ..cubicTo(22, 17.9, 21.11, 17, 20, 17)
        ..close();

  static final Path heart =
      Path()
        ..moveTo(16, 3.25)
        ..cubicTo(16.65, 2.49, 17.66, 2, 18.7, 2)
        ..cubicTo(20.55, 2, 22, 3.45, 22, 5.3)
        ..cubicTo(22, 7.57, 19.09, 10.2, 16, 13)
        ..cubicTo(12.91, 10.19, 10, 7.56, 10, 5.3)
        ..cubicTo(10, 3.45, 11.45, 2, 13.3, 2)
        ..cubicTo(14.34, 2, 15.35, 2.49, 16, 3.25)
        ..close();

  static const List<(Offset, Offset)> _rays = [
    (Offset(16, -3.2), Offset(16, -5)),
    (Offset(8.6, -0.4), Offset(7.4, -1.6)),
    (Offset(23.4, -0.4), Offset(24.6, -1.6)),
    (Offset(6.2, 6.6), Offset(4.6, 6.6)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final pose = state._poseAt(state._morph.value);
    final red = Paint()..color = kSupporterHeartRed;

    canvas.drawCircle(_discCentre, _discRadius, Paint()..color = disc);

    canvas
      ..save()
      ..translate(_artOrigin.dx, _artOrigin.dy)
      ..scale(_artScale);

    //glow
    if (pose.glow > 0) {
      canvas
        ..save()
        ..translate(_glowCentre.dx, _glowCentre.dy)
        ..scale(pose.glowScale)
        ..drawCircle(
          Offset.zero,
          7,
          Paint()
            ..color = kSupporterHeartRed.withValues(alpha: pose.glow)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
        )
        ..restore();
    }

    //rays, blinking between full and a third
    if (pose.rays) {
      final fadeIn = state._morph.value.clamp(0.0, 1.0);
      final blink = 1 - 0.65 * Curves.easeInOut.transform(state._blink.value);
      final rayPaint =
          Paint()
            ..color = kSupporterHeartRed.withValues(alpha: fadeIn * blink)
            ..strokeWidth = 0.7
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke;
      for (final (a, b) in _rays) {
        canvas.drawLine(a, b, rayPaint);
      }
    }

    //hand
    final handPaint = Paint()..color = hand;
    canvas
      ..save()
      ..translate(_handPivot.dx, _handPivot.dy + pose.handY)
      ..rotate(pose.handTurn)
      ..translate(-_handPivot.dx, -_handPivot.dy)
      ..drawPath(_cuff, handPaint)
      ..drawPath(_palm, handPaint)
      ..restore();

    //heart
    final beat =
        state._beat.isAnimating
            ? _SupporterHeartState._beatScale.transform(state._beat.value)
            : 1.0;
    canvas
      ..save()
      ..translate(_heartCentre.dx + pose.heartX, _heartCentre.dy + pose.heartY)
      ..scale(pose.heartScale * beat)
      ..translate(-_heartCentre.dx, -_heartCentre.dy)
      ..drawPath(heart, red)
      ..restore()
      ..restore();

    _paintBurst(canvas);
  }

  void _paintBurst(Canvas canvas) {
    final particles = state._particles;
    if (particles.isEmpty || !state._burst.isAnimating) return;

    canvas
      ..save()
      ..clipPath(
        Path()
          ..addOval(Rect.fromCircle(center: _discCentre, radius: _discRadius)),
      );

    final total = state._burst.value;
    final span = 1 - particles.last.delay;
    const start = Offset(74.4, 47.3);
    for (final p in particles) {
      final local = ((total - p.delay) / span).clamp(0.0, 1.0);
      if (local <= 0 || local >= 1) continue;
      final eased = Curves.easeOut.transform(local);
      final opacity = eased < 0.15 ? eased / 0.15 : 1 - (eased - 0.15) / 0.85;
      final scale = 0.4 + (p.scale - 0.4) * eased;
      //13 px, like the design; the heart path is 12 units wide
      final unit = 13 / 12 * scale;
      final centre = start + Offset(p.dx * eased, -36 * eased);
      canvas
        ..save()
        ..translate(centre.dx, centre.dy)
        ..scale(unit)
        ..translate(-16, -7.5)
        //a rim in the disc colour, so a small heart still reads while it
        //crosses the big red one
        ..drawPath(
          heart,
          Paint()
            ..color = disc.withValues(alpha: opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4 / unit,
        )
        ..drawPath(
          heart,
          Paint()..color = kSupporterHeartRed.withValues(alpha: opacity),
        )
        ..restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HeartPainter oldDelegate) =>
      oldDelegate.disc != disc || oldDelegate.hand != hand;
}
