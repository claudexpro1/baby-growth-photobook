import 'package:flutter/material.dart';

import '../common/drive_consent.dart';
import '../common/photo_image.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/providers.dart';
import '../../domain/age_label.dart';
import '../../domain/baby.dart';
import '../../ui/theme.dart';
import '../baby/baby_page.dart';
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
    try {
      final n = await ref.read(babiesProvider.notifier).restoreFromDrive();
      message = n == 0
          ? 'No new babies found in your Google Drive.'
          : (n == 1
                ? 'Restored 1 baby from Google Drive.'
                : 'Restored $n babies from Google Drive.');
    } catch (_) {
      message = 'Could not reach Google Drive. Please check your connection and try again.';
    }
    if (!mounted) return;
    setState(() => _restoring = false);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Baby Photobook'),
        actions: [
          IconButton(
            tooltip: 'Bring back my babies from Google Drive',
            onPressed: _restoring ? null : _restore,
            icon: const Icon(Icons.cloud_download_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (v) =>
                v == 'disconnect' ? _disconnectDrive() : _deleteAll(),
            itemBuilder: (_) => const [
              PopupMenuItem(
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
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.child_care,
                        size: 72,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'A few photos, kept with care',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'One photo now and then, saved in your own Drive, '
                        'becomes a story you will treasure.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'You choose how often, we remind you, and every photo is '
                        'filed by date in your own Google Drive. There is no '
                        'account to make and no server of ours, so only you can see them.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _add,
                        child: const Text('Start with your baby'),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _restoring ? null : _restore,
                        icon: const Icon(Icons.cloud_download_outlined),
                        label: const Text('I already registered my baby'),
                      ),
                    ],
                  ),
                ),
              )
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
      data: buildTheme(baby.gender),
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
                              'Next photo: ${loc.formatMediumDate(next)}',
                              style: Theme.of(context).textTheme.bodySmall,
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
