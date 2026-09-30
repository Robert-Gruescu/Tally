import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tally/core/widgets/celebration.dart';

/// The half-second of confetti after something is saved.
///
/// Decoration, and therefore held to a stricter rule than the rest of the app:
/// it must never be able to break anything. It is inserted into an overlay
/// above a live screen, it outlives the sheet that triggered it, and it fires
/// on the one action the whole product exists for. A burst that threw, or that
/// stayed on screen, or that swallowed the next tap, would cost more than it
/// ever gives.
///
/// Timing it by eye on a device does not work — it is over in 900ms, which is
/// shorter than a screenshot takes to come back. So it is measured here.
void main() {
  /// Puts a host on screen and hands back its overlay.
  Future<OverlayState> pumpHost(WidgetTester tester, {bool reduced = false}) async {
    late OverlayState overlay;

    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: child!,
      ),
      home: Builder(
        builder: (context) {
          overlay = Overlay.of(context);
          return const Scaffold(body: Text('ledgerul'));
        },
      ),
    ));

    return overlay;
  }

  int shapesOn(WidgetTester tester, IconData icon) =>
      tester.widgetList<Icon>(find.byIcon(icon)).length;

  testWidgets('a burst appears over whatever is on screen', (tester) async {
    final overlay = await pumpHost(tester);

    showCelebration(
      overlay,
      icon: Icons.favorite_rounded,
      colour: const Color(0xFFB04A7A),
      reducedMotion: false,
    );
    // Far enough in that every shape has passed its own start delay.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(shapesOn(tester, Icons.favorite_rounded), greaterThan(0));
    // The screen underneath is untouched.
    expect(find.text('ledgerul'), findsOneWidget);
  });

  testWidgets('it clears itself off the screen', (tester) async {
    final overlay = await pumpHost(tester);

    showCelebration(
      overlay,
      icon: Icons.star_rounded,
      colour: const Color(0xFF2E6E9E),
      reducedMotion: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(shapesOn(tester, Icons.star_rounded), greaterThan(0));

    // A celebration that outstays its welcome is the stuck undo bar all over
    // again, except this one sits on top of everything.
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
    expect(shapesOn(tester, Icons.star_rounded), 0);
  });

  testWidgets('it never takes a touch away from the screen below',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: GestureDetector(
              onTap: () => taps++,
              child: const SizedBox(
                width: 300,
                height: 300,
                child: ColoredBox(color: Color(0xFFEEEEEE)),
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => showCelebration(
              Overlay.of(context),
              icon: Icons.diamond_rounded,
              colour: const Color(0xFF7A4FA3),
              reducedMotion: false,
            ),
            child: const Icon(Icons.add),
          ),
        ),
      ),
    ));

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(shapesOn(tester, Icons.diamond_rounded), greaterThan(0));

    // Mid-flight, a second expense has to be startable.
    await tester.tap(find.byType(GestureDetector).first, warnIfMissed: false);
    await tester.pump();
    expect(taps, 1, reason: 'the burst must not eat the tap');

    await tester.pumpAndSettle();
  });

  testWidgets('two bursts in a row do not trip over each other',
      (tester) async {
    final overlay = await pumpHost(tester);

    void fire() => showCelebration(
          overlay,
          icon: Icons.workspace_premium_rounded,
          colour: const Color(0xFF8C6318),
          reducedMotion: false,
        );

    fire();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    fire();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(shapesOn(tester, Icons.workspace_premium_rounded), 0);
  });

  group('when it should stay out of the way', () {
    testWidgets('reduced motion means nothing moves at all', (tester) async {
      final overlay = await pumpHost(tester, reduced: true);

      showCelebration(
        overlay,
        icon: Icons.favorite_rounded,
        colour: const Color(0xFFB04A7A),
        // Passed by the caller, which reads the phone's own setting.
        reducedMotion: true,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(shapesOn(tester, Icons.favorite_rounded), 0);
    });

    testWidgets('no overlay is not an error', (tester) async {
      // The sheet can be closed by something else first. Saving must not fail
      // because there was nowhere to put the confetti.
      showCelebration(
        null,
        icon: Icons.favorite_rounded,
        colour: const Color(0xFFB04A7A),
        reducedMotion: false,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
