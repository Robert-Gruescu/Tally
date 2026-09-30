import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tally/core/theme.dart';
import 'package:tally/core/widgets/money_text.dart';

/// The five themes, held to the contrast they were designed against.
///
/// These numbers were measured once, by hand, before the palettes were written
/// down. Left at that they would rot: somebody brightens a pastel because it
/// looks nicer in a screenshot, and the app quietly becomes unreadable for the
/// people who needed the contrast most. So the measurement lives here instead
/// of in a comment, where changing a colour either keeps it or fails the run.
///
/// The thresholds are WCAG AA: 4.5:1 for text, and 3:1 for the things that are
/// shape rather than reading matter.
///
/// This also pins a real defect. The secondary text colour sat at 56% of the
/// ink, measuring 4.10:1 on the light page, while the comment beside it claimed
/// it had been verified at 4.5:1. Every date, hint and caption in the app is
/// that colour.
double _relativeLuminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}

/// Contrast between two opaque colours, per WCAG.
double _contrast(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Flattens a translucent colour onto its background.
///
/// Secondary text and hairlines are written as an alpha over the ink, so what
/// actually reaches the eye is the blend, not the ink. Measuring the ink alone
/// is the usual way a palette passes on paper and fails on a phone.
Color _over(Color fg, Color bg) {
  final a = fg.a;
  return Color.from(
    alpha: 1,
    red: fg.r * a + bg.r * (1 - a),
    green: fg.g * a + bg.g * (1 - a),
    blue: fg.b * a + bg.b * (1 - a),
  );
}

void main() {
  group('every theme is readable', () {
    for (final flavor in AppFlavor.values) {
      {
        final theme = AppTheme.light(flavor);
        final money = theme.extension<MoneyColors>()!;
        final name = flavor.label;

        // The page is a sweep, not a fill, and `scaffoldBackgroundColor` is
        // transparent because the gradient is painted behind every route. Text
        // sits over the whole sweep, so both ends have to hold: a gradient deep
        // enough to be worth having is deep enough to take a borderline ratio
        // under the line, which is exactly what happened to the darker end of
        // the Prințesă page twice before these values settled.
        final ends = {
          'sus': money.backdropTop,
          'jos': money.backdropBottom,
        };

        test('$name: body text is comfortable over the whole sweep', () {
          ends.forEach((end, page) {
            expect(
              _contrast(theme.colorScheme.onSurface, page),
              greaterThanOrEqualTo(7),
              reason: 'body copy should clear AAA at the $end end',
            );
          });
        });

        test('$name: secondary text clears 4.5:1 at both ends', () {
          ends.forEach((end, page) {
            expect(
              _contrast(_over(money.muted, page), page),
              greaterThanOrEqualTo(4.5),
              reason: end,
            );
          });
        });

        test('$name: both money colours clear 4.5:1 at both ends', () {
          ends.forEach((end, page) {
            expect(_contrast(money.income, page), greaterThanOrEqualTo(4.5),
                reason: 'income, $end');
            expect(_contrast(money.expense, page), greaterThanOrEqualTo(4.5),
                reason: 'expense, $end');
          });
        });

        test('$name: the accent can be read at both ends', () {
          // It carries the period label, the streak and the selected tab.
          ends.forEach((end, page) {
            expect(
              _contrast(theme.colorScheme.primary, page),
              greaterThanOrEqualTo(4.5),
              reason: end,
            );
          });
        });

        test('$name: the page motif moves away from the text, not toward it',
            () {
          // The invariant the whole backdrop rests on. A shape drawn on the
          // page shifts the background behind any word that passes over it; if
          // it shifted toward the ink, every motif would be a small hole in
          // the contrast budget and the safe opacity would be near zero.
          //
          // Going the other way, a shape can only ever raise contrast, which
          // is why the painter is free to draw them at a third to a half
          // opacity instead of a barely visible three percent.
          final motif = _relativeLuminance(money.backdropMotif);
          final page = _relativeLuminance(money.backdropBottom);
          final ink = _relativeLuminance(theme.colorScheme.onSurface);

          expect(ink, lessThan(page), reason: 'the page is always the light one');
          expect(motif, greaterThan(page),
              reason: 'dark text on a light page needs a lighter motif');
        });

        test('$name: text stays readable over a motif at full strength', () {
          // Pinned at opacity 1, which is stronger than anything the painter
          // uses. If it holds there it holds everywhere, and nobody has to
          // remember to re-measure when the opacity is tuned.
          final over = money.backdropMotif;
          expect(_contrast(theme.colorScheme.onSurface, over),
              greaterThanOrEqualTo(4.5),
              reason: 'body text');
          expect(_contrast(theme.colorScheme.primary, over),
              greaterThanOrEqualTo(4.5),
              reason: 'the accent carries the streak and the period label');
          expect(_contrast(money.income, over), greaterThanOrEqualTo(4.5),
              reason: 'income');
          expect(_contrast(money.expense, over), greaterThanOrEqualTo(4.5),
              reason: 'expense');
        });

        test('$name: the sweep is a sweep, and a gentle one', () {
          // Two ends that match would make the gradient pointless; two that
          // are far apart would put one of them outside what was measured.
          expect(money.backdropTop, isNot(money.backdropBottom));
          final gap = (_relativeLuminance(money.backdropTop) -
                  _relativeLuminance(money.backdropBottom))
              .abs();
          expect(gap, lessThan(0.15),
              reason: 'a steep page turns the text illegible at one end');
        });

        test('$name: button text can be read on the accent', () {
          expect(
            _contrast(theme.colorScheme.onPrimary, theme.colorScheme.primary),
            greaterThanOrEqualTo(4.5),
          );
        });

        test('$name: the two money colours are not the same colour', () {
          // Deliberately not a luminance test. Red and green chosen to read as
          // equals sit at almost the same lightness, and in these palettes they
          // do: the classic theme separates them by 0.005 and Prințesă by
          // 0.0005. To someone with deuteranopia they are one colour.
          //
          // That is a known property of the design rather than an oversight,
          // and it is why nothing in this app leans on colour alone: every
          // amount carries an explicit sign, and every figure sits under a word
          // that names its direction. The group below pins that promise, which
          // is the one actually being kept.
          expect(money.income, isNot(money.expense));
        });
      }
    }
  });

  group('the themes are distinct', () {
    test('no two share a page', () {
      final pages = <Color>{};
      for (final flavor in AppFlavor.values) {
        final page =
            AppTheme.light(flavor).extension<MoneyColors>()!.backdropBottom;
        expect(pages.add(page), isTrue, reason: '${flavor.label} repeats a page');
      }
    });

    test('every one has a motif shape of its own', () {
      // The scattered shapes on the page are what a child recognises across a
      // room, before any of the words.
      final shapes = <IconData>{};
      for (final flavor in AppFlavor.values) {
        expect(shapes.add(flavor.confetti), isTrue,
            reason: '${flavor.label} repeats a shape');
      }
    });

    test('there are exactly four, and no plain one', () {
      expect(AppFlavor.values, hasLength(4));
      expect(
        AppFlavor.values.map((f) => f.name),
        containsAll(<String>['princess', 'prince', 'king', 'queen']),
      );
    });

    test('no two share an accent', () {
      final accents = <Color>{};
      for (final flavor in AppFlavor.values) {
        final accent = AppTheme.light(flavor).colorScheme.primary;
        expect(accents.add(accent), isTrue,
            reason: '${flavor.label} repeats an accent');
      }
    });

    test('every one has a name, a description and two marks', () {
      for (final flavor in AppFlavor.values) {
        expect(flavor.label, isNotEmpty);
        expect(flavor.description, isNotEmpty);
        expect(flavor.emblem, isNotNull);
        expect(flavor.confetti, isNotNull);
      }
    });

    test('no accent is one of the money colours', () {
      // The accent is free to be any colour except the two that mean
      // direction. If it ever became one of them, a selected tab and money
      // going out would be painted the same.
      for (final flavor in AppFlavor.values) {
        final theme = AppTheme.light(flavor);
        final money = theme.extension<MoneyColors>()!;
        expect(theme.colorScheme.primary, isNot(money.income));
        expect(theme.colorScheme.primary, isNot(money.expense));
      }
    });
  });

  /// What the palettes lean on instead of being distinguishable by lightness.
  ///
  /// If this ever stops holding, the money colours become the only thing
  /// separating income from expense, and for a red-green colour blind reader
  /// that is nothing at all.
  group('colour is never the only signal', () {
    Future<void> pumpAmount(
      WidgetTester tester, {
      required int minor,
      required bool signed,
      required bool showPlus,
    }) =>
        tester.pumpWidget(MaterialApp(
          theme: AppTheme.light(AppFlavor.princess),
          home: Scaffold(
            body: MoneyText(
              minor: minor,
              currency: 'lei',
              signed: signed,
              showPlus: showPlus,
            ),
          ),
        ));

    testWidgets('an expense prints a minus, not just a red', (tester) async {
      await pumpAmount(tester, minor: -1250, signed: true, showPlus: false);
      expect(find.textContaining('\u2212'), findsOneWidget);
    });

    testWidgets('income prints a plus, not just a green', (tester) async {
      await pumpAmount(tester, minor: 5000, signed: true, showPlus: true);
      expect(find.textContaining('+'), findsOneWidget);
    });

    testWidgets('the amount is spoken in full, sign included', (tester) async {
      await pumpAmount(tester, minor: -1250, signed: true, showPlus: false);
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.semanticsLabel, contains('minus'));
    });
  });

  group('remembering the choice', () {
    test('a stored name comes back as itself', () {
      for (final flavor in AppFlavor.values) {
        expect(AppFlavor.byName(flavor.name), flavor);
      }
    });

    test('nothing stored yet opens on the fallback', () {
      expect(AppFlavor.byName(null), AppFlavor.fallback);
    });

    test('a name from another version does not crash the app', () {
      // Restoring a backup written by a different build, or rolling one back,
      // must not leave someone unable to open their own ledger.
      expect(AppFlavor.byName('unicorn'), AppFlavor.fallback);
      expect(AppFlavor.byName(''), AppFlavor.fallback);
    });

    test('anyone who was on the removed plain theme lands somewhere real', () {
      // It was called `classic` and it is gone. Phones that stored that name
      // must open on a theme rather than on nothing.
      expect(AppFlavor.byName('classic'), AppFlavor.fallback);
      expect(AppFlavor.values, contains(AppFlavor.byName('classic')));
    });
  });
}
