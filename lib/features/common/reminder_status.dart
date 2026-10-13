import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../notifications/reminder_service.dart';

/// Tells the parent, in words, whether reminders will actually reach them on
/// this device, with a button to fix or test it.
class ReminderStatus extends ConsumerStatefulWidget {
  const ReminderStatus({
    super.key,
    required this.babyId,
    required this.enabled,
  });
  final String babyId;

  /// The reminder switch as currently shown (may not be saved yet).
  final bool enabled;

  @override
  ConsumerState<ReminderStatus> createState() => _ReminderStatusState();
}

class _ReminderStatusState extends ConsumerState<ReminderStatus> {
  bool _busy = false;
  bool? _allowed; // native only

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (kIsWeb) return;
    final ok = await ReminderService.instance.notificationsAllowed().catchError(
      (_) => false,
    );
    if (mounted) setState(() => _allowed = ok);
  }

  void _say(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _addToCalendar() async {
    setState(() => _busy = true);
    try {
      final baby = ref
          .read(babiesProvider)
          .value!
          .firstWhere((b) => b.id == widget.babyId);
      await ref.read(babiesProvider.notifier).syncGoogleCalendar(baby);
      _say('Reminders are in your Google Calendar.');
    } catch (_) {
      _say(
        'Could not add the reminders. Allow Google Calendar access and try again.',
      );
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _test(String name) async {
    final ok = await ReminderService.instance.requestPermission().catchError(
      (_) => false,
    );
    await _refresh();
    if (!ok) {
      _say('Notifications are blocked. Allow them in your phone settings.');
      return;
    }
    await ReminderService.instance.sendTest(name);
  }

  @override
  Widget build(BuildContext context) {
    final baby = ref
        .watch(babiesProvider)
        .value
        ?.where((b) => b.id == widget.babyId)
        .firstOrNull;
    if (baby == null) return const SizedBox();
    final scheme = Theme.of(context).colorScheme;

    late final IconData icon;
    late final String text;
    Widget? action;
    var good = false;
    if (!widget.enabled) {
      icon = Icons.notifications_off_outlined;
      text = 'Reminders are off.';
    } else if (kIsWeb) {
      if (baby.googleCalendarId != null) {
        good = true;
        icon = Icons.event_available;
        text =
            'Reminders are in your Google Calendar ("Baby Photobook - ${baby.name}"). '
            'Google Calendar notifies you on every device where it is installed.';
        action = TextButton(
          onPressed: _busy ? null : _addToCalendar,
          child: const Text('Update calendar'),
        );
      } else {
        icon = Icons.event_busy;
        text =
            'Not in your calendar yet, so nothing will remind you. A web page cannot '
            'send reminders by itself, so this app uses Google Calendar.';
        action = FilledButton.tonal(
          onPressed: _busy ? null : _addToCalendar,
          child: const Text('Add to Google Calendar'),
        );
      }
    } else if (_allowed == null) {
      icon = Icons.notifications_none;
      text = 'Checking notifications...';
    } else if (_allowed!) {
      good = true;
      icon = Icons.notifications_active_outlined;
      text = 'Notifications are on for this phone.';
      action = TextButton(
        onPressed: () => _test(baby.name),
        child: const Text('Send test reminder'),
      );
    } else {
      icon = Icons.notifications_off_outlined;
      text = 'Notifications are blocked for this app. Allow them in your phone settings.';
      action = TextButton(
        onPressed: () => _test(baby.name),
        child: const Text('Ask again / send test'),
      );
    }
    return Card(
      color: good
          ? scheme.primaryContainer.withValues(alpha: 0.5)
          : scheme.errorContainer.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon),
                const SizedBox(width: 12),
                Expanded(child: Text(text)),
              ],
            ),
            if (action != null)
              Align(alignment: Alignment.centerRight, child: action),
          ],
        ),
      ),
    );
  }
}
