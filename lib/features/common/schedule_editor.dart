import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../domain/baby.dart';
import '../../domain/schedule.dart';

/// One editable phase row (mutable draft of a [Phase]).
class PhaseDraft {
  PhaseDraft(this.startValue, this.startUnit, this.every, this.unit);
  int startValue;
  TimeUnit startUnit;
  int every;
  TimeUnit unit;

  factory PhaseDraft.from(Phase p) => PhaseDraft(
    p.start.value,
    p.start.unit,
    p.frequency.every,
    p.frequency.unit,
  );

  Phase toPhase() => Phase(
    start: Age(startValue, startUnit),
    frequency: Frequency(every, unit),
  );
}

/// Units offered for the finish line. Years are only a convenience: they are
/// saved as months (2 years = 24 months), so the schedule engine is unchanged.
enum FinishUnit { day, week, month, year }

/// Highest finish-line value in [u]: 18 years.
int maxFinishIn(FinishUnit u) => switch (u) {
  FinishUnit.day => maxAgeIn(TimeUnit.day),
  FinishUnit.week => maxAgeIn(TimeUnit.week),
  FinishUnit.month => maxAgeIn(TimeUnit.month),
  FinishUnit.year => maxAgeYears,
};

/// The editable finish line: the age at which the photo series stops.
class FinishDraft {
  FinishDraft({
    this.enabled = false,
    this.value = 2,
    this.unit = FinishUnit.year,
  });
  bool enabled;
  int value;
  FinishUnit unit;

  /// Whole years show as years, so a saved 24 months reads "2 years".
  factory FinishDraft.from(Age? end) {
    if (end == null) return FinishDraft();
    if (end.unit == TimeUnit.month && end.value >= 12 && end.value % 12 == 0) {
      return FinishDraft(
        enabled: true,
        value: end.value ~/ 12,
        unit: FinishUnit.year,
      );
    }
    return FinishDraft(
      enabled: true,
      value: end.value,
      unit: switch (end.unit) {
        TimeUnit.day => FinishUnit.day,
        TimeUnit.week => FinishUnit.week,
        TimeUnit.month => FinishUnit.month,
      },
    );
  }

  Age? toAge() => !enabled
      ? null
      : switch (unit) {
          FinishUnit.day => Age(value, TimeUnit.day),
          FinishUnit.week => Age(value, TimeUnit.week),
          FinishUnit.month => Age(value, TimeUnit.month),
          FinishUnit.year => Age(value * 12, TimeUnit.month),
        };
}

/// Returns an error message if the phases (and finish line) cannot form a
/// schedule, else null.
String? validatePhases(
  DateTime birth,
  List<PhaseDraft> drafts, {
  FinishDraft? finish,
}) {
  try {
    PhotoSchedule(
      birth,
      drafts.map((d) => d.toPhase()).toList(),
      end: finish?.toAge(),
    );
    return null;
  } on ArgumentError catch (e) {
    return '${e.message}'.contains('finish')
        ? 'The finish line must be later than the start of the last step.'
        : 'Each phase must start later than the one before it.';
  }
}

/// "2 years" for whole years, otherwise "5 weeks" and so on.
String ageSpanLabel(int value, TimeUnit unit) {
  if (unit == TimeUnit.month && value >= 12 && value % 12 == 0) {
    final y = value ~/ 12;
    return '$y year${y == 1 ? '' : 's'}';
  }
  return '$value ${unit.name}${value == 1 ? '' : 's'}';
}

const schedulePresets = <String, List<List<Object>>>{
  'Daily, then weekly, then monthly': [
    [0, TimeUnit.day, 1, TimeUnit.day],
    [1, TimeUnit.month, 1, TimeUnit.week],
    [6, TimeUnit.month, 1, TimeUnit.month],
  ],
  'Weekly, then monthly': [
    [0, TimeUnit.day, 1, TimeUnit.week],
    [6, TimeUnit.month, 1, TimeUnit.month],
  ],
  'Monthly': [
    [0, TimeUnit.day, 1, TimeUnit.month],
  ],
};

/// "Photo every ..." phases, shown as plain sentences the user can tweak.
class ScheduleEditor extends StatefulWidget {
  const ScheduleEditor({
    super.key,
    required this.phases,
    required this.birth,
    this.finish,
    this.onChanged,
    this.today,
  });
  final List<PhaseDraft> phases;

  /// The baby's birth, which the real dates are counted from.
  final DateTime birth;

  /// Overridable "today" for tests.
  final DateTime? today;

  /// The finish line; when null the editor has no finish-line section.
  final FinishDraft? finish;
  final VoidCallback? onChanged;

  @override
  State<ScheduleEditor> createState() => _ScheduleEditorState();
}

class _ScheduleEditorState extends State<ScheduleEditor> {
  List<PhaseDraft> get _p => widget.phases;

  void _change(VoidCallback f) {
    setState(f);
    widget.onChanged?.call();
  }

  String _plural(int v, TimeUnit u) => '${u.name}${v == 1 ? '' : 's'}';

  DateTime get _birthDay =>
      DateTime.utc(widget.birth.year, widget.birth.month, widget.birth.day);

  DateTime get _today {
    final t = widget.today ?? DateTime.now();
    return DateTime.utc(t.year, t.month, t.day);
  }

  /// The schedule as currently edited, or null while it is not valid.
  PhotoSchedule? _schedule() {
    try {
      return PhotoSchedule(
        widget.birth,
        _p.map((d) => d.toPhase()).toList(),
        end: widget.finish?.toAge(),
      );
    } on ArgumentError {
      return null;
    }
  }

  String _date(DateTime d, {bool year = false}) {
    final loc = MaterialLocalizations.of(context);
    return year
        ? '${loc.formatMediumDate(d)}, ${d.year}'
        : loc.formatMediumDate(d);
  }

  String _every(PhaseDraft p) => p.every == 1
      ? switch (p.unit) {
          TimeUnit.day => 'every day',
          TimeUnit.week => 'every week',
          TimeUnit.month => 'every month',
        }
      : 'every ${p.every} ${_plural(p.every, p.unit)}';

  /// "From Wed, Oct 14 · every week · until Oct 20" for step [i].
  String? _stepLine(int i, PhotoSchedule? sched) {
    if (sched == null) return null;
    final start = _p[i].toPhase().start.from(_birthDay);
    final parts = <String>['From ${_date(start)}', _every(_p[i])];
    final DateTime? stop = i + 1 < _p.length
        ? _p[i + 1]
              .toPhase()
              .start
              .from(_birthDay)
              .subtract(const Duration(days: 1))
        : sched.endDate;
    if (stop != null) {
      parts.add(
        i + 1 < _p.length ? 'until ${_date(stop)}' : 'until the finish line',
      );
    } else {
      parts.add('and so on');
    }
    return parts.join(' · ');
  }

  /// A quiet note when a step is so short it gives very few photos.
  String? _stepWarning(int i, PhotoSchedule? sched) {
    if (sched == null) return null;
    final start = _p[i].toPhase().start.from(_birthDay);
    final DateTime? stop = i + 1 < _p.length
        ? _p[i + 1]
              .toPhase()
              .start
              .from(_birthDay)
              .subtract(const Duration(days: 1))
        : sched.endDate;
    if (stop == null) return null;
    final n = sched.dueDates(start, stop).where((d) {
      return !d.isBefore(start);
    }).length;
    return n < 2 ? 'This step gives only $n photo${n == 1 ? '' : 's'}.' : null;
  }

  Widget _photoDaysCard(BuildContext context) {
    final sched = _schedule();
    final scheme = Theme.of(context).colorScheme;
    if (sched == null) {
      return Card(
        color: scheme.errorContainer.withValues(alpha: 0.4),
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Text(
            'The steps do not fit together yet: each step has to start later than the one before it.',
          ),
        ),
      );
    }
    final fromBirth = !_today.isAfter(_birthDay);
    final from = fromBirth ? _birthDay : _today;
    final next = <DateTime>[];
    var window = 60;
    while (next.length < 6 && window < 4000) {
      next
        ..clear()
        ..addAll(sched.dueDates(from, from.add(Duration(days: window))));
      if (next.length >= 6) break;
      if (sched.endDate != null &&
          from.add(Duration(days: window)).isAfter(sched.endDate!)) {
        break;
      }
      window *= 2;
    }
    final shown = next.take(6).toList();
    final last = _p.last;
    final finish = widget.finish;
    final lines = <Widget>[];
    if (finish != null && finish.enabled && sched.endDate != null) {
      final end = sched.endDate!;
      final rhythm = PhotoSchedule(
        widget.birth,
        _p.map((d) => d.toPhase()).toList(),
      );
      final inRhythm = rhythm.dueDates(end, end).isNotEmpty;
      final before = sched.dueDates(
        _birthDay,
        end.subtract(const Duration(days: 1)),
      );
      lines.add(
        Text(
          'Finish line: ${_date(end, year: true)} '
          '(${ageSpanLabel(finish.toAge()!.value, finish.toAge()!.unit)}). '
          '${inRhythm || before.isEmpty ? 'The last photo is on the finish day.' : 'Last regular photo ${_date(before.last)}, then one final photo on the finish day.'}',
        ),
      );
      if (end.difference(_birthDay).inDays < 30) {
        lines.add(
          const Text(
            'That finish line is under a month away, so the series is very short.',
          ),
        );
      }
    } else {
      lines.add(Text('…and so on, ${_every(last)}.'));
    }
    return Card(
      color: scheme.primaryContainer.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fromBirth ? 'Your first photo days' : 'Your next photo days',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final d in shown)
                  Chip(
                    label: Text(_date(d)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (final l in lines)
              Padding(padding: const EdgeInsets.only(top: 4), child: l),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose how often you want a photo. It can change as your baby grows. '
          'The last step goes on from then onwards. (One photo a day is the most.)',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final e in schedulePresets.entries)
              ActionChip(
                label: Text(e.key),
                onPressed: () => _change(() {
                  _p
                    ..clear()
                    ..addAll(
                      e.value.map(
                        (p) => PhaseDraft(
                          p[0] as int,
                          p[1] as TimeUnit,
                          p[2] as int,
                          p[3] as TimeUnit,
                        ),
                      ),
                    );
                }),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _p.length; i++) _card(i),
        TextButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Add a step'),
          onPressed:
              _p.length >= maxSteps ||
                  _p.last.startValue >= maxAgeIn(_p.last.startUnit)
              ? null
              : () => _change(() {
                  final last = _p.last;
                  _p.add(
                    PhaseDraft(
                      last.startValue + 1,
                      last.startUnit == TimeUnit.day
                          ? TimeUnit.month
                          : last.startUnit,
                      last.every,
                      last.unit,
                    ),
                  );
                }),
        ),
        if (widget.finish != null) _finishCard(widget.finish!),
        _photoDaysCard(context),
      ],
    );
  }

  Widget _finishCard(FinishDraft f) {
    String plural(FinishUnit u) => '${u.name}${f.value == 1 ? '' : 's'}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The switch is how the finish line is turned on and off.
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Finish line'),
              value: f.enabled,
              onChanged: (v) => _change(() => f.enabled = v),
            ),
            if (f.enabled)
              Row(
                children: [
                  const Expanded(child: Text('Finish line at age')),
                  IconButton(
                    tooltip: 'Less',
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: f.value > 1
                        ? () => _change(() => f.value--)
                        : null,
                  ),
                  SizedBox(
                    width: 24,
                    child: Text('${f.value}', textAlign: TextAlign.center),
                  ),
                  IconButton(
                    tooltip: 'More',
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: f.value < maxFinishIn(f.unit)
                        ? () => _change(() => f.value++)
                        : null,
                  ),
                  DropdownButton<FinishUnit>(
                    value: f.unit,
                    underline: const SizedBox(),
                    items: [
                      for (final u in FinishUnit.values)
                        DropdownMenuItem(value: u, child: Text(plural(u))),
                    ],
                    onChanged: (u) => _change(() {
                      f.unit = u!;
                      f.value = f.value.clamp(1, maxFinishIn(u));
                    }),
                  ),
                ],
              ),
            if (f.enabled && f.value >= maxFinishIn(f.unit))
              Text(
                'The longest finish line is $maxAgeYears years.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  Widget _card(int i) {
    final p = _p[i];
    final sched = _schedule();
    final line = _stepLine(i, sched);
    final warn = _stepWarning(i, sched);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  i == 0 ? 'Step 1 (from birth)' : 'Step ${i + 1}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                if (_p.length > 1)
                  IconButton(
                    tooltip: 'Remove step',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _change(() => _p.removeAt(i)),
                  ),
              ],
            ),
            if (i > 0) ...[
              _row(
                'Starts at age',
                p.startValue,
                p.startUnit,
                0,
                maxAgeIn,
                (v, u) => _change(() {
                  p.startValue = v;
                  p.startUnit = u;
                }),
              ),
              Text(
                'Birth day is age 0, so age ${ageSpanLabel(p.startValue, p.startUnit)} is '
                '${_date(p.toPhase().start.from(_birthDay))}.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            _row(
              'A photo every',
              p.every,
              p.unit,
              1,
              maxGapIn,
              (v, u) => _change(() {
                p.every = v;
                p.unit = u;
              }),
            ),
            if (line != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  line,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (warn != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(warn, style: Theme.of(context).textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    String label,
    int value,
    TimeUnit unit,
    int min,
    int Function(TimeUnit) maxIn,
    void Function(int, TimeUnit) onChanged,
  ) {
    final max = maxIn(unit);
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          tooltip: 'Less',
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > min ? () => onChanged(value - 1, unit) : null,
        ),
        SizedBox(width: 24, child: Text('$value', textAlign: TextAlign.center)),
        IconButton(
          tooltip: 'More',
          icon: const Icon(Icons.add_circle_outline),
          onPressed: value < max ? () => onChanged(value + 1, unit) : null,
        ),
        DropdownButton<TimeUnit>(
          value: unit,
          underline: const SizedBox(),
          items: [
            for (final u in TimeUnit.values)
              DropdownMenuItem(value: u, child: Text(_plural(value, u))),
          ],
          onChanged: (u) => onChanged(value.clamp(min, maxIn(u!)), u),
        ),
      ],
    );
  }
}

/// Reminder on/off and time of day.
class ReminderEditor extends StatelessWidget {
  const ReminderEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final ReminderSettings value;
  final ValueChanged<ReminderSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Remind me to take a photo'),
          subtitle: Text(
            kIsWeb
                ? 'Reminders go into your Google Calendar, so every device notifies you.'
                : 'A gentle notification on your phone. Off any time.',
          ),
          value: value.enabled,
          onChanged: (v) => onChanged(value.copyWith(enabled: v)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          enabled: value.enabled,
          title: const Text('Time of day'),
          subtitle: Text(
            TimeOfDay(hour: value.hour, minute: value.minute).format(context),
          ),
          trailing: const Icon(Icons.alarm),
          onTap: () async {
            final t = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(hour: value.hour, minute: value.minute),
            );
            if (t != null) {
              onChanged(value.copyWith(hour: t.hour, minute: t.minute));
            }
          },
        ),
      ],
    );
  }
}
