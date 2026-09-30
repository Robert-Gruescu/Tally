import 'dart:math';

import 'package:flutter/material.dart';

/// A short burst of the current theme's shape, after something is saved.
///
/// This is the only purely decorative thing in the app, and it earns its place
/// for one reason: writing down what you spent has no natural reward. The money
/// is already gone, the number that appears is smaller than the last one, and
/// nothing good visibly happens. For an adult the habit survives that. For a
/// child it usually does not.
///
/// So the app supplies the missing half-second. Hearts for the princess, stars
/// for the prince, crowns and gems for the two older ones.
///
/// Rules it keeps to:
///  - it never blocks anything, so a second entry can start mid-flight;
///  - it is over in well under a second, because a celebration that outlasts
///    the pleasure becomes a wait;
///  - it does not run at all when the phone asks for reduced motion.
/// Everything is passed in rather than read from a [BuildContext].
///
/// The caller reads these off its own context before it starts saving, then
/// closes the sheet and calls this. Handing a context across that gap would
/// mean reaching through a widget that may already be gone, and the burst is
/// the least important thing on screen: it must never be the reason a save
/// throws.
void showCelebration(
  OverlayState? overlay, {
  required IconData icon,
  required Color colour,
  required bool reducedMotion,
}) {
  if (reducedMotion || overlay == null || !overlay.mounted) return;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _Celebration(
      icon: icon,
      colour: colour,
      onDone: () {
        // Guarded: a rebuild of the tree underneath can dispose the entry
        // first, and removing a detached entry throws.
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

class _Celebration extends StatefulWidget {
  const _Celebration({
    required this.icon,
    required this.colour,
    required this.onDone,
  });

  final IconData icon;
  final Color colour;
  final VoidCallback onDone;

  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration>
    with SingleTickerProviderStateMixin {
  static const _count = 14;
  static const _duration = Duration(milliseconds: 900);

  late final AnimationController _controller;

  /// Fixed at construction rather than per frame, so each shape keeps its own
  /// path instead of jittering.
  late final List<_Speck> _specks;

  @override
  void initState() {
    super.initState();

    final random = Random();
    _specks = [
      for (var i = 0; i < _count; i++)
        _Speck(
          // Spread across the width, denser in the middle where the eye is.
          dx: (random.nextDouble() - 0.5) * 1.6,
          rise: 0.22 + random.nextDouble() * 0.30,
          size: 13 + random.nextDouble() * 13,
          spin: (random.nextDouble() - 0.5) * 1.4,
          delay: random.nextDouble() * 0.25,
        ),
    ];

    _controller = AnimationController(vsync: this, duration: _duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    // Nothing here may take a touch: the list underneath stays usable the whole
    // time, and a second expense can be started before the first burst lands.
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            children: [
              for (final speck in _specks)
                _buildSpeck(speck, _controller.value, size),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSpeck(_Speck speck, double t, Size size) {
    // Each shape starts a little after the one before it, so the burst reads as
    // a scatter rather than a single blink.
    final local = ((t - speck.delay) / (1 - speck.delay)).clamp(0.0, 1.0);
    if (local <= 0) return const SizedBox.shrink();

    // Out fast, then drifting: eased so the shapes leap and then float,
    // which is what confetti does and what a linear rise never looks like.
    final eased = Curves.easeOutCubic.transform(local);

    // Fades only in the last third. Fading from the start makes the burst look
    // like it is failing rather than finishing.
    final opacity = local < 0.65 ? 1.0 : 1.0 - (local - 0.65) / 0.35;

    return Positioned(
      // Rises from just above the add button, which is where the finger was.
      left: size.width / 2 + speck.dx * size.width * 0.34 * eased,
      bottom: size.height * 0.12 + size.height * speck.rise * eased,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: speck.spin * eased * pi,
          child: Icon(
            widget.icon,
            size: speck.size,
            color: widget.colour,
          ),
        ),
      ),
    );
  }
}

/// One shape's own path through the burst.
class _Speck {
  const _Speck({
    required this.dx,
    required this.rise,
    required this.size,
    required this.spin,
    required this.delay,
  });

  /// Sideways drift, as a fraction of the screen. Negative goes left.
  final double dx;

  /// How far up it travels, as a fraction of the screen height.
  final double rise;

  final double size;

  /// Turns, in half-rotations.
  final double spin;

  /// How late it starts, as a fraction of the whole burst.
  final double delay;
}
