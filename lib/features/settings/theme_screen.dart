import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets/money_text.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';

/// Choosing a crown.
///
/// Built for someone who cannot yet read the word "lavandă": every theme shows
/// itself rather than describing itself, in a card painted with its own real
/// colours, down to the two money colours and a specimen amount. Nothing here
/// is a swatch of paint next to a label — it is a small picture of what the
/// app is about to look like.
///
/// Choosing takes effect immediately, behind the picker. There is no Save
/// button and nothing to confirm, because the change is free, visible and
/// reversible, and a child should be able to try all five without being asked
/// to commit to anything.
class ThemeScreen extends ConsumerWidget {
  const ThemeScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const ThemeScreen());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final selected = ref.watch(flavorProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.themeTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 18),
            child: Text(l10n.themeSub, style: theme.textTheme.bodySmall),
          ),
          for (final flavor in AppFlavor.values) ...[
            _FlavorCard(
              flavor: flavor,
              selected: flavor == selected,
              onTap: () {
                if (flavor == selected) return;
                HapticFeedback.selectionClick();
                ref.read(flavorProvider.notifier).set(flavor);
              },
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _FlavorCard extends StatelessWidget {
  const _FlavorCard({
    required this.flavor,
    required this.selected,
    required this.onTap,
  });

  final AppFlavor flavor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The card is painted from the theme it is offering, not from the one
    // currently on. Building the whole ThemeData is the honest way to do that:
    // it cannot drift from what tapping actually produces, because it is the
    // same code that produces it.
    final preview = AppTheme.light(flavor);
    final money = preview.extension<MoneyColors>()!;
    final accent = preview.colorScheme.primary;
    final ink = preview.colorScheme.onSurface;
    // The card is painted with the same two colours the real page is, so what
    // is on offer is what arrives.
    final pageTop = money.backdropTop;
    final pageBottom = money.backdropBottom;

    return Semantics(
      selected: selected,
      button: true,
      label: flavor.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.base),
          curve: Motion.ease,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [pageTop, pageBottom],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              // The chosen card is ringed in its own accent, at a weight you
              // can see across a room. A tick alone is easy to miss when the
              // five cards are already different colours.
              color: selected ? accent : money.hairline,
              width: selected ? 2.5 : 1,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.14),
                      border: Border.all(color: accent, width: 1.5),
                    ),
                    child: Icon(flavor.emblem, size: 21, color: accent),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          flavor.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: preview.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          flavor.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: preview.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedScale(
                    duration: Motion.of(context, Motion.base),
                    curve: Motion.ease,
                    scale: selected ? 1 : 0,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 17,
                        color: preview.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // A specimen of the only two colours that carry meaning, with a
              // real amount beside each. This is the part that matters: a
              // child picking a theme should still be able to tell the money
              // coming in from the money going out.
              Row(
                children: [
                  Expanded(
                    child: _Specimen(
                      label: l10n.income,
                      minor: 5000,
                      color: money.income,
                      ink: ink,
                      muted: money.muted,
                      style: preview.textTheme.titleSmall!,
                      showPlus: true,
                    ),
                  ),
                  Container(width: 1, height: 26, color: money.hairline),
                  Expanded(
                    child: _Specimen(
                      label: l10n.expenses,
                      minor: -1250,
                      color: money.expense,
                      ink: ink,
                      muted: money.muted,
                      style: preview.textTheme.titleSmall!,
                      showPlus: false,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One money colour, shown doing its job rather than sitting in a swatch.
class _Specimen extends ConsumerWidget {
  const _Specimen({
    required this.label,
    required this.minor,
    required this.color,
    required this.ink,
    required this.muted,
    required this.style,
    required this.showPlus,
  });

  final String label;
  final int minor;
  final Color color;
  final Color ink;
  final Color muted;
  final TextStyle style;
  final bool showPlus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style.copyWith(
                  color: muted,
                  fontWeight: FontWeight.w500,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        MoneyText(
          minor: minor,
          currency: currency,
          showCurrency: false,
          signed: true,
          showPlus: showPlus,
          style: style,
          color: color,
          fractionScale: 0.78,
        ),
      ],
    );
  }
}
