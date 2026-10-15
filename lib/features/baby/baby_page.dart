import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../common/drive_consent.dart';
import '../common/photo_image.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/photo_library.dart';
import '../../data/providers.dart';
import '../../domain/age_label.dart';
import '../../domain/baby.dart';
import '../../domain/milestones.dart';
import '../common/baby_avatar.dart';
import '../common/calendar_actions.dart';
import '../../notifications/reminder_service.dart';
import '../../ui/adaptive_scaffold.dart';
import '../../ui/responsive.dart';
import '../../ui/theme.dart';
import 'capture.dart';
import 'edit_baby_page.dart';
import 'export_actions.dart';
import 'photo_viewer.dart';
import 'slideshow.dart';
import 'timelapse_dialog.dart';

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

  Future<void> _addToGoogleCalendar(Baby baby) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Adding reminders to Google Calendar...')),
    );
    final r = await updateGoogleCalendar(ref, baby);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: Duration(seconds: r.ok ? 5 : 10),
          content: Text(r.message),
          action: r.ok
              ? SnackBarAction(
                  label: 'Open',
                  onPressed: () => openInGoogleCalendar(baby),
                )
              : null,
        ),
      );
  }

  Future<void> _connectDrive(Baby baby) async {
    if (!await ref.read(cloudProvider).isSignedIn() &&
        !(mounted && await showDriveConsent(context))) {
      return;
    }
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
      data: themeFor(context, baby.gender),
      child: Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          final desktop = context.isDesktop;

          final identity = _identity(context, baby, photos, big: desktop);
          final todayCard = Card(
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
                        : baby.schedule.nextDueAfter(todayUtc) == null
                        ? 'Finish line reached ♥'
                        : 'Next photo: ${loc.formatFullDate(baby.schedule.nextDueAfter(todayUtc)!)}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, box) {
                      final camera = FilledButton.icon(
                        icon: const Icon(Icons.photo_camera),
                        label: Text(haveToday ? 'Retake' : 'Take photo'),
                        onPressed: () => capturePhoto(
                          context,
                          ref,
                          baby,
                          ImageSource.camera,
                        ),
                      );
                      final gallery = OutlinedButton.icon(
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('From gallery'),
                        onPressed: () => capturePhoto(
                          context,
                          ref,
                          baby,
                          ImageSource.gallery,
                        ),
                      );
                      // Very narrow phones: one button under the other, so the
                      // labels never wrap.
                      if (box.maxWidth < 310) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            camera,
                            const SizedBox(height: 8),
                            gallery,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: camera),
                          const SizedBox(width: 10),
                          gallery,
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          );
          final where = _WhereCard(
            baby: baby,
            photos: photos,
            syncing: _syncing,
            onSync: () => _sync(),
            onConnect: () => _connectDrive(baby),
          );
          final timeline = <Widget>[
            if (desktop)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Timeline',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
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
          ];

          final menu = PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (v) => _onMenu(v, baby, photos),
            itemBuilder: (_) => [
              if (photos.length > 1)
                const PopupMenuItem(
                  value: 'slideshow',
                  child: Text('Play slideshow'),
                ),
              if (photos.length > 1 &&
                  ref.watch(timelapseExporterProvider).supported)
                const PopupMenuItem(
                  value: 'timelapse',
                  child: Text('Make timelapse video'),
                ),
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
                  child: Text('Add reminders to Google Calendar'),
                ),
              if (kIsWeb && baby.reminder.enabled)
                const PopupMenuItem(
                  value: 'ics',
                  child: Text('Download calendar file (.ics)'),
                ),
              const PopupMenuItem(value: 'edit', child: Text('Settings')),
            ],
          );

          final Widget body;
          if (desktop) {
            body = ContentFrame(
              maxWidth: 1240,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 372,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(0, 28, 0, 40),
                      children: [
                        identity,
                        const SizedBox(height: 8),
                        todayCard,
                        where,
                        _actionsCard(context, baby, photos),
                      ],
                    ),
                  ),
                  const SizedBox(width: 40),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(0, 28, 0, 56),
                      children: timeline,
                    ),
                  ),
                ],
              ),
            );
          } else {
            body = ListView(
              padding: EdgeInsets.fromLTRB(
                context.isWide ? 0 : 16,
                context.isWide ? 24 : 0,
                context.isWide ? 0 : 16,
                32,
              ),
              children: [
                identity,
                const SizedBox(height: 8),
                todayCard,
                where,
                const SizedBox(height: 8),
                ...timeline,
              ],
            );
          }

          return AdaptiveScaffold(
            title: baby.name,
            actions: [menu],
            bodyPadded: !desktop,
            maxWidth: desktop ? 1240 : 760,
            body: body,
          );
        },
      ),
    );
  }

  void _onMenu(String v, Baby baby, List<PhotoEntry> photos) {
    switch (v) {
      case 'slideshow':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SlideshowPage(babyId: baby.id)),
        );
      case 'timelapse':
        showTimelapseDialog(
          context,
          exporter: ref.read(timelapseExporterProvider),
          baby: baby,
          photos: photos,
        );
      case 'pdf':
        sharePhotobookPdf(context, ref, baby, photos);
      case 'link':
        showShareLinkSheet(context, ref, baby, photos);
      case 'calendar':
        _addToGoogleCalendar(baby);
      case 'ics':
        ReminderService.instance.addToCalendar(baby);
      case 'restore':
        _sync(restore: true);
      case 'edit':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => EditBabyPage(babyId: baby.id)),
        );
    }
  }

  Widget _identity(
    BuildContext context,
    Baby baby,
    List<PhotoEntry> photos, {
    required bool big,
  }) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: big ? 0 : 8),
      child: Row(
        children: [
          BabyAvatar(
            baby: baby,
            photo: photos.lastOrNull,
            size: big ? 104 : 72,
          ),
          SizedBox(width: big ? 20 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  baby.name,
                  style: big
                      ? text.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        )
                      : text.headlineSmall,
                ),
                Text(
                  ageNowLabel(baby.birth, DateTime.now()),
                  style: text.titleMedium,
                ),
                Text(bornText(context, baby), style: text.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The things the three-dots menu holds, laid out in plain sight for the
  /// desktop side panel.
  Widget _actionsCard(
    BuildContext context,
    Baby baby,
    List<PhotoEntry> photos,
  ) {
    Widget tile(IconData icon, String label, String value) => ListTile(
      dense: true,
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => _onMenu(value, baby, photos),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (photos.length > 1)
            tile(Icons.slideshow, 'Play slideshow', 'slideshow'),
          if (photos.length > 1 &&
              ref.watch(timelapseExporterProvider).supported)
            tile(
              Icons.movie_creation_outlined,
              'Make timelapse video',
              'timelapse',
            ),
          tile(Icons.picture_as_pdf_outlined, 'Share photobook (PDF)', 'pdf'),
          if (baby.storage == StorageMode.googleDrive)
            tile(Icons.link, 'Get a share link', 'link'),
          if (kIsWeb && baby.reminder.enabled)
            tile(
              Icons.event_available_outlined,
              'Add reminders to Google Calendar',
              'calendar',
            ),
          tile(Icons.settings_outlined, 'Settings', 'edit'),
        ],
      ),
    );
  }

  List<Widget> _timeline(
    BuildContext context,
    Baby baby,
    List<PhotoEntry> photos,
  ) {
    // Sections by age; milestones sit in the section of their day, even when
    // that section has no photo yet.
    final sections = <String, List<PhotoEntry>>{};
    final starts = <String, DateTime>{};
    final marks = <String, List<Milestone>>{};
    for (final p in photos) {
      final k = ageSection(baby.birth, p.date);
      sections.putIfAbsent(k, () => []).add(p);
      starts[k] = starts[k] == null || p.date.isBefore(starts[k]!)
          ? p.date
          : starts[k]!;
    }
    for (final m in reachedMilestones(baby.birth, DateTime.now())) {
      final k = ageSection(baby.birth, m.date);
      marks.putIfAbsent(k, () => []).add(m);
      sections.putIfAbsent(k, () => []);
      starts[k] = starts[k] == null || m.date.isBefore(starts[k]!)
          ? m.date
          : starts[k]!;
    }
    final keys = sections.keys.toList()
      ..sort((a, c) => starts[a]!.compareTo(starts[c]!));
    final out = <Widget>[_birthStory(context, baby)];
    for (final k in keys) {
      final e = MapEntry(k, sections[k]!);
      out.add(
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            e.key,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      );
      for (final m in marks[k] ?? const <Milestone>[]) {
        out.add(_milestoneCard(context, m));
      }
      if (e.value.isEmpty) continue;
      out.add(
        GridView.extent(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          maxCrossAxisExtent: context.isWide ? 210 : 150,
          mainAxisSpacing: context.isWide ? 12 : 8,
          crossAxisSpacing: context.isWide ? 12 : 8,
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

  Widget _birthStory(BuildContext context, Baby baby) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Text('🍼', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Our story begins',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    '${baby.name}, ${bornText(context, baby)} (a ${_weekday(baby.birth)}).',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _weekday(DateTime d) => const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][d.weekday - 1];

  Widget _milestoneCard(BuildContext context, Milestone m) {
    final loc = MaterialLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              const Text('🎉', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${m.label} old · ${loc.formatMediumDate(m.date)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                'Your photos are only on this device.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                'If this browser\'s data is cleared or the device is lost, they '
                'are lost too. Connect Google Drive to keep them safe in your '
                'own account.',
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
