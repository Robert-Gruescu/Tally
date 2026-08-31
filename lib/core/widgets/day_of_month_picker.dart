import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../recurrence.dart';
import '../theme.dart';

/// A horizontal strip of 1..31.
///
/// A dropdown would hide the choice behind a tap, and a calendar would imply a
/// specific date rather than a day that repeats. The strip shows the whole
/// range at once and scrolls the chosen day into view.
class DayOfMonthPicker extends StatefulWidget {
  const DayOfMonthPicker({
    super.key,
    required this.day,
    required this.onChanged,
    this.label,
    this.lastDayLabel = 'ultima zi',
  });

  final int day;
  final ValueChanged<int> onChanged;
  final String? label;
  final String lastDayLabel;

  @override
  State<DayOfMonthPicker> createState() => _DayOfMonthPickerState();
}

class _DayOfMonthPickerState extends State<DayOfMonthPicker> {
  late final ScrollController _controller;

  static const _cell = 42.0;
  static const _gap = 7.0;

  @override
  void initState() {
    super.initState();
    // Opens with the current day already on screen. Someone whose salary lands
    // on the 28th should not have to scroll to see their own setting.
    final index = (widget.day - 1).clamp(0, Recurrence.maxDay - 1);
    _controller = ScrollController(
      initialScrollOffset: (index - 2).clamp(0, Recurrence.maxDay - 1) *
          (_cell + _gap),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final money = theme.extension<MoneyColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Row(
            children: [
              Text(widget.label!, style: theme.textTheme.bodySmall),
              const SizedBox(width: 6),
              Text(
                widget.day >= Recurrence.maxDay
                    ? widget.lastDayLabel
                    : '${widget.day}',
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          height: _cell,
          child: ListView.separated(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            itemCount: Recurrence.maxDay,
            separatorBuilder: (_, _) => const SizedBox(width: _gap),
            itemBuilder: (context, i) {
              final value = i + 1;
              final selected = value == widget.day;

              return Semantics(
                selected: selected,
                button: true,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onChanged(value);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: Motion.of(context, Motion.fast),
                    curve: Motion.ease,
                    width: _cell,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? theme.colorScheme.primary : null,
                      border:
                          selected ? null : Border.all(color: money.hairline),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$value',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: selected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
