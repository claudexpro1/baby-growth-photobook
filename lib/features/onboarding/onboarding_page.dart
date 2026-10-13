import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/baby.dart';
import '../../domain/schedule.dart';
import '../../notifications/reminder_service.dart';
import '../../ui/theme.dart';
import '../common/drive_consent.dart';
import '../common/schedule_editor.dart';

/// Earliest birth date offered: 25 years back covers parents adding an older
/// child's early photos; the schedule does not care about the exact year.
DateTime birthDateFirst(DateTime now) => DateTime(now.year - 25, 1, 1);

/// Latest birth date offered: an expected due date up to ten months ahead, so
/// parents can set up before the birth.
DateTime birthDateLast(DateTime now) =>
    DateTime(now.year, now.month + 10, now.day);

/// Four friendly steps: about the baby, where photos live, how often, reminders.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  int _step = 0;
  final _name = TextEditingController();
  final _place = TextEditingController();
  Gender _gender = Gender.neutral;
  DateTime _birthDate = DateTime.now();
  TimeOfDay _birthTime = TimeOfDay.now();
  StorageMode? _storage;
  bool _connecting = false;
  bool _saving = false;
  var _reminder = const ReminderSettings();
  final List<PhaseDraft> _phases = [
    PhaseDraft(0, TimeUnit.day, 1, TimeUnit.week),
  ];
  String? _error;

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

  String? _validate(int step) {
    switch (step) {
      case 0:
        return _name.text.trim().isEmpty
            ? "Please enter your baby's name."
            : null;
      case 1:
        return _storage == null
            ? 'Please choose where to keep the photos.'
            : null;
      case 2:
        return validatePhases(_birth, _phases);
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
    setState(() => _saving = true);
    if (_reminder.enabled) {
      // Ask for permission at the moment it is needed, with context.
      final granted = await ReminderService.instance
          .requestPermission()
          .catchError((_) => false);
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notifications are off for this app. You can allow them in your phone settings.',
            ),
          ),
        );
      }
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
            phases: _phases.map((p) => p.toPhase()).toList(),
            reminder: _reminder,
            storage: _storage!,
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _chooseDrive() async {
    if (!await ref.read(cloudProvider).isSignedIn() &&
        !(mounted && await showDriveConsent(context))) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      final cloud = ref.read(cloudProvider);
      if (!await cloud.isSignedIn()) await cloud.signIn();
      setState(() => _storage = StorageMode.googleDrive);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = 'We could not connect to Google Drive. Please try again, or keep photos in the app for now.',
      );
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _chooseAppOnly() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Keep photos only in the app?'),
        content: const Text(
          'Your photos will live only inside this app, on this phone. '
          'If the phone is lost or reset, or the app is deleted, the photos are gone.\n\n'
          'Google Drive keeps them safe in your own account. You can connect it later in settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Go back'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Keep in the app only'),
          ),
        ],
      ),
    );
    if (ok == true) setState(() => _storage = StorageMode.appOnly);
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      'About your baby',
      'Where should photos live?',
      'How often?',
      'Reminders',
    ];
    return Theme(
      data: buildTheme(_gender),
      child: Scaffold(
        appBar: AppBar(title: Text(titles[_step])),
        body: SafeArea(
          child: Column(
            children: [
              LinearProgressIndicator(value: (_step + 1) / 4),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    [
                      _aboutStep,
                      _storageStep,
                      _scheduleStep,
                      _reminderStep,
                    ][_step](),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
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
                      onPressed: (_saving || _connecting) ? null : _next,
                      child: Text(_step < 3 ? 'Next' : 'Finish'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
      const SizedBox(height: 20),
      const Text('Girl or boy? (This only picks the colours.)'),
      const SizedBox(height: 8),
      SegmentedButton<Gender>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: Gender.girl, label: Text('Girl')),
          ButtonSegment(value: Gender.boy, label: Text('Boy')),
          ButtonSegment(value: Gender.neutral, label: Text('Skip')),
        ],
        selected: {_gender},
        onSelectionChanged: (s) => setState(() => _gender = s.first),
      ),
      const SizedBox(height: 12),
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
            firstDate: birthDateFirst(DateTime.now()),
            lastDate: birthDateLast(DateTime.now()),
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
      const SizedBox(height: 8),
      TextField(
        controller: _place,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Place of birth (optional)',
        ),
      ),
    ],
  );

  Widget _storageStep() {
    Widget option(
      String title,
      String sub,
      IconData icon,
      bool selected,
      VoidCallback? onTap, {
      Widget? trailing,
    }) => Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          width: selected ? 2 : 1,
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Icon(icon, size: 30),
        title: Text(title),
        subtitle: Text(sub),
        trailing:
            trailing ?? (selected ? const Icon(Icons.check_circle) : null),
        onTap: onTap,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your photos go straight into your own account. '
          'There is no server of ours in between, so nobody else can see them.',
        ),
        const SizedBox(height: 12),
        option(
          'Google Drive',
          'Recommended. Saved in "BabyPhotobook" in your Drive.',
          Icons.cloud_outlined,
          _storage == StorageMode.googleDrive,
          _connecting ? null : _chooseDrive,
          trailing: _connecting
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
        ),
        option(
          'iCloud Drive',
          'Coming soon',
          Icons.cloud_circle_outlined,
          false,
          null,
        ),
        option(
          'Only in this app',
          'Not recommended: lost if the phone is lost.',
          Icons.phone_android,
          _storage == StorageMode.appOnly,
          _chooseAppOnly,
        ),
      ],
    );
  }

  Widget _scheduleStep() => ScheduleEditor(
    phases: _phases,
    onChanged: () => setState(() => _error = null),
  );

  Widget _reminderStep() => ReminderEditor(
    value: _reminder,
    onChanged: (r) => setState(() => _reminder = r),
  );
}
