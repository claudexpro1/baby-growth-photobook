import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/baby.dart';
import '../../notifications/reminder_service.dart';
import '../../ui/theme.dart';
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
    _reminder = _baby.reminder;
    _gender = _baby.gender;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final err = _name.text.trim().isEmpty
        ? "Please enter your baby's name."
        : validatePhases(_baby.birth, _phases);
    setState(() => _error = err);
    if (err != null) return;
    if (_reminder.enabled && !_baby.reminder.enabled) {
      await ReminderService.instance.requestPermission().catchError(
        (_) => false,
      );
    }
    await ref
        .read(babiesProvider.notifier)
        .updateBaby(
          _baby.copyWith(
            name: _name.text.trim(),
            gender: _gender,
            phases: _phases.map((p) => p.toPhase()).toList(),
            reminder: _reminder,
          ),
        );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Remove ${_baby.name}?'),
        content: Text(
          _baby.driveFolderId != null
              ? 'This removes ${_baby.name} and the photos cached on this phone. '
                    'The photos already in your Google Drive folder are not deleted.'
              : 'This removes ${_baby.name} and all photos stored in this app. '
                    'Photos kept only in the app cannot be recovered.',
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
    await ref.read(babiesProvider.notifier).remove(_baby);
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildTheme(_gender),
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
              onChanged: () => setState(() => _error = null),
            ),
            const SizedBox(height: 16),
            Text('Reminders', style: Theme.of(context).textTheme.titleMedium),
            ReminderEditor(
              value: _reminder,
              onChanged: (r) => setState(() => _reminder = r),
            ),
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
