import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../common/photo_image.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/providers.dart';
import '../../domain/age_label.dart';
import '../../ui/responsive.dart';

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
        .value
        ?.where((b) => b.id == widget.babyId)
        .firstOrNull;
    if (baby == null) return const Scaffold(body: SizedBox());
    final photos = ref.watch(photosProvider(widget.babyId)).value ?? [];
    if (photos.isEmpty) return const Scaffold(body: SizedBox());
    final i = _index.clamp(0, photos.length - 1);
    final p = photos[i];
    void step(int by) {
      final to = (_index + by).clamp(0, photos.length - 1);
      if (to == _index) return;
      _controller.animateToPage(
        to,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }

    Widget arrow(bool left) => Positioned(
      left: left ? 16 : null,
      right: left ? null : 16,
      top: 0,
      bottom: 0,
      child: Center(
        child: IconButton.filledTonal(
          tooltip: left ? 'Previous photo' : 'Next photo',
          style: IconButton.styleFrom(
            backgroundColor: Colors.white24,
            foregroundColor: Colors.white,
          ),
          icon: Icon(left ? Icons.chevron_left : Icons.chevron_right),
          onPressed: (left ? i > 0 : i < photos.length - 1)
              ? () => step(left ? -1 : 1)
              : null,
        ),
      ),
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => step(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => step(1),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
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
                  await ref
                      .read(photosProvider(widget.babyId).notifier)
                      .delete(p);
                  if (context.mounted &&
                      (ref.read(photosProvider(widget.babyId)).value ?? [])
                          .isEmpty) {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),
          body: Stack(
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: photos.length,
                onPageChanged: (v) => setState(() => _index = v),
                itemBuilder: (_, k) => InteractiveViewer(
                  child: Center(
                    child: PhotoImage(photos[k], fit: BoxFit.contain),
                  ),
                ),
              ),
              if (context.isWide && photos.length > 1) ...[
                arrow(true),
                arrow(false),
              ],
            ],
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
        ),
      ),
    );
  }
}
