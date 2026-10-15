import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/photo_library.dart';
import '../../data/providers.dart';
import '../../domain/baby.dart';
import '../../notifications/calendar_status.dart';
import '../../notifications/reminder_service.dart';
import '../common/reminder_status.dart';
import '../common/schedule_editor.dart';

/// "Backup and reminders": where the photos are kept (Google Drive) and how
/// the reminders reach the parent (Google Calendar), each as one short line
/// that opens in place. A step that still needs doing is shown open, with its
/// button, so a new parent sees what to do next without searching menus.
class BackupAndReminders extends ConsumerWidget {
  const BackupAndReminders({
    super.key,
    required this.baby,
    required this.photos,
    required this.syncing,
    required this.onSync,
    required this.onConnect,
    required this.onReconnect,
    required this.onUpdateCalendar,
    required this.onSettings,
  });

  final Baby baby;
  final List<PhotoEntry> photos;
  final bool syncing;
  final VoidCallback onSync;
  final VoidCallback onConnect;
  final VoidCallback onReconnect;

  /// Puts the reminders into Google Calendar (runs inside a tap).
  final VoidCallback onUpdateCalendar;
  final VoidCallback onSettings;

  Uri _folderUrl(String id) =>
      Uri.parse('https://drive.google.com/drive/folders/$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final reconnect = ref.watch(driveReconnectProvider);
    final last = ref.watch(calendarStatusProvider).value?[baby.id];
    final badge = calendarBadge(baby, last);
    final onDrive = baby.storage == StorageMode.googleDrive;
    final waiting = photos.where((p) => !p.synced).length;

    final driveTodo = !onDrive || reconnect;
    final calendarTodo =
        useGoogleCalendar &&
        baby.reminder.enabled &&
        baby.googleCalendarId == null;
    final todo = (driveTodo ? 1 : 0) + (calendarTodo ? 1 : 0);

    final rows = <Widget>[
      if (!onDrive)
        _AttentionRow(
          icon: Icons.cloud_off_outlined,
          title: 'Photos are only on this device',
          text:
              'If this browser\'s data is cleared or the device is lost, '
              'they are lost too. Connect Google Drive to keep them safe in '
              'your own account.',
          button: 'Connect Google Drive',
          onPressed: onConnect,
          color: scheme.errorContainer.withValues(alpha: 0.5),
        )
      else if (reconnect)
        _AttentionRow(
          icon: Icons.cloud_sync_outlined,
          title: 'Reconnect to Google Drive',
          text: waiting == 0
              ? 'Google signs you out about every hour. One tap and your '
                    'photos sync again.'
              : '$waiting photo${waiting == 1 ? ' is' : 's are'} safe on this '
                    'device and wait to upload. Tap to reconnect.',
          button: 'Reconnect',
          onPressed: onReconnect,
          color: const Color(0xFFFFF0C2),
          foreground: const Color(0xFF5C3F00),
        )
      else
        _driveRow(context, waiting),
      if (calendarTodo)
        _AttentionRow(
          icon: Icons.event_outlined,
          title: 'Add reminders to your Google Calendar',
          text:
              'A web page cannot send reminders by itself, so they go into a '
              'calendar of your own. Google Calendar then notifies you on '
              'every device.',
          button: 'Add reminders',
          onPressed: onUpdateCalendar,
          color: scheme.primaryContainer.withValues(alpha: 0.5),
        )
      else
        _remindersRow(context, ref, badge),
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (todo > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                todo == 1 ? 'One step left' : 'Two steps left',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget _driveRow(BuildContext context, int waiting) {
    final folderId = baby.driveFolderId;
    final title = syncing
        ? 'Saving to Google Drive…'
        : waiting == 0
        ? 'Saved in Google Drive'
        : '$waiting photo${waiting == 1 ? '' : 's'} waiting to upload';
    return ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      leading: Icon(
        waiting == 0 && !syncing
            ? Icons.cloud_done_outlined
            : Icons.cloud_upload_outlined,
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${photos.length} photo${photos.length == 1 ? '' : 's'}'),
      children: [
        Text('Google Drive  ›  BabyPhotobook  ›  ${baby.name}'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open in Drive'),
              onPressed: folderId == null
                  ? null
                  : () => launchUrl(
                      _folderUrl(folderId),
                      mode: LaunchMode.externalApplication,
                    ),
            ),
            OutlinedButton.icon(
              icon: syncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: const Text('Sync now'),
              onPressed: syncing ? null : onSync,
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (folderId == null)
          const Text('The folder is created with your first photo.'),
        Text(
          'Please do not rename, move or delete this folder or the files in '
          'it: the app needs them to show and restore your photos. Photos you '
          'add to the folder by hand are not shown in the app; add photos '
          'from the app so they are numbered and dated.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  String _remindersTitle(BuildContext context, CalendarBadge badge) {
    final r = baby.reminder;
    if (!r.enabled) return 'Reminders are off';
    final time = TimeOfDay(hour: r.hour, minute: r.minute).format(context);
    return useGoogleCalendar
        ? 'Reminders at $time  ·  ${badge.label}'
        : 'Reminders at $time';
  }

  Future<void> _apply(WidgetRef ref, ReminderSettings r) async {
    final turningOn = r.enabled && !baby.reminder.enabled;
    if (turningOn && !useGoogleCalendar) {
      await ReminderService.instance.requestPermission().catchError(
        (_) => false,
      );
    }
    await ref
        .read(babiesProvider.notifier)
        .updateBaby(baby.copyWith(reminder: r));
    // The change is a tap, so Google may ask for permission now.
    if (useGoogleCalendar && (turningOn || baby.googleCalendarId != null)) {
      onUpdateCalendar();
    }
  }

  Widget _remindersRow(
    BuildContext context,
    WidgetRef ref,
    CalendarBadge badge,
  ) {
    final bad = useGoogleCalendar && badge.tone == BadgeTone.bad;
    return ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      initiallyExpanded: bad,
      leading: Icon(
        baby.reminder.enabled
            ? Icons.event_available_outlined
            : Icons.notifications_off_outlined,
      ),
      title: Text(
        _remindersTitle(context, badge),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        baby.reminder.enabled && useGoogleCalendar
            ? 'Google Calendar'
            : baby.reminder.enabled
            ? 'Notifications on this phone'
            : 'Tap to turn on',
      ),
      children: [
        ReminderEditor(value: baby.reminder, onChanged: (r) => _apply(ref, r)),
        ReminderStatus(
          babyId: baby.id,
          enabled: baby.reminder.enabled,
          embedded: true,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Change the photo schedule in Settings'),
            onPressed: onSettings,
          ),
        ),
      ],
    );
  }
}

/// A step that is not done yet: always open, with its one button.
class _AttentionRow extends StatelessWidget {
  const _AttentionRow({
    required this.icon,
    required this.title,
    required this.text,
    required this.button,
    required this.onPressed,
    required this.color,
    this.foreground,
  });
  final IconData icon;
  final String title;
  final String text;
  final String button;
  final VoidCallback onPressed;
  final Color color;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: foreground),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: foreground),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(text),
            const SizedBox(height: 10),
            FilledButton(onPressed: onPressed, child: Text(button)),
          ],
        ),
      ),
    );
  }
}
