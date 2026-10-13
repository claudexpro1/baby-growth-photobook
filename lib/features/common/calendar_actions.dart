import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/providers.dart';
import '../../domain/baby.dart';
import '../../notifications/calendar_status.dart';
import '../../notifications/google_calendar.dart';

/// What happened when the parent asked to update Google Calendar.
class CalendarOutcome {
  const CalendarOutcome(this.message, {this.ok = true, this.details});
  final String message;
  final bool ok;

  /// The raw error, for the "Details" line.
  final String? details;
}

/// Puts the reminders into Google Calendar and always says what happened.
Future<CalendarOutcome> updateGoogleCalendar(WidgetRef ref, Baby baby) async {
  try {
    final r = await ref.read(babiesProvider.notifier).syncGoogleCalendar(baby);
    return CalendarOutcome(
      'Done: ${r.count} reminder${r.count == 1 ? '' : 's'} in "Baby Photobook - ${baby.name}".',
    );
  } catch (e) {
    return CalendarOutcome(
      'Could not update Google Calendar. ${calendarErrorMessage(e)}',
      ok: false,
      details: e.toString(),
    );
  }
}

Future<void> openInGoogleCalendar(Baby baby) {
  final id = baby.googleCalendarId;
  return launchUrl(
    Uri.parse(
      id == null
          ? 'https://calendar.google.com/calendar/u/0/r'
          : openCalendarUrl(id),
    ),
    mode: LaunchMode.externalApplication,
  );
}

/// Small coloured chip: the same words and colours everywhere.
class CalendarChip extends StatelessWidget {
  const CalendarChip({super.key, required this.badge, this.onTap});
  final CalendarBadge badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (badge.tone) {
      BadgeTone.good => (const Color(0xFFDDF3E1), const Color(0xFF1B5E20)),
      BadgeTone.bad => (scheme.errorContainer, scheme.onErrorContainer),
      BadgeTone.warn => (const Color(0xFFFFF0C2), const Color(0xFF7A5200)),
      BadgeTone.quiet => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };
    return Semantics(
      button: onTap != null,
      label: 'Google Calendar: ${badge.label}',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event, size: 14, color: fg),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  badge.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
