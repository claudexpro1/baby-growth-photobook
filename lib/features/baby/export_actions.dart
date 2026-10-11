import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/photo_library.dart';
import '../../data/providers.dart';
import '../../domain/baby.dart';
import '../../export/photobook_pdf.dart';

String _pdfName(Baby baby) =>
    '${baby.name.replaceAll(RegExp(r'[^\w\- ]'), '')}-photobook.pdf';

Future<void> _withProgress(
  BuildContext context,
  String text,
  Future<void> Function() job,
) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    ),
  );
  try {
    await job();
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}

/// Builds the PDF photobook and opens the phone's share sheet.
Future<void> sharePhotobookPdf(
  BuildContext context,
  WidgetRef ref,
  Baby baby,
  List<PhotoEntry> photos,
) async {
  if (photos.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Take a first photo to make a photobook.')),
    );
    return;
  }
  late final String path;
  await _withProgress(context, 'Making the photobook...', () async {
    final bytes = await buildPhotobookPdf(baby, photos);
    final dir = await getTemporaryDirectory();
    path = '${dir.path}/${_pdfName(baby)}';
    await File(path).writeAsBytes(bytes);
  });
  await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
}

/// Bottom sheet to create (or stop) a Google Drive link to a Shared folder.
Future<void> showShareLinkSheet(
  BuildContext context,
  WidgetRef ref,
  Baby baby,
  List<PhotoEntry> photos,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ShareLinkSheet(baby: baby, photos: photos),
  );
}

class _ShareLinkSheet extends ConsumerStatefulWidget {
  const _ShareLinkSheet({required this.baby, required this.photos});
  final Baby baby;
  final List<PhotoEntry> photos;

  @override
  ConsumerState<_ShareLinkSheet> createState() => _ShareLinkSheetState();
}

class _ShareLinkSheetState extends ConsumerState<_ShareLinkSheet> {
  bool _busy = false;
  String? _link;
  String? _error;

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final cloud = ref.read(cloudProvider);
      var baby = widget.baby;
      final babyFolder = await cloud.ensureBabyFolder(
        baby.name,
        existingId: baby.driveFolderId,
      );
      final shared = await cloud.ensureSharedFolder(
        babyFolder,
        existingId: baby.driveSharedFolderId,
      );
      if (baby.driveFolderId != babyFolder ||
          baby.driveSharedFolderId != shared) {
        baby = baby.copyWith(
          driveFolderId: babyFolder,
          driveSharedFolderId: shared,
        );
        await ref.read(babiesProvider.notifier).updateBaby(baby);
      }
      await cloud.upload(
        shared,
        _pdfName(baby),
        await buildPhotobookPdf(baby, widget.photos),
      );
      final link = await cloud.shareFolderLink(shared);
      setState(() => _link = link);
    } catch (_) {
      setState(
        () => _error =
            'Could not create the link. Check your connection and try again.',
      );
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    final id = widget.baby.driveSharedFolderId;
    if (id == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(cloudProvider).unshareFolder(id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The link no longer works.')),
        );
      }
    } catch (_) {
      setState(() {
        _error = 'Could not stop sharing. Please try again.';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Share with a link',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'We put a photobook (PDF) in a separate "Shared" folder in your Drive and make '
            'a link to that folder. Anyone you send the link to can view it. '
            'Your other photos stay private. You can stop sharing at any time.',
          ),
          const SizedBox(height: 16),
          if (_link != null) ...[
            SelectableText(_link!),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text('Send link'),
                    onPressed: () =>
                        SharePlus.instance.share(ShareParams(text: _link!)),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy'),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: _link!));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link copied')),
                      );
                    }
                  },
                ),
              ],
            ),
          ] else
            FilledButton(
              onPressed: _busy || widget.photos.isEmpty ? null : _create,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      widget.photos.isEmpty
                          ? 'Take a photo first'
                          : 'Create link',
                    ),
            ),
          if (widget.baby.driveSharedFolderId != null)
            TextButton(
              onPressed: _busy ? null : _stop,
              child: const Text('Stop sharing'),
            ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }
}
