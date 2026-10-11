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

/// Returns an error message if the phases cannot form a schedule, else null.
String? validatePhases(DateTime birth, List<PhaseDraft> drafts) {
  try {
    PhotoSchedule(birth, drafts.map((d) => d.toPhase()).toList());
    return null;
  } on ArgumentError {
    return 'Each phase must start later than the one before it.';
  }
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
  const ScheduleEditor({super.key, required this.phases, this.onChanged});
  final List<PhaseDraft> phases;
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

  String _summary() {
    final parts = <String>[];
    for (var i = 0; i < _p.length; i++) {
      final p = _p[i];
      final from = i == 0
          ? 'From birth'
          : 'From ${p.startValue} ${_plural(p.startValue, p.startUnit)}';
      final every = p.every == 1
          ? switch (p.unit) {
              TimeUnit.day => 'every day',
              TimeUnit.week => 'every week',
              TimeUnit.month => 'every month',
            }
          : 'every ${p.every} ${_plural(p.every, p.unit)}';
      parts.add('$from: $every');
    }
    return parts.join('\n');
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
          onPressed: () => _change(() {
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
        Card(
          color: Theme.of(context).colorScheme.primaryContainer
              .withValues(alpha: 0.4),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text('In short:\n${_summary()}'),
          ),
        ),
      ],
    );
  }

  Widget _card(int i) {
    final p = _p[i];
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
            if (i > 0)
              _row(
                'Starts at age',
                p.startValue,
                p.startUnit,
                0,
                (v, u) => _change(() {
                  p.startValue = v;
                  p.startUnit = u;
                }),
              ),
            _row(
              'A photo every',
              p.every,
              p.unit,
              1,
              (v, u) => _change(() {
                p.every = v;
                p.unit = u;
              }),
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
    void Function(int, TimeUnit) onChanged,
  ) {
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
          onPressed: () => onChanged(value + 1, unit),
        ),
        DropdownButton<TimeUnit>(
          value: unit,
          underline: const SizedBox(),
          items: [
            for (final u in TimeUnit.values)
              DropdownMenuItem(value: u, child: Text(_plural(value, u))),
          ],
          onChanged: (u) => onChanged(value, u!),
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
                ? 'Reminders go into your Google Calendar, so every device notifies you. Use "Add reminders to Google Calendar" in the baby\'s menu after setup.'
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
