import 'package:flutter/material.dart';

DateTime _utcDay(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// A month calendar for choosing which day a photo is for. Days that already
/// have a photo are filled in with a tick; days the schedule asks for, with no
/// photo yet, have a ring. Returns the chosen day (local midnight), or null.
Future<DateTime?> showPhotoDayPicker(
  BuildContext context, {
  required DateTime first,
  required DateTime last,
  required DateTime initial,
  required Set<DateTime> photoDays,
  Set<DateTime> dueDays = const {},
  String helpText = 'Which day is this photo for?',
}) => showDialog<DateTime>(
  context: context,
  builder: (_) => PhotoDayPicker(
    first: first,
    last: last,
    initial: initial,
    photoDays: photoDays,
    dueDays: dueDays,
    helpText: helpText,
  ),
);

class PhotoDayPicker extends StatefulWidget {
  const PhotoDayPicker({
    super.key,
    required this.first,
    required this.last,
    required this.initial,
    required this.photoDays,
    this.dueDays = const {},
    this.helpText = 'Which day is this photo for?',
  });
  final DateTime first, last, initial;

  /// Date-only (UTC) days that already have a photo.
  final Set<DateTime> photoDays;

  /// Date-only (UTC) days the schedule asks for a photo.
  final Set<DateTime> dueDays;
  final String helpText;

  @override
  State<PhotoDayPicker> createState() => _PhotoDayPickerState();
}

class _PhotoDayPickerState extends State<PhotoDayPicker> {
  late DateTime _month = DateTime(widget.initial.year, widget.initial.month);
  late DateTime _selected = DateTime(
    widget.initial.year,
    widget.initial.month,
    widget.initial.day,
  );

  bool _inRange(DateTime d) =>
      !_utcDay(d).isBefore(_utcDay(widget.first)) &&
      !_utcDay(d).isAfter(_utcDay(widget.last));

  bool get _canPrev =>
      DateTime(_month.year, _month.month, 0).isAfter(
        DateTime(widget.first.year, widget.first.month, widget.first.day - 1),
      ) ||
      DateTime(
        _month.year,
        _month.month - 1,
      ).isAfter(DateTime(widget.first.year, widget.first.month - 1));

  bool get _canNext => DateTime(
    _month.year,
    _month.month + 1,
  ).isBefore(DateTime(widget.last.year, widget.last.month + 1));

  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final lead = (DateTime(_month.year, _month.month, 1).weekday - 1) % 7;
    final cells = <Widget>[
      for (final w in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
        Center(child: Text(w, style: Theme.of(context).textTheme.labelMedium)),
      for (var i = 0; i < lead; i++) const SizedBox(),
      for (var day = 1; day <= daysInMonth; day++)
        _dayCell(DateTime(_month.year, _month.month, day), scheme),
    ];
    return AlertDialog(
      scrollable:
          true, // short screens (landscape) can scroll instead of overflow
      title: Text(widget.helpText),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous month',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _canPrev
                      ? () => setState(
                          () =>
                              _month = DateTime(_month.year, _month.month - 1),
                        )
                      : null,
                ),
                Expanded(
                  child: Text(
                    loc.formatMonthYear(_month),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Next month',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _canNext
                      ? () => setState(
                          () =>
                              _month = DateTime(_month.year, _month.month + 1),
                        )
                      : null,
                ),
              ],
            ),
            // Plain rows (not a lazy grid) so the dialog can size and scroll.
            for (var i = 0; i < cells.length; i += 7)
              Row(
                children: [
                  for (var j = i; j < i + 7; j++)
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1.15,
                        child: j < cells.length ? cells[j] : const SizedBox(),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _legend(
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check, size: 12, color: scheme.onPrimary),
                  ),
                  'Has a photo',
                ),
                if (widget.dueDays.isNotEmpty)
                  _legend(
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.primary, width: 2),
                      ),
                    ),
                    'Photo day, no photo yet',
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(loc.cancelButtonLabel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () => Navigator.pop(context, _selected),
          child: Text(loc.okButtonLabel),
        ),
      ],
    );
  }

  Widget _legend(Widget swatch, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      swatch,
      const SizedBox(width: 6),
      Flexible(
        child: Text(label, style: Theme.of(context).textTheme.bodySmall),
      ),
    ],
  );

  Widget _dayCell(DateTime day, ColorScheme scheme) {
    final enabled = _inRange(day);
    final has = widget.photoDays.contains(_utcDay(day));
    final due = widget.dueDays.contains(_utcDay(day));
    final selected = day == _selected;
    final loc = MaterialLocalizations.of(context);
    final label =
        '${loc.formatFullDate(day)}${has ? ', has a photo' : ''}'
        '${!has && due ? ', photo day' : ''}';
    final bg = has ? scheme.primary : null;
    final fg = !enabled
        ? scheme.onSurface.withValues(alpha: 0.3)
        : has
        ? scheme.onPrimary
        : scheme.onSurface;
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      child: InkResponse(
        key: Key('day-${day.year}-${day.month}-${day.day}'),
        onTap: enabled ? () => setState(() => _selected = day) : null,
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: selected
                ? Border.all(color: scheme.tertiary, width: 3)
                : (due && !has
                      ? Border.all(color: scheme.primary, width: 2)
                      : null),
          ),
          alignment: Alignment.center,
          child: Text(
            '${day.day}',
            style: TextStyle(
              color: fg,
              fontWeight: has || selected ? FontWeight.w700 : null,
            ),
          ),
        ),
      ),
    );
  }
}
