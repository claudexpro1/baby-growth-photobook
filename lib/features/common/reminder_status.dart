import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/baby.dart';
import '../../notifications/google_calendar.dart';
import 'calendar_actions.dart';
import '../../notifications/calendar_status.dart';
import '../../notifications/reminder_service.dart';

/// Tells the parent, in words, whether reminders will actually reach them on
/// this device, with a button to fix or test it.
class ReminderStatus extends ConsumerStatefulWidget {
  const ReminderStatus({
    super.key,
    required this.babyId,
    required this.enabled,
    this.unsaved = false,
  });
  final String babyId;

  /// Settings were changed here but not saved yet: the calendar would still
  /// get the old schedule, so updating waits for Save.
  final bool unsaved;

  /// The reminder switch as currently shown (may not be saved yet).
  final bool enabled;

  @override
  ConsumerState<ReminderStatus> createState() => _ReminderStatusState();
}

class _ReminderStatusState extends ConsumerState<ReminderStatus> {
  bool _busy = false;
  bool? _allowed; // native only
  CalendarOutcome? _outcome;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    if (useGoogleCalendar) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
  }

  /// Looks in Google Calendar when Settings opens (never opens Google's window).
  Future<void> _check({bool prompt = false}) async {
    final baby = _baby;
    if (baby == null || baby.googleCalendarId == null || _checking) return;
    setState(() => _checking = true);
    try {
      final c = await ref
          .read(calendarStatusProvider.notifier)
          .check(baby, prompt: prompt);
      if (c == null && prompt == false) _outcome = null;
    } catch (e) {
      _outcome = CalendarOutcome(
        'Could not check Google Calendar. ${calendarErrorMessage(e)}',
        ok: false,
        details: e.toString(),
      );
    }
    if (mounted) setState(() => _checking = false);
  }

  Baby? get _baby => ref
      .read(babiesProvider)
      .value
      ?.where((b) => b.id == widget.babyId)
      .firstOrNull;

  Future<void> _refresh() async {
    if (useGoogleCalendar) return;
    final ok = await ReminderService.instance.notificationsAllowed().catchError(
      (_) => false,
    );
    if (mounted) setState(() => _allowed = ok);
  }

  void _say(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _addToCalendar() async {
    final baby = _baby;
    if (baby == null) return;
    setState(() {
      _busy = true;
      _outcome = null;
    });
    final r = await updateGoogleCalendar(ref, baby);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _outcome = r;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(r.message)));
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

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} h ago';
    return '${d.inDays} day${d.inDays == 1 ? '' : 's'} ago';
  }

  String _when(BuildContext context, DateTime t) {
    final loc = MaterialLocalizations.of(context);
    return '${loc.formatMediumDate(t)} ${loc.formatTimeOfDay(TimeOfDay.fromDateTime(t))}';
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
    } else if (useGoogleCalendar) {
      final last = ref.watch(calendarStatusProvider).value?[baby.id];
      final badge = calendarBadge(baby, last);
      good = badge.tone == BadgeTone.good;
      icon = switch (badge.tone) {
        BadgeTone.good => Icons.event_available,
        BadgeTone.warn => Icons.event_note,
        _ => Icons.event_busy,
      };
      final lines = <String>[
        badge.detail,
        if (good && last?.next != null)
          'Next reminder: ${_when(context, last!.next!)}.',
        if (good)
          'Google Calendar notifies you on every device where it is installed.',
        if (badge.tone == BadgeTone.bad)
          'Tap "Fix it" to make a new calendar with the reminders.',
        if (badge.tone == BadgeTone.quiet) 'A web page cannot send reminders by itself, so this app uses Google Calendar.',
        if (last != null && baby.googleCalendarId != null)
          'Last checked ${_ago(last.checkedAt)}.',
      ];
      text = lines.join('\n');
      final fix = badge.tone == BadgeTone.bad;
      action = Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        children: [
          if (baby.googleCalendarId != null)
            TextButton(
              onPressed: () => openInGoogleCalendar(baby),
              child: const Text('Open in Google Calendar'),
            ),
          if (baby.googleCalendarId != null && badge.tone != BadgeTone.bad)
            TextButton(
              onPressed: _busy || _checking ? null : () => _check(prompt: true),
              child: const Text('Check now'),
            ),
          fix || baby.googleCalendarId == null
              ? FilledButton.tonal(
                  onPressed: _busy || widget.unsaved ? null : _addToCalendar,
                  child: Text(fix ? 'Fix it' : 'Add to Google Calendar'),
                )
              : TextButton(
                  onPressed: _busy || widget.unsaved ? null : _addToCalendar,
                  child: const Text('Update calendar'),
                ),
        ],
      );
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
            if (widget.unsaved && useGoogleCalendar)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'You changed something here. Tap Save: Google Calendar then '
                  'updates by itself.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            if (_busy || _checking)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
            if (_outcome != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _outcome!.message,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _outcome!.ok ? null : scheme.error,
                  ),
                ),
              ),
            if (_outcome?.details != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Details: ${_outcome!.details}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (action != null)
              Align(alignment: Alignment.centerRight, child: action),
          ],
        ),
      ),
    );
  }
}
