import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// The page itself: a gradient with the theme's own shape scattered across it,
/// drifting as the ledger scrolls.
///
/// Changing the text colour is not changing the theme. What a child recognises
/// as "mine" is the page, so the page is where the theme has to live: a sweep
/// from near-white at the top to a tint at the bottom, with hearts, stars,
/// crowns or gems set into it.
///
/// It moves, and only when the user does. Scrolling the ledger drags the shapes
/// along at a quarter speed and turns them slightly, which reads as depth
/// rather than decoration. A backdrop that animated on its own would be a
/// battery cost and a distraction in an app people open for ten seconds at a
/// time; one that answers the finger costs nothing when nobody is touching it.
///
/// The shapes are white — never the accent. That is not timidity: an accent-tinted motif pulls the page toward
/// the colour the accent-coloured text is painted in, and measured, it fails
/// 4.5:1 even at three percent opacity. Moving away from the ink instead means
/// a shape passing behind a word can only ever make it easier to read.
///
/// Both ends of the gradient were measured against every text colour before the
/// values were chosen, and the darker end of the Prințesă page had to be opened
/// up twice to clear 4.5:1.
class ThemedBackdrop extends StatefulWidget {
  const ThemedBackdrop({
    super.key,
    required this.flavor,
    required this.child,
  });

  final AppFlavor flavor;
  final Widget child;

  @override
  State<ThemedBackdrop> createState() => _ThemedBackdropState();
}

class _ThemedBackdropState extends State<ThemedBackdrop> {
  /// How far the ledger has been scrolled, in logical pixels.
  ///
  /// Held in a notifier rather than in `setState` so a scroll repaints the
  /// painter alone and never the screen on top of it.
  final _scroll = ValueNotifier<double>(0);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    // Only the vertical list underneath. The category grid and the day strip
    // scroll sideways, and dragging one of those should not move the sky.
    if (notification.metrics.axis != Axis.vertical) return false;
    _scroll.value = notification.metrics.pixels;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final money = Theme.of(context).extension<MoneyColors>()!;

    return Stack(
      children: [
        Positioned.fill(
          // The painter never rebuilds with the content above it.
          child: RepaintBoundary(
            child: ValueListenableBuilder<double>(
              valueListenable: _scroll,
              builder: (context, offset, _) => CustomPaint(
                painter: _BackdropPainter(
                  top: money.backdropTop,
                  bottom: money.backdropBottom,
                  motif: money.backdropMotif,
                  // Free to be this strong because the motif only ever moves
                  // the page away from the text.
                  motifOpacity: 0.55,
                  shape: _shapeFor(widget.flavor),
                  scroll: offset,
                ),
              ),
            ),
          ),
        ),
        NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: widget.child,
        ),
      ],
    );
  }
}

_MotifShape _shapeFor(AppFlavor flavor) => switch (flavor) {
      AppFlavor.princess => _MotifShape.heart,
      AppFlavor.prince => _MotifShape.star,
      AppFlavor.king => _MotifShape.crown,
      AppFlavor.queen => _MotifShape.gem,
    };

enum _MotifShape { heart, star, crown, gem }

class _BackdropPainter extends CustomPainter {
  _BackdropPainter({
    required this.top,
    required this.bottom,
    required this.motif,
    required this.motifOpacity,
    required this.shape,
    required this.scroll,
  });

  final Color top;
  final Color bottom;
  final Color motif;
  final double motifOpacity;
  final _MotifShape shape;
  final double scroll;

  /// How many shapes are in the field. Enough to feel scattered, few enough
  /// that a scroll stays cheap.
  static const _count = 22;

  /// The field is taller than any screen, and wraps. Without that, scrolling
  /// far enough would run off the end of the pattern and leave a bare page.
  static const _fieldHeight = 1600.0;

  /// A quarter of the scroll speed. Enough to read as depth, little enough
  /// that nobody watching the numbers notices it moving.
  static const _parallax = 0.25;

  /// Fixed so the layout is the same every frame and every launch. A pattern
  /// that reshuffled on each repaint would shimmer.
  static final _specks = _buildField();

  static List<_Speck> _buildField() {
    final random = Random(20260930);
    return [
      for (var i = 0; i < _count; i++)
        _Speck(
          x: random.nextDouble(),
          y: random.nextDouble() * _fieldHeight,
          size: 14 + random.nextDouble() * 20,
          // A lean, not a tumble. These shapes have an up: a crown rotated
          // ninety degrees stops reading as a crown and becomes a smudge.
          turn: (random.nextDouble() - 0.5) * 0.5,
          // Nearer shapes are bigger and move more, which is what makes the
          // field read as having depth rather than being a flat wallpaper.
          depth: 0.6 + random.nextDouble() * 0.8,
        ),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(rect),
    );

    final paint = Paint()
      ..color = motif.withValues(alpha: motifOpacity)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (final speck in _specks) {
      final shift = scroll * _parallax * speck.depth;
      // Wrapped into the field, then into the screen, so there is always
      // something above and below whatever is on screen.
      var y = (speck.y - shift) % _fieldHeight;
      if (y > size.height + speck.size) continue;

      canvas.save();
      canvas.translate(speck.x * size.width, y);
      // A slight sway tied to the scroll, so the shapes lean as they pass
      // rather than sliding like stickers. Kept small for the same reason the
      // starting angles are.
      canvas.rotate(speck.turn + sin(shift * 0.004) * 0.10);
      _paintShape(canvas, speck.size, paint);
      canvas.restore();
    }
  }

  void _paintShape(Canvas canvas, double s, Paint paint) {
    switch (shape) {
      case _MotifShape.heart:
        canvas.drawPath(_heart(s), paint);
      case _MotifShape.star:
        canvas.drawPath(_star(s, points: 5), paint);
      case _MotifShape.crown:
        canvas.drawPath(_crown(s), paint);
      case _MotifShape.gem:
        canvas.drawPath(_gem(s), paint);
    }
  }

  /// Two lobes and a point, drawn around the origin.
  Path _heart(double s) {
    final r = s / 2;
    return Path()
      ..moveTo(0, r * 0.75)
      ..cubicTo(-r * 1.6, -r * 0.35, -r * 0.55, -r * 1.25, 0, -r * 0.45)
      ..cubicTo(r * 0.55, -r * 1.25, r * 1.6, -r * 0.35, 0, r * 0.75)
      ..close();
  }

  /// A regular star: outer points at the full radius, inner at 42% of it.
  Path _star(double s, {required int points}) {
    final outer = s / 2;
    final inner = outer * 0.42;
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? outer : inner;
      final a = -pi / 2 + i * pi / points;
      final x = cos(a) * r;
      final y = sin(a) * r;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    return path..close();
  }

  /// Three peaks over a band, which is the least a crown can be and still be
  /// unmistakable at this size.
  Path _crown(double s) {
    final w = s / 2;
    final h = s * 0.42;
    return Path()
      ..moveTo(-w, -h)
      ..lineTo(-w * 0.52, h * 0.15)
      ..lineTo(0, -h)
      ..lineTo(w * 0.52, h * 0.15)
      ..lineTo(w, -h)
      ..lineTo(w * 0.78, h)
      ..lineTo(-w * 0.78, h)
      ..close();
  }

  /// A cut stone: a table across the top, facets down to a point.
  Path _gem(double s) {
    final w = s / 2;
    final h = s / 2;
    return Path()
      ..moveTo(-w * 0.55, -h * 0.6)
      ..lineTo(w * 0.55, -h * 0.6)
      ..lineTo(w, -h * 0.05)
      ..lineTo(0, h)
      ..lineTo(-w, -h * 0.05)
      ..close();
  }

  @override
  bool shouldRepaint(_BackdropPainter old) =>
      old.scroll != scroll ||
      old.top != top ||
      old.bottom != bottom ||
      old.motif != motif ||
      old.motifOpacity != motifOpacity ||
      old.shape != shape;
}

/// One shape's place in the field.
class _Speck {
  const _Speck({
    required this.x,
    required this.y,
    required this.size,
    required this.turn,
    required this.depth,
  });

  /// Across the screen, as a fraction of its width.
  final double x;

  /// Down the field, in logical pixels.
  final double y;

  final double size;

  /// Where it starts turned to, in radians.
  final double turn;

  /// How strongly it answers the scroll. Bigger is nearer.
  final double depth;
}
