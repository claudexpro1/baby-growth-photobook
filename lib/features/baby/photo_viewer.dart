import 'package:flutter/material.dart';

import '../common/photo_image.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/providers.dart';
import '../../domain/age_label.dart';

/// Full-screen swipeable photos with age and date.
class PhotoViewer extends ConsumerStatefulWidget {
  const PhotoViewer({super.key, required this.babyId, required this.initial});
  final String babyId;
  final int initial;

  @override
  ConsumerState<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends ConsumerState<PhotoViewer> {
  late final PageController _controller = PageController(
    initialPage: widget.initial,
  );
  late int _index = widget.initial;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baby = ref
        .watch(babiesProvider)
        .value!
        .firstWhere((b) => b.id == widget.babyId);
    final photos = ref.watch(photosProvider(widget.babyId)).value ?? [];
    if (photos.isEmpty) return const Scaffold(body: SizedBox());
    final i = _index.clamp(0, photos.length - 1);
    final p = photos[i];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${ageLabel(baby.birth, p.date)}  ·  #${p.number}',
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share),
            onPressed: () async {
              final bytes = await p.bytes();
              await SharePlus.instance.share(
                ShareParams(
                  files: [
                    XFile.fromData(
                      bytes,
                      mimeType: 'image/jpeg',
                      name: p.name.fileName,
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Delete this photo?'),
                  content: Text(
                    baby.driveFolderId != null
                        ? 'It will be removed from this phone and from your Google Drive folder.'
                        : 'It will be removed from this phone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                      ),
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (ok != true) return;
              await ref.read(photosProvider(widget.babyId).notifier).delete(p);
              if (context.mounted &&
                  (ref.read(photosProvider(widget.babyId)).value ?? [])
                      .isEmpty) {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: photos.length,
        onPageChanged: (v) => setState(() => _index = v),
        itemBuilder: (_, k) => InteractiveViewer(
          child: Center(child: PhotoImage(photos[k], fit: BoxFit.contain)),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            MaterialLocalizations.of(context).formatFullDate(p.date),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }
}
