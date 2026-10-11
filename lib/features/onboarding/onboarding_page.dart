import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/baby.dart';
import '../../domain/schedule.dart';

/// Four steps: about the baby, where photos live, the schedule, reminders.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _EditablePhase {
  _EditablePhase(this.startValue, this.startUnit, this.every, this.unit);
  int startValue;
  TimeUnit startUnit;
  int every;
  TimeUnit unit;

  Phase toPhase() => Phase(
    start: Age(startValue, startUnit),
    frequency: Frequency(every, unit),
  );
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  int _step = 0;
  final _name = TextEditingController();
  final _place = TextEditingController();
  Gender _gender = Gender.neutral;
  DateTime _birthDate = DateTime.now();
  TimeOfDay _birthTime = TimeOfDay.now();
  StorageMode? _storage;
  var _reminder = const ReminderSettings();
  final List<_EditablePhase> _phases = [
    _EditablePhase(0, TimeUnit.day, 1, TimeUnit.week),
  ];
  String? _error;

  static const _presets = <String, List<List<Object>>>{
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

  @override
  void dispose() {
    _name.dispose();
    _place.dispose();
    super.dispose();
  }

  DateTime get _birth => DateTime(
    _birthDate.year,
    _birthDate.month,
    _birthDate.day,
    _birthTime.hour,
    _birthTime.minute,
  );

  List<Phase> get _phaseList => _phases.map((p) => p.toPhase()).toList();

  String? _validate(int step) {
    switch (step) {
      case 0:
        return _name.text.trim().isEmpty
            ? "Please enter the baby's name."
            : null;
      case 1:
        return _storage == null
            ? 'Please choose where to keep the photos.'
            : null;
      case 2:
        try {
          PhotoSchedule(_birth, _phaseList);
          return null;
        } on ArgumentError {
          return 'Each phase must start later than the one before it.';
        }
    }
    return null;
  }

  Future<void> _next() async {
    final err = _validate(_step);
    setState(() => _error = err);
    if (err != null) return;
    if (_step < 3) {
      setState(() => _step++);
      return;
    }
    await ref
        .read(babiesProvider.notifier)
        .add(
          Baby(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            name: _name.text.trim(),
            gender: _gender,
            birth: _birth,
            birthPlace: _place.text.trim(),
            phases: _phaseList,
            reminder: _reminder,
            storage: _storage!,
          ),
        );
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _chooseStorage(StorageMode mode) async {
    if (mode == StorageMode.appOnly) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Keep photos only in the app?'),
          content: const Text(
            'Your photos will live only inside this app on this phone. '
            'If the phone is lost, reset, or the app is deleted, the photos '
            'are gone. Connecting Google Drive or iCloud keeps them safe in '
            'your own account. You can connect later in Settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Go back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Keep in the app only'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _storage = mode);
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      'About the baby',
      'Where photos live',
      'Photo schedule',
      'Reminders',
    ];
    return Scaffold(
      appBar: AppBar(title: Text('${titles[_step]} (${_step + 1}/4)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          [_aboutStep, _storageStep, _scheduleStep, _reminderStep][_step](),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              if (_step > 0)
                TextButton(
                  onPressed: () => setState(() {
                    _step--;
                    _error = null;
                  }),
                  child: const Text('Back'),
                ),
              const Spacer(),
              FilledButton(
                onPressed: _next,
                child: Text(_step < 3 ? 'Next' : 'Finish'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _aboutStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        controller: _name,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Name'),
      ),
      const SizedBox(height: 16),
      SegmentedButton<Gender>(
        segments: const [
          ButtonSegment(value: Gender.girl, label: Text('Girl')),
          ButtonSegment(value: Gender.boy, label: Text('Boy')),
          ButtonSegment(
            value: Gender.neutral,
            label: Text('Prefer not to say'),
          ),
        ],
        selected: {_gender},
        onSelectionChanged: (s) => setState(() => _gender = s.first),
      ),
      const SizedBox(height: 16),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Birth date'),
        subtitle: Text(
          MaterialLocalizations.of(context).formatFullDate(_birthDate),
        ),
        trailing: const Icon(Icons.calendar_today),
        onTap: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: _birthDate,
            firstDate: DateTime(2000),
            lastDate: DateTime.now().add(const Duration(days: 60)),
          );
          if (d != null) setState(() => _birthDate = d);
        },
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Birth time'),
        subtitle: Text(_birthTime.format(context)),
        trailing: const Icon(Icons.schedule),
        onTap: () async {
          final t = await showTimePicker(
            context: context,
            initialTime: _birthTime,
          );
          if (t != null) setState(() => _birthTime = t);
        },
      ),
      TextField(
        controller: _place,
        decoration: const InputDecoration(labelText: 'Birth place (optional)'),
      ),
    ],
  );

  Widget _storageStep() {
    Widget option(StorageMode m, String title, String sub, IconData icon) =>
        Card(
          child: ListTile(
            leading: Icon(icon),
            title: Text(title),
            subtitle: Text(sub),
            trailing: _storage == m ? const Icon(Icons.check_circle) : null,
            selected: _storage == m,
            onTap: () => _chooseStorage(m),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your photos go straight into your own account. '
          'There is no server of ours in between.',
        ),
        const SizedBox(height: 12),
        option(
          StorageMode.googleDrive,
          'Google Drive',
          "Saved in a folder in your Drive",
          Icons.cloud_outlined,
        ),
        if (Platform.isIOS)
          option(
            StorageMode.iCloud,
            'iCloud Drive',
            'Saved in your iCloud Drive',
            Icons.cloud_circle_outlined,
          ),
        option(
          StorageMode.appOnly,
          'Only in this app',
          'Not recommended: photos are lost if you lose the phone',
          Icons.phone_android,
        ),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Sign-in to Drive/iCloud arrives in an upcoming update; '
            'your choice is saved now.',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
      ],
    );
  }

  Widget _scheduleStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'You decide how often to take a photo, and it can change over '
        'time. At most one photo per day. The last phase continues onwards.',
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: [
          for (final e in _presets.entries)
            ActionChip(
              label: Text(e.key),
              onPressed: () => setState(() {
                _phases
                  ..clear()
                  ..addAll(
                    e.value.map(
                      (p) => _EditablePhase(
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
      for (var i = 0; i < _phases.length; i++) _phaseCard(i),
      TextButton.icon(
        icon: const Icon(Icons.add),
        label: const Text('Add phase'),
        onPressed: () => setState(() {
          final last = _phases.last;
          _phases.add(
            _EditablePhase(
              last.startValue + 1,
              last.startUnit == TimeUnit.day ? TimeUnit.month : last.startUnit,
              last.every,
              last.unit,
            ),
          );
        }),
      ),
    ],
  );

  Widget _phaseCard(int i) {
    final p = _phases[i];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Phase ${i + 1}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                if (_phases.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() => _phases.removeAt(i)),
                  ),
              ],
            ),
            if (i == 0)
              const Text('Starts at birth')
            else
              _amountRow(
                'Starts at age',
                p.startValue,
                p.startUnit,
                0,
                (v, u) => setState(() {
                  p.startValue = v;
                  p.startUnit = u;
                }),
              ),
            _amountRow(
              'Photo every',
              p.every,
              p.unit,
              1,
              (v, u) => setState(() {
                p.every = v;
                p.unit = u;
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountRow(
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
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > min ? () => onChanged(value - 1, unit) : null,
        ),
        Text('$value'),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => onChanged(value + 1, unit),
        ),
        DropdownButton<TimeUnit>(
          value: unit,
          items: [
            for (final u in TimeUnit.values)
              DropdownMenuItem(
                value: u,
                child: Text('${u.name}${value == 1 ? '' : 's'}'),
              ),
          ],
          onChanged: (u) => onChanged(value, u!),
        ),
      ],
    );
  }

  Widget _reminderStep() => Column(
    children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Remind me to take a photo'),
        subtitle: const Text('You can change or turn this off any time.'),
        value: _reminder.enabled,
        onChanged: (v) =>
            setState(() => _reminder = _reminder.copyWith(enabled: v)),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        enabled: _reminder.enabled,
        title: const Text('Time of day'),
        subtitle: Text(
          TimeOfDay(
            hour: _reminder.hour,
            minute: _reminder.minute,
          ).format(context),
        ),
        trailing: const Icon(Icons.alarm),
        onTap: () async {
          final t = await showTimePicker(
            context: context,
            initialTime: TimeOfDay(
              hour: _reminder.hour,
              minute: _reminder.minute,
            ),
          );
          if (t != null) {
            setState(
              () => _reminder = _reminder.copyWith(
                hour: t.hour,
                minute: t.minute,
              ),
            );
          }
        },
      ),
    ],
  );
}
