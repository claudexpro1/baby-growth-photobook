import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../common/drive_consent.dart';
import '../common/install_info.dart';
import '../common/install_sheet.dart';
import 'welcome_view.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/baby.dart';
import '../../notifications/calendar_status.dart';
import '../../ui/adaptive_scaffold.dart';
import '../../ui/responsive.dart';
import '../common/baby_avatar.dart';
import '../common/calendar_actions.dart';
import '../../ui/theme.dart';
import '../baby/baby_page.dart';
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

  Future<void> _logOut() async {
    final babies = ref.read(babiesProvider).value ?? [];
    final waiting = <String>[];
    for (final b in babies) {
      final n = (ref.read(photosProvider(b.id)).value ?? [])
          .where((p) => !p.synced)
          .length;
      if (n > 0) waiting.add('${b.name} ($n)');
    }
    final blocked = waiting.isNotEmpty;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(blocked ? 'Not yet' : 'Log out?'),
        content: Text(
          blocked
              ? [
                  'Not uploaded to Drive yet: ${waiting.join(', ')}. Wait '
                      'for the upload, then log out.',
                ].join('\n\n')
              : 'You are signed out of Google and this device forgets your babies '
                    'and photos.\n\nNothing is deleted: your photos stay in your '
                    'Google Drive and your reminders stay in your Google Calendar. '
                    'To get everything back, log in again with "I already '
                    'registered my baby".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(blocked ? 'OK' : 'Cancel'),
          ),
          if (!blocked)
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Log out'),
            ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(babiesProvider.notifier).logOut();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('You are logged out.')));
  }

  Future<void> _deleteAll() async {
    final babies = ref.read(babiesProvider).value ?? [];
    final waiting = <String>[];
    for (final b in babies) {
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
          'This removes all babies and the photos kept on this device, switches '
          'off any share links and signs you out of Google.\n\n'
          'It also DELETES the "Baby Photobook" calendars this app made in your '
          'Google Calendar, with their reminders.\n\n'
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
    final body = babies.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(child: Text('Could not load your babies.')),
      data: (list) => list.isEmpty
          ? WelcomeView(onStart: _add, onRestore: _restore, busy: _restoring)
          : context.isWide
          ? _BabyGrid(babies: list, onAdd: _add)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              children: [
                if (!isInstalledApp()) const _InstallBanner(),
                for (final b in list) _BabyCard(b),
              ],
            ),
    );
    if (welcome) return Scaffold(body: body);
    return AdaptiveScaffold(
      title: 'Baby Photobook',
      showTitle: false,
      bodyPadded: false,
      actions: [
        PopupMenuButton<String>(
          tooltip: 'Menu',
          onSelected: (v) => switch (v) {
            'restore' => _restore(),
            'install' => startInstall(context),
            'logout' => _logOut(),
            _ => _deleteAll(),
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'restore',
              enabled: !_restoring,
              child: const Text('Bring back babies from Google Drive'),
            ),
            if (!isInstalledApp())
              const PopupMenuItem(
                value: 'install',
                child: Text('Install on your phone'),
              ),
            const PopupMenuItem(value: 'logout', child: Text('Log out')),
            PopupMenuItem(
              value: 'delete',
              child: Text('Delete all data on this device'),
            ),
          ],
        ),
      ],
      floatingActionButton:
          !context.isWide && babies.hasValue && babies.value!.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('Add a baby'),
            )
          : null,
      body: body,
    );
  }
}

/// Wide windows: a heading, then the babies as a grid of cards with an
/// "add" tile at the end.
class _BabyGrid extends StatelessWidget {
  const _BabyGrid({required this.babies, required this.onAdd});
  final List<Baby> babies;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ContentFrame(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 40, 0, 28),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          babies.length == 1 ? 'Your baby' : 'Your babies',
                          style: text.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'One photo at a time, kept in your own Google Drive.',
                          style: text.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add),
                    label: const Text('Add a baby'),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 48),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 560,
                mainAxisExtent: 208,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
              ),
              delegate: SliverChildListDelegate([
                for (final b in babies) _BabyCard(b, large: true),
                _AddBabyTile(onTap: onAdd),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddBabyTile extends StatelessWidget {
  const _AddBabyTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return HoverLift(
      child: Material(
        color: scheme.primaryContainer.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.35)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: scheme.primary,
                  child: Icon(Icons.add, color: scheme.onPrimary, size: 30),
                ),
                const SizedBox(height: 12),
                Text(
                  'Add a baby',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: scheme.primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BabyCard extends ConsumerWidget {
  const _BabyCard(this.baby, {this.large = false});
  final Baby baby;

  /// The roomier card used in the desktop grid.
  final bool large;

  /// Tapping the chip checks the calendar and shows the answer.
  Future<void> _openCalendar(BuildContext context, WidgetRef ref) async {
    if (baby.googleCalendarId == null || !baby.reminder.enabled) {
      // The baby page shows the reminder step open, with its button.
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => BabyPage(babyId: baby.id)));
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
          final card = Card(
            margin: large ? EdgeInsets.zero : null,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => BabyPage(babyId: baby.id)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: large ? Alignment.centerLeft : Alignment.topLeft,
                  heightFactor: large ? null : 1,
                  child: Row(
                    children: [
                      BabyAvatar(
                        baby: baby,
                        photo: photos.lastOrNull,
                        size: large ? 112 : 84,
                      ),
                      SizedBox(width: large ? 20 : 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              baby.name,
                              maxLines: large ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(birthSummary(context, baby)),
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
                            if (large)
                              Text(
                                '${photos.length} photo${photos.length == 1 ? '' : 's'}',
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
                            if (waiting > 0)
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
            ),
          );
          return large ? HoverLift(child: card) : card;
        },
      ),
    );
  }
}

/// A one-time hint on phones: put the app on the home screen. "Not now" hides
/// it for good; the menu entry "Install on your phone" stays.
class _InstallBanner extends ConsumerStatefulWidget {
  const _InstallBanner();

  @override
  ConsumerState<_InstallBanner> createState() => _InstallBannerState();
}

class _InstallBannerState extends ConsumerState<_InstallBanner> {
  static const _key = 'install_banner_dismissed';
  bool _hidden = true; // hidden until we know it was not dismissed

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final store = await ref.read(localStoreProvider.future);
      final seen = await store.read(_key) != null;
      if (mounted && !seen) setState(() => _hidden = false);
    } catch (_) {
      /* storage unavailable: no banner */
    }
  }

  Future<void> _dismiss() async {
    setState(() => _hidden = true);
    try {
      final store = await ref.read(localStoreProvider.future);
      await store.write(_key, Uint8List.fromList([1]));
    } catch (_) {
      /* it simply shows again next time */
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      color: scheme.primaryContainer.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.install_mobile),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Add Baby Photobook to your home screen',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.only(left: 36),
              child: Text('It then opens like an app. No store needed.'),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                children: [
                  TextButton(onPressed: _dismiss, child: const Text('Not now')),
                  FilledButton(
                    onPressed: () => startInstall(context),
                    child: const Text('Show me how'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
