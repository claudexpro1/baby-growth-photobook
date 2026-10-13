import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/baby.dart';
import '../../notifications/reminder_service.dart';
import '../../ui/theme.dart';
import '../common/reminder_status.dart';
import '../common/schedule_editor.dart';

/// Settings for one baby: name, schedule, reminders, delete.
class EditBabyPage extends ConsumerStatefulWidget {
  const EditBabyPage({super.key, required this.babyId});
  final String babyId;

  @override
  ConsumerState<EditBabyPage> createState() => _EditBabyPageState();
}

class _EditBabyPageState extends ConsumerState<EditBabyPage> {
  late Baby _baby;
  late final TextEditingController _name;
  late List<PhaseDraft> _phases;
  late FinishDraft _finish;
  late ReminderSettings _reminder;
  late Gender _gender;
  String? _error;

  @override
  void initState() {
    super.initState();
    _baby = ref
        .read(babiesProvider)
        .value!
        .firstWhere((b) => b.id == widget.babyId);
    _name = TextEditingController(text: _baby.name);
    _phases = _baby.phases.map(PhaseDraft.from).toList();
    _finish = FinishDraft.from(_baby.end);
    _reminder = _baby.reminder;
    _gender = _baby.gender;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Baby get _current => ref
      .read(babiesProvider)
      .value!
      .firstWhere((b) => b.id == widget.babyId, orElse: () => _baby);

  Future<void> _save() async {
    final err = _name.text.trim().isEmpty
        ? "Please enter your baby's name."
        : validatePhases(_baby.birth, _phases, finish: _finish);
    setState(() => _error = err);
    if (err != null) return;
    if (_reminder.enabled && !_baby.reminder.enabled) {
      final granted = await ReminderService.instance
          .requestPermission()
          .catchError((_) => false);
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notifications are off for this app. Allow them in your phone settings to get reminders.',
            ),
          ),
        );
      }
    }
    await ref
        .read(babiesProvider.notifier)
        .updateBaby(
          _current.copyWith(
            name: _name.text.trim(),
            gender: _gender,
            phases: _phases.map((p) => p.toPhase()).toList(),
            end: _finish.toAge(),
            clearEnd: !_finish.enabled,
            reminder: _reminder,
          ),
        );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final baby = _current;
    final onDrive = baby.storage == StorageMode.googleDrive;
    final photos = ref.read(photosProvider(baby.id)).value ?? [];
    final waiting = photos.where((p) => !p.synced).length;
    if (onDrive && waiting > 0) {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Not all photos are in Drive yet'),
          content: Text(
            '$waiting photo${waiting == 1 ? ' is' : 's are'} still waiting to upload. '
            'Open ${baby.name}\'s page and tap Sync first, so nothing is lost.',
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => Navigator.pop(c),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Remove ${baby.name}?'),
        content: Text(
          [
            if (onDrive)
              'This removes ${baby.name} and the photos cached on this phone. '
                  'The photos already in your Google Drive folder are not deleted.'
            else
              'This removes ${baby.name} and all photos stored in this app. '
                  'Photos kept only in the app cannot be recovered.',
            if (baby.driveSharedFolderId != null)
              'The share link will be switched off.',
          ].join('\n\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(babiesProvider.notifier).remove(baby);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not switch off the share link, so nothing was removed. Check your connection and try again.',
          ),
        ),
      );
      return;
    }
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: themeFor(context, _gender),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          actions: [TextButton(onPressed: _save, child: const Text('Save'))],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 16),
            SegmentedButton<Gender>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: Gender.girl, label: Text('Girl')),
                ButtonSegment(value: Gender.boy, label: Text('Boy')),
                ButtonSegment(value: Gender.neutral, label: Text('Neutral')),
              ],
              selected: {_gender},
              onSelectionChanged: (s) => setState(() => _gender = s.first),
            ),
            const SizedBox(height: 24),
            Text('How often', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ScheduleEditor(
              phases: _phases,
              birth: _baby.birth,
              finish: _finish,
              onChanged: () => setState(() => _error = null),
            ),
            const SizedBox(height: 16),
            Text('Reminders', style: Theme.of(context).textTheme.titleMedium),
            ReminderEditor(
              value: _reminder,
              onChanged: (r) => setState(() => _reminder = r),
            ),
            ReminderStatus(babyId: widget.babyId, enabled: _reminder.enabled),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              label: Text('Remove ${_baby.name}'),
              onPressed: _delete,
            ),
          ],
        ),
      ),
    );
  }
}
