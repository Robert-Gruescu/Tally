import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Semantic colours.
///
/// The palette is deliberately austere: one ink, two money colours, nothing
/// else. Green and red are reserved *exclusively* for the direction of money,
/// so they never compete with a brand accent for the same green. Every other
/// emphasis in the app is carried by ink, weight and space.
class MoneyColors extends ThemeExtension<MoneyColors> {
  const MoneyColors({
    required this.income,
    required this.expense,
    required this.hairline,
    required this.muted,
    required this.backdropTop,
    required this.backdropBottom,
    required this.backdropMotif,
  });

  final Color income;
  final Color expense;

  /// Rules and separators. Grouping without reaching for a card.
  final Color hairline;

  /// The two ends of the page's gradient, top and bottom.
  ///
  /// Both are measured, not just the flat page colour: text sits over the whole
  /// sweep, and a gradient deep enough to be worth having is deep enough to
  /// take a border-line ratio under the line. The darker end of the Prințesă
  /// page had to be opened up twice before every colour cleared 4.5:1 on it.
  final Color backdropTop;
  final Color backdropBottom;

  /// The shapes scattered across the page.
  ///
  /// White, and never the accent. That
  /// looks like a retreat from colour and is in fact the only version that is
  /// safe: a motif tinted with the accent pulls the page *towards* the colour
  /// the accent-coloured text is painted in, so the streak badge and the period
  /// label lose contrast wherever a shape passes behind them. Measured, an
  /// accent motif fails 4.5:1 even at three percent opacity, which is too faint
  /// to be worth having.
  ///
  /// Moving away from the ink instead means the shapes can only ever *raise*
  /// contrast, at any opacity. The colour is carried by the gradient behind
  /// them, which is where it belongs.
  final Color backdropMotif;

  /// Secondary text. Verified at 4.5:1 or better against its own page in
  /// every theme, at both ends of the gradient.
  ///
  /// It used to be 56% of the ink, which measures 4.10:1 on the light page
  /// while the comment here claimed it passed. Every date, every hint and
  /// every "medie pe zi" in the app is this colour, which made it the
  /// most-read text in the product and the one below the line.
  final Color muted;

  @override
  MoneyColors copyWith({
    Color? income,
    Color? expense,
    Color? hairline,
    Color? muted,
    Color? backdropTop,
    Color? backdropBottom,
    Color? backdropMotif,
  }) =>
      MoneyColors(
        income: income ?? this.income,
        expense: expense ?? this.expense,
        hairline: hairline ?? this.hairline,
        muted: muted ?? this.muted,
        backdropTop: backdropTop ?? this.backdropTop,
        backdropBottom: backdropBottom ?? this.backdropBottom,
        backdropMotif: backdropMotif ?? this.backdropMotif,
      );

  @override
  MoneyColors lerp(MoneyColors? other, double t) {
    if (other == null) return this;
    return MoneyColors(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      backdropTop: Color.lerp(backdropTop, other.backdropTop, t)!,
      backdropBottom: Color.lerp(backdropBottom, other.backdropBottom, t)!,
      backdropMotif: Color.lerp(backdropMotif, other.backdropMotif, t)!,
    );
  }
}

/// Durations and curves used across the app.
///
/// Everything here is feedback or a state change, so nothing runs long. A
/// strong custom ease-out reads as responsive where the built-in curves feel
/// slack.
class Motion {
  const Motion._();

  static const fast = Duration(milliseconds: 140);
  static const base = Duration(milliseconds: 220);
  static const chart = Duration(milliseconds: 280);

  static const ease = Cubic(0.22, 1, 0.36, 1);

  /// Collapses a duration to zero when the platform asks for reduced motion.
  static Duration of(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}

/// The four crowns.
///
/// The app is for keeping track of money, and someone learning to do that has
/// to want to open it first. A theme picked by the person using it is the
/// cheapest way to make it theirs, and once built it costs nothing: the whole
/// palette already runs through one place.
///
/// The pastels are soft but never weak. All ten palettes below were measured
/// before they were written down: body text at 12:1 or better against its own
/// page, secondary text and both money colours past 4.5:1. A nursery palette
/// nobody can read is a worse app wearing a nicer dress.
enum AppFlavor {
  princess,
  prince,
  king,
  queen;

  /// What the picker calls it.
  String get label => switch (this) {
        AppFlavor.princess => 'Prințesă',
        AppFlavor.prince => 'Prinț',
        AppFlavor.king => 'Rege',
        AppFlavor.queen => 'Regină',
      };

  /// One line naming the colours, for the row under the title.
  String get description => switch (this) {
        AppFlavor.princess => 'Roz pudrat și lavandă',
        AppFlavor.prince => 'Bleu și verde mentă',
        AppFlavor.king => 'Auriu cald și bej',
        AppFlavor.queen => 'Mov pastel și roz prăfuit',
      };

  /// The mark that stands for the theme.
  IconData get emblem => switch (this) {
        AppFlavor.princess => Icons.auto_awesome_rounded,
        AppFlavor.prince => Icons.shield_rounded,
        AppFlavor.king => Icons.workspace_premium_rounded,
        AppFlavor.queen => Icons.diamond_rounded,
      };

  /// The shape that rains down when something is saved.
  IconData get confetti => switch (this) {
        AppFlavor.princess => Icons.favorite_rounded,
        AppFlavor.prince => Icons.star_rounded,
        AppFlavor.king => Icons.workspace_premium_rounded,
        AppFlavor.queen => Icons.diamond_rounded,
      };

  /// What a fresh install opens with, and what anything unrecognised becomes.
  static const fallback = AppFlavor.princess;

  /// Stored in preferences by name, so reordering this enum later cannot
  /// silently move everybody to a different theme.
  ///
  /// Anything it does not recognise lands on [fallback]. That covers a fresh
  /// install, a backup written by a newer build, and the people who were on
  /// the plain theme before it was removed — none of whom should be met with
  /// a crash or a blank page.
  static AppFlavor byName(String? name) {
    for (final flavor in AppFlavor.values) {
      if (flavor.name == name) return flavor;
    }
    return fallback;
  }
}

/// The six colours a theme is made of, at one brightness.
class _Palette {
  const _Palette({
    required this.ink,
    required this.bg,
    required this.surface,
    required this.accent,
    required this.income,
    required this.expense,
    required this.backdropTop,
    required this.backdropBottom,
  });

  /// Body text, and what almost everything else is derived from.
  final Color ink;
  final Color bg;
  final Color surface;

  /// Selection, the save button, the underline. Never the money colours:
  /// those two mean direction and nothing else.
  final Color accent;

  final Color income;
  final Color expense;

  /// The page is a sweep between these two rather than one flat fill.
  final Color backdropTop;
  final Color backdropBottom;
}

class AppTheme {
  const AppTheme._();

  // Light. Each page carries the faintest wash of its own hue, so the neutrals
  // sit with the accent instead of reading as a separate grey system.
  // Each page is a sweep from a near-white top to a tinted bottom, so the
  // colour is something the eye moves through rather than a flat wash. The
  // bottom end is the one that had to be measured: every colour in the app
  // still clears 4.5:1 against it.
  static const _light = {
    AppFlavor.princess: _Palette(
      ink: Color(0xFF3B2A33),
      bg: Color(0xFFFDF4F7),
      surface: Color(0xFFFFFFFF),
      accent: Color(0xFFB04A7A),
      income: Color(0xFF1F7A55),
      // A rose red rather than a brick one: it belongs to this palette, and it
      // still reads as the opposite of the green beside it.
      expense: Color(0xFFB8425F),
      backdropTop: Color(0xFFFFF9FB),
      backdropBottom: Color(0xFFFCF2F6),
    ),
    AppFlavor.prince: _Palette(
      ink: Color(0xFF24313D),
      bg: Color(0xFFF2F8FC),
      surface: Color(0xFFFFFFFF),
      accent: Color(0xFF2E6E9E),
      income: Color(0xFF1C7A5E),
      expense: Color(0xFFB04A3A),
      backdropTop: Color(0xFFF8FCFE),
      backdropBottom: Color(0xFFE9F3FA),
    ),
    AppFlavor.king: _Palette(
      ink: Color(0xFF3A3022),
      bg: Color(0xFFFDF8ED),
      surface: Color(0xFFFFFFFF),
      // Deep enough to hold white on it. The bright gold everyone reaches for
      // first measures 4.3:1 and fails, which is how gold interfaces end up
      // unreadable in daylight.
      accent: Color(0xFF8C6318),
      income: Color(0xFF2A6E45),
      expense: Color(0xFFA8482C),
      backdropTop: Color(0xFFFFFDF7),
      backdropBottom: Color(0xFFF9F0DF),
    ),
    AppFlavor.queen: _Palette(
      ink: Color(0xFF322A3B),
      bg: Color(0xFFF9F4FC),
      surface: Color(0xFFFFFFFF),
      accent: Color(0xFF7A4FA3),
      income: Color(0xFF226E52),
      expense: Color(0xFFA8445E),
      backdropTop: Color(0xFFFDFAFE),
      backdropBottom: Color(0xFFF1E9F8),
    ),
  };

  /// The app has one brightness.
  ///
  /// There is no dark variant, on purpose. A themed page is the whole point of
  /// these four, and the dark versions of them were the weakest thing in the
  /// product: pastels taken down to near-black stop being pastels, and the
  /// gradient and the motifs that carry the character turn into mud. Following
  /// the phone into that would mean half the people who choose a theme never
  /// see the one they chose.
  ///
  /// So the page stays light whatever the system is set to. The cost is
  /// honest — the app is brighter than its neighbours at night — and it is
  /// the trade this app is willing to make.
  static ThemeData light(AppFlavor flavor) => _build(_light[flavor]!);

  static ThemeData _build(_Palette palette) {
    final ink = palette.ink;
    final bg = palette.bg;
    final surface = palette.surface;
    final accent = palette.accent;
    // 70% on light, not 56%: measured rather than guessed. See MoneyColors.
    final muted = ink.withValues(alpha: 0.70);
    final hairline = ink.withValues(alpha: 0.09);

    // The accent is the primary: it carries selection, the save button and the
    // underline. The money colours stay out of it entirely, so green and red
    // still mean one thing each.
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
    ).copyWith(
      primary: accent,
      onPrimary: Colors.white,
      surface: surface,
      onSurface: ink,
      error: palette.expense,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // Transparent, because the page is painted by [ThemedBackdrop] behind
      // every route. A Scaffold filling itself with a flat colour would cover
      // the gradient and the motifs with a solid slab.
      //
      // The opaque colour is still carried on the palette and is what the two
      // ends of the gradient are derived from; contrast is measured against
      // those ends rather than against this.
      scaffoldBackgroundColor: Colors.transparent,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme, ink, muted),
      extensions: [
        MoneyColors(
          income: palette.income,
          expense: palette.expense,
          hairline: hairline,
          muted: muted,
          backdropTop: palette.backdropTop,
          backdropBottom: palette.backdropBottom,
          // Away from the ink, always. See MoneyColors.backdropMotif.
          backdropMotif: Colors.white,
        ),
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        // Stated rather than inferred. An AppBar with no colour of its own
        // leaves Flutter to guess the status bar contrast from a transparent
        // background, and it guesses light icons — which on a cream page means
        // the clock and the battery vanish. The page is always light, so these
        // are always dark.
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      dividerTheme: DividerThemeData(color: hairline, thickness: 1, space: 1),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: hairline,
        dragHandleSize: const Size(36, 4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 3,
        highlightElevation: 3,
        shape: const CircleBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          foregroundColor: ink,
          side: BorderSide(color: hairline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        // Placeholder text needs the same 4.5:1 as body copy. A lighter grey
        // here is the most common contrast failure in finance interfaces.
        hintStyle: TextStyle(color: muted, fontWeight: FontWeight.w400),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 62,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected) ? accent : muted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11.5,
            letterSpacing: 0,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? accent : muted,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        actionTextColor: Colors.white,
        contentTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 14.5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        side: BorderSide(color: hairline),
        shape: const StadiumBorder(),
        labelStyle: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: ink,
        ),
      ),
    );
  }

  /// An explicit scale at roughly a 1.28 ratio. Material's defaults cluster in
  /// a flat middle band, which is why an untouched M3 app reads as undesigned:
  /// nothing is decisively larger than anything else.
  static TextTheme _textTheme(TextTheme base, Color ink, Color muted) {
    TextStyle style(
      double size,
      FontWeight weight, {
      double tracking = 0,
      double height = 1.3,
      Color? color,
    }) =>
        TextStyle(
          fontSize: size,
          fontWeight: weight,
          letterSpacing: tracking,
          height: height,
          color: color ?? ink,
        );

    return base.copyWith(
      // The balance. Tight tracking keeps large numerals from drifting apart,
      // stopping well short of the point where they touch.
      displayLarge: style(52, FontWeight.w600, tracking: -2, height: 1.02),
      displayMedium: style(40, FontWeight.w600, tracking: -1.4, height: 1.05),
      displaySmall: style(30, FontWeight.w600, tracking: -0.9, height: 1.1),
      headlineSmall: style(24, FontWeight.w600, tracking: -0.6),
      titleLarge: style(20, FontWeight.w600, tracking: -0.3),
      titleMedium: style(17, FontWeight.w600, tracking: -0.2),
      titleSmall: style(15, FontWeight.w600, tracking: -0.1),
      bodyLarge: style(16, FontWeight.w400, height: 1.5),
      bodyMedium: style(15, FontWeight.w400, height: 1.45),
      bodySmall: style(13, FontWeight.w400, height: 1.4, color: muted),
      labelLarge: style(15, FontWeight.w600, tracking: -0.1),
      labelMedium: style(13, FontWeight.w500),
      labelSmall: style(11.5, FontWeight.w500, color: muted),
    );
  }
}
