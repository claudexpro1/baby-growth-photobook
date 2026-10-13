import 'dart:async';

import 'package:flutter/material.dart';

import '../common/drive_consent.dart';
import '../common/photo_image.dart';
import 'welcome_view.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/providers.dart';
import '../../domain/age_label.dart';
import '../../domain/baby.dart';
import '../../notifications/calendar_status.dart';
import '../common/calendar_actions.dart';
import '../../ui/theme.dart';
import '../baby/baby_page.dart';
import '../baby/edit_baby_page.dart';
import '../../notifications/google_calendar.dart' show calendarErrorMessage;
import '../onboarding/onboarding_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    // Top up the rolling reminder window every time the app opens.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(babiesProvider.future);
      ref.read(babiesProvider.notifier).reschedule();
      unawaited(ref.read(calendarStatusProvider.notifier).checkAll());
    });
  }

  bool _restoring = false;

  Future<void> _restore() async {
    if (!await ref.read(cloudProvider).isSignedIn() &&
        !(mounted && await showDriveConsent(context))) {
      return;
    }
    if (!mounted) return;
    setState(() => _restoring = true);
    String message;
    var found = 0;
    try {
      found = await ref.read(babiesProvider.notifier).restoreFromDrive();
      message = found == 0
          ? 'No new babies found in your Google Drive.'
          : (found == 1
                ? 'Restored 1 baby from Google Drive.'
                : 'Restored $found babies from Google Drive.');
    } catch (_) {
      message = 'Could not reach Google Drive. Please check your connection and try again.';
    }
    if (!mounted) return;
    setState(() => _restoring = false);
    // Found babies: the list is already on screen, a short note is enough.
    // Nothing found: say it clearly, so the start screen does not look stuck.
    if (found == 0) {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Nothing to bring back'),
          content: Text(
            message.startsWith('No new')
                ? 'We looked in the "BabyPhotobook" folder of the Google account you chose and found no babies that are not already here.\n\nIf you expected some, check you chose the same Google account you used before.'
                : message,
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _disconnectDrive() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Disconnect Google Drive?'),
        content: const Text(
          'The app signs out of Google Drive on this device and stops uploading. '
          'Your photos stay in your Drive and on this device.\n\n'
          'To take the access away completely, also remove Baby Photobook at '
          'myaccount.google.com/permissions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    String message;
    try {
      await ref.read(cloudProvider).signOut();
      message = 'Google Drive is disconnected on this device.';
    } catch (_) {
      message = 'Could not disconnect. Please try again.';
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    await launchUrl(
      Uri.parse('https://myaccount.google.com/permissions'),
      mode: LaunchMode.externalApplication,
    ).catchError((_) => false);
  }

  Future<void> _deleteAll() async {
    final babies = ref.read(babiesProvider).value ?? [];
    final waiting = <String>[];
    for (final b in babies.where((b) => b.storage == StorageMode.googleDrive)) {
      final n = (ref.read(photosProvider(b.id)).value ?? [])
          .where((p) => !p.synced)
          .length;
      if (n > 0) waiting.add('${b.name} ($n)');
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete everything on this device?'),
        content: Text(
          'This removes all babies, their reminders and the photos kept on this '
          'device, switches off any share links and signs out of Google Drive.\n\n'
          'Photos already in your Google Drive are NOT deleted: delete the '
          '"BabyPhotobook" folder in Drive yourself if you want those gone.'
          '${waiting.isEmpty ? '' : '\n\nNot uploaded yet, so these would be lost: ${waiting.join(', ')}. Cancel and sync first.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(c).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      for (final b in List<Baby>.of(babies)) {
        await ref.read(babiesProvider.notifier).remove(b);
      }
      await ref.read(cloudProvider).signOut().catchError((_) {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Everything on this device is deleted.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not switch off a share link, so nothing more was deleted. Check your connection and try again.',
            ),
          ),
        );
      }
    }
  }

  void _add() =>
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const OnboardingPage()));

  @override
  Widget build(BuildContext context) {
    final babies = ref.watch(babiesProvider);
    final welcome = babies.hasValue && babies.value!.isEmpty;
    return Scaffold(
      appBar: welcome
          ? null
          : AppBar(
              title: const Text('Baby Photobook'),
              actions: [
                PopupMenuButton<String>(
                  onSelected: (v) => switch (v) {
                    'restore' => _restore(),
                    'disconnect' => _disconnectDrive(),
                    _ => _deleteAll(),
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'restore',
                      enabled: !_restoring,
                      child: const Text('Bring back babies from Google Drive'),
                    ),
                    const PopupMenuItem(
                      value: 'disconnect',
                      child: Text('Disconnect Google Drive'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete all data on this device'),
                    ),
                  ],
                ),
              ],
            ),
      floatingActionButton: babies.hasValue && babies.value!.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('Add a baby'),
            )
          : null,
      body: babies.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            const Center(child: Text('Could not load your babies.')),
        data: (list) => list.isEmpty
            ? WelcomeView(onStart: _add, onRestore: _restore, busy: _restoring)
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                children: [for (final b in list) _BabyCard(b)],
              ),
      ),
    );
  }
}

class _BabyCard extends ConsumerWidget {
  const _BabyCard(this.baby);
  final Baby baby;

  /// Tapping the chip checks the calendar and shows the answer.
  Future<void> _openCalendar(BuildContext context, WidgetRef ref) async {
    if (baby.googleCalendarId == null || !baby.reminder.enabled) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => EditBabyPage(babyId: baby.id)));
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      final c = await ref
          .read(calendarStatusProvider.notifier)
          .check(baby, prompt: true);
      final badge = calendarBadge(baby, c);
      messenger.showSnackBar(SnackBar(content: Text(badge.detail)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(calendarErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(photosProvider(baby.id)).value ?? [];
    final today = DateTime.now();
    final todayUtc = DateTime.utc(today.year, today.month, today.day);
    final dueToday =
        baby.schedule.dueDates(todayUtc, todayUtc).isNotEmpty &&
        !photos.any((p) => p.date == todayUtc);
    final next = baby.schedule.nextDueAfter(todayUtc);
    final loc = MaterialLocalizations.of(context);
    final waiting = photos.where((p) => !p.synced).length;
    return Theme(
      data: themeFor(context, baby.gender),
      child: Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          return Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => BabyPage(babyId: baby.id)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: 84,
                        height: 84,
                        child: photos.isEmpty
                            ? ColoredBox(
                                color: scheme.primaryContainer,
                                child: Icon(
                                  Icons.child_care,
                                  size: 40,
                                  color: scheme.primary,
                                ),
                              )
                            : PhotoImage(photos.last, cacheWidth: 250),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            baby.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(ageLabel(baby.birth, DateTime.now())),
                          const SizedBox(height: 6),
                          if (dueToday)
                            Chip(
                              label: const Text("Today's photo"),
                              backgroundColor: scheme.primaryContainer,
                              visualDensity: VisualDensity.compact,
                            )
                          else
                            Text(
                              next == null
                                  ? 'Finish line reached ♥'
                                  : 'Next photo: ${loc.formatMediumDate(next)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          if (useGoogleCalendar)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: CalendarChip(
                                badge: calendarBadge(
                                  baby,
                                  ref
                                      .watch(calendarStatusProvider)
                                      .value?[baby.id],
                                ),
                                onTap: () => _openCalendar(context, ref),
                              ),
                            ),
                          if (baby.storage == StorageMode.appOnly)
                            Text(
                              'Only on this phone',
                              style: TextStyle(
                                color: scheme.error,
                                fontSize: 12,
                              ),
                            )
                          else if (waiting > 0)
                            Text(
                              '$waiting waiting to upload',
                              style: const TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
