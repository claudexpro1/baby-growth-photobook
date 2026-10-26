import 'package:flutter/material.dart';

import '../../ui/adaptive_scaffold.dart';
import '../../ui/responsive.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/baby.dart';
import '../../domain/schedule.dart';
import '../../notifications/calendar_status.dart';
import '../../notifications/reminder_service.dart';
import '../../ui/theme.dart';
import '../common/baby_details_form.dart';
import '../common/drive_consent.dart';
import '../baby/baby_page.dart';
import '../common/schedule_editor.dart';

export '../common/baby_details_form.dart' show birthDateFirst, birthDateLast;

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
  bool _driveConnected = false;
  bool _connecting = false;
  bool _saving = false;
  var _reminder = const ReminderSettings();
  // A gentle suggestion to start with: every week, then every month from six
  // months. Every part can be changed in the next steps.
  final List<PhaseDraft> _phases = [
    PhaseDraft(0, TimeUnit.day, 1, TimeUnit.week),
    PhaseDraft(6, TimeUnit.month, 1, TimeUnit.month),
  ];
  final _finish = FinishDraft();
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
        return !_driveConnected
            ? 'Please connect Google Drive to continue. The app needs a Google '
                  'account to keep your photos.'
            : null;
      case 2:
        return validatePhases(_birth, _phases, finish: _finish);
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
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await ref
        .read(babiesProvider.notifier)
        .add(
          Baby(
            id: id,
            name: _name.text.trim(),
            gender: _gender,
            birth: _birth,
            birthPlace: _place.text.trim(),
            phases: _phases.map((p) => p.toPhase()).toList(),
            end: _finish.toAge(),
            reminder: _reminder,
          ),
        );
    if (!mounted) return;
    // Straight to the baby's page: the next steps (reminders in Calendar, the
    // first photo) are right there, so nobody has to find the new baby first.
    final nav = Navigator.of(context);
    nav.pushReplacement(
      MaterialPageRoute(builder: (_) => BabyPage(babyId: id)),
    );
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
      setState(() => _driveConnected = true);
    } catch (_) {
      if (!mounted) return;
      setState(
        () =>
            _error = 'We could not connect to Google Drive. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      'About your baby',
      'Connect Google Drive',
      'How often?',
      'Reminders',
    ];
    return Theme(
      data: themeFor(context, _gender),
      child: AdaptiveScaffold(
        title: titles[_step],
        maxWidth: 720,
        body: _framed(
          context,
          SafeArea(
            child: Column(
              children: [
                LinearProgressIndicator(value: (_step + 1) / 4),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.all(context.isWide ? 32 : 20),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Step ${_step + 1} of 4',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                            ),
                            if (context.isWide)
                              Text(
                                titles[_step],
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                          ],
                        ),
                      ),
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
      ),
    );
  }

  /// On a website the steps sit in a centred card instead of filling the page.
  Widget _framed(BuildContext context, Widget content) {
    if (!context.isWide) return content;
    return LayoutBuilder(
      builder: (context, box) => Center(
        child: SizedBox(
          height: (box.maxHeight - 56).clamp(420.0, 760.0),
          child: Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _aboutStep() => BabyDetailsForm(
    name: _name,
    place: _place,
    gender: _gender,
    birthDate: _birthDate,
    birthTime: _birthTime,
    onGender: (g) => setState(() => _gender = g),
    onBirthDate: (d) => setState(() => _birthDate = d),
    onBirthTime: (t) => setState(() => _birthTime = t),
  );

  Widget _storageStep() {
    final scheme = Theme.of(context).colorScheme;
    final connected = _driveConnected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          margin: EdgeInsets.zero,
          color: scheme.primaryContainer.withValues(alpha: 0.5),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Baby Photobook needs a Google account. Your photos are '
                    'saved in your own Google Drive, and reminders go into your '
                    'own Google Calendar. Without connecting Google Drive the '
                    'app cannot keep your photos, so it cannot be used.',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Your photos go straight into your own account. '
          'There is no server of ours in between, so nobody else can see them.',
        ),
        const SizedBox(height: 20),
        if (connected)
          Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: scheme.primary, width: 2),
            ),
            child: const ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: Icon(Icons.check_circle, size: 30),
              title: Text('Google Drive is connected'),
              subtitle: Text(
                'Photos will be saved in "BabyPhotobook" in your Drive.',
              ),
            ),
          )
        else
          FilledButton.icon(
            onPressed: _connecting ? null : _chooseDrive,
            icon: _connecting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_outlined),
            label: const Text('Connect Google Drive'),
          ),
      ],
    );
  }

  Widget _scheduleStep() => ScheduleEditor(
    phases: _phases,
    birth: _birth,
    finish: _finish,
    onChanged: () => setState(() => _error = null),
  );

  Widget _reminderStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ReminderEditor(
        value: _reminder,
        onChanged: (r) => setState(() => _reminder = r),
      ),
      if (useGoogleCalendar && _reminder.enabled)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Next, on your baby\'s page, one tap puts the reminders into your '
            'Google Calendar. Everything here can be changed later in Settings.',
          ),
        ),
    ],
  );
}
