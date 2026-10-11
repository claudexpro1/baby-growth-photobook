import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../common/photo_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/photo_library.dart';
import '../../data/providers.dart';
import '../../domain/age_label.dart';
import '../../domain/baby.dart';
import '../../notifications/reminder_service.dart';
import '../../ui/theme.dart';
import 'capture.dart';
import 'edit_baby_page.dart';
import 'export_actions.dart';
import 'photo_viewer.dart';

/// A baby's story: today's photo, where the photos are, and the timeline.
class BabyPage extends ConsumerStatefulWidget {
  const BabyPage({super.key, required this.babyId});
  final String babyId;

  @override
  ConsumerState<BabyPage> createState() => _BabyPageState();
}

class _BabyPageState extends ConsumerState<BabyPage> {
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    // Quietly upload anything still waiting when the page opens.
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync(quiet: true));
  }

  Future<void> _sync({bool quiet = false, bool restore = false}) async {
    if (_syncing) return;
    setState(() => _syncing = true);
    final outcome = await ref
        .read(photosProvider(widget.babyId).notifier)
        .sync(restore: restore);
    if (!mounted) return;
    setState(() => _syncing = false);
    if (!quiet || !outcome.ok) {
      if (!(quiet && outcome.message.contains('not connected'))) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(outcome.message)));
      }
    }
  }

  Future<void> _connectDrive(Baby baby) async {
    try {
      final cloud = ref.read(cloudProvider);
      if (!await cloud.isSignedIn()) await cloud.signIn();
      await ref
          .read(babiesProvider.notifier)
          .updateBaby(baby.copyWith(storage: StorageMode.googleDrive));
      await _sync();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'We could not connect to Google Drive. Please try again.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final baby = ref
        .watch(babiesProvider)
        .value
        ?.where((b) => b.id == widget.babyId)
        .firstOrNull;
    if (baby == null) return const Scaffold(body: SizedBox());
    final photos = ref.watch(photosProvider(baby.id)).value ?? [];
    final today = DateTime.now();
    final todayUtc = DateTime.utc(today.year, today.month, today.day);
    final haveToday = photos.any((p) => p.date == todayUtc);
    final dueToday = baby.schedule.dueDates(todayUtc, todayUtc).isNotEmpty;
    final loc = MaterialLocalizations.of(context);

    return Theme(
      data: buildTheme(baby.gender),
      child: Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          return Scaffold(
            appBar: AppBar(
              title: Text(baby.name),
              actions: [
                PopupMenuButton<String>(
                  onSelected: (v) {
                    switch (v) {
                      case 'pdf':
                        sharePhotobookPdf(context, ref, baby, photos);
                      case 'link':
                        showShareLinkSheet(context, ref, baby, photos);
                      case 'calendar':
                        ReminderService.instance.addToCalendar(baby);
                      case 'restore':
                        _sync(restore: true);
                      case 'edit':
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => EditBabyPage(babyId: baby.id),
                          ),
                        );
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'pdf',
                      child: Text('Share photobook (PDF)'),
                    ),
                    if (baby.storage == StorageMode.googleDrive) ...[
                      const PopupMenuItem(
                        value: 'link',
                        child: Text('Get a share link'),
                      ),
                      const PopupMenuItem(
                        value: 'restore',
                        child: Text('Restore photos from Drive'),
                      ),
                    ],
                    if (kIsWeb && baby.reminder.enabled)
                      const PopupMenuItem(
                        value: 'calendar',
                        child: Text('Add reminders to Calendar'),
                      ),
                    const PopupMenuItem(value: 'edit', child: Text('Settings')),
                  ],
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                Text(
                  ageLabel(baby.birth, DateTime.now()),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Card(
                  color: scheme.primaryContainer.withValues(alpha: 0.5),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          haveToday
                              ? "Today's photo is saved ♥"
                              : dueToday
                              ? "It's photo day!"
                              : 'Next photo: ${loc.formatFullDate(baby.schedule.nextDueAfter(todayUtc))}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                icon: const Icon(Icons.photo_camera),
                                label: Text(
                                  haveToday ? 'Retake' : 'Take photo',
                                ),
                                onPressed: () => capturePhoto(
                                  context,
                                  ref,
                                  baby,
                                  ImageSource.camera,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('From gallery'),
                              onPressed: () => capturePhoto(
                                context,
                                ref,
                                baby,
                                ImageSource.gallery,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                _WhereCard(
                  baby: baby,
                  photos: photos,
                  syncing: _syncing,
                  onSync: () => _sync(),
                  onConnect: () => _connectDrive(baby),
                ),
                const SizedBox(height: 8),
                if (photos.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Your story starts with the first photo.\nIt will appear here.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                else
                  ..._timeline(context, baby, photos),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _timeline(
    BuildContext context,
    Baby baby,
    List<PhotoEntry> photos,
  ) {
    final sections = <String, List<PhotoEntry>>{};
    for (final p in photos) {
      sections.putIfAbsent(ageSection(baby.birth, p.date), () => []).add(p);
    }
    final out = <Widget>[];
    for (final e in sections.entries) {
      out.add(
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(e.key, style: Theme.of(context).textTheme.titleMedium),
        ),
      );
      out.add(
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (final p in e.value)
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PhotoViewer(
                      babyId: baby.id,
                      initial: photos.indexOf(p),
                    ),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      PhotoImage(p, cacheWidth: 400),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black54],
                            ),
                          ),
                          child: Text(
                            ageLabel(baby.birth, p.date),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      if (!p.synced && baby.storage == StorageMode.googleDrive)
                        const Positioned(
                          top: 6,
                          right: 6,
                          child: Icon(
                            Icons.cloud_upload_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }
    return out;
  }
}

/// "Where are my photos?" - always visible, so the Drive folder is easy to find.
class _WhereCard extends StatelessWidget {
  const _WhereCard({
    required this.baby,
    required this.photos,
    required this.syncing,
    required this.onSync,
    required this.onConnect,
  });
  final Baby baby;
  final List<PhotoEntry> photos;
  final bool syncing;
  final VoidCallback onSync;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (baby.storage != StorageMode.googleDrive) {
      return Card(
        color: scheme.errorContainer.withValues(alpha: 0.5),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your photos are only on this phone.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                'If the phone is lost or reset, they are lost too. '
                'Connect Google Drive to keep them safe in your own account.',
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: onConnect,
                child: const Text('Connect Google Drive'),
              ),
            ],
          ),
        ),
      );
    }
    final waiting = photos.where((p) => !p.synced).length;
    final folderId = baby.driveFolderId;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.folder_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Google Drive  ›  BabyPhotobook  ›  ${baby.name}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              waiting == 0
                  ? '${photos.length} photo${photos.length == 1 ? '' : 's'} safe in your Drive'
                  : '$waiting photo${waiting == 1 ? '' : 's'} waiting to upload',
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open in Drive'),
                    onPressed: folderId == null
                        ? null
                        : () => launchUrl(
                            ((DriveFolderUrl.of(folderId))),
                            mode: LaunchMode.externalApplication,
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  icon: syncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: const Text('Sync'),
                  onPressed: syncing ? null : onSync,
                ),
              ],
            ),
            if (folderId == null)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'The folder is created with your first photo.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class DriveFolderUrl {
  static Uri of(String id) =>
      Uri.parse('https://drive.google.com/drive/folders/$id');
}
