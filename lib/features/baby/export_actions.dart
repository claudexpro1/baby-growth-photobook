import 'package:flutter/material.dart';

import '../../data/google_auth.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/photo_library.dart';
import '../../data/photo_sync.dart';
import '../../data/providers.dart';
import '../../domain/baby.dart';
import '../../export/photobook_pdf.dart';
import '../common/adaptive_sheet.dart';

/// File name that keeps letters from any alphabet (e.g. Greek) and falls back
/// to the baby's id if nothing is left.
String _pdfName(Baby baby) {
  final clean = baby.name
      .replaceAll(RegExp(r'[^\p{L}\p{N}\- ]', unicode: true), '')
      .trim();
  return '${clean.isEmpty ? baby.id : clean}-photobook.pdf';
}

void _say(BuildContext context, String text) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

/// Builds the PDF photobook and opens the phone's share sheet.
Future<void> sharePhotobookPdf(
  BuildContext context,
  WidgetRef ref,
  Baby baby,
  List<PhotoEntry> photos,
) async {
  if (photos.isEmpty) {
    _say(context, 'Take a first photo to make a photobook.');
    return;
  }
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('Making the photobook...')),
          ],
        ),
      ),
    ),
  );
  Uint8List? pdf;
  try {
    pdf = await buildPhotobookPdf(baby, photos);
  } catch (_) {
    pdf = null;
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
  if (!context.mounted) return;
  if (pdf == null) {
    _say(context, 'Sorry, the photobook could not be made. Please try again.');
    return;
  }
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(pdf, mimeType: 'application/pdf', name: _pdfName(baby)),
      ],
    ),
  );
}

/// Bottom sheet to create (or stop) a Google Drive link to a Shared folder.
Future<void> showShareLinkSheet(
  BuildContext context,
  WidgetRef ref,
  Baby baby,
  List<PhotoEntry> photos,
) {
  return showAdaptiveSheet<void>(
    context,
    builder: (_) => _ShareLinkSheet(babyId: baby.id, photos: photos),
  );
}

class _ShareLinkSheet extends ConsumerStatefulWidget {
  const _ShareLinkSheet({required this.babyId, required this.photos});
  final String babyId;
  final List<PhotoEntry> photos;

  @override
  ConsumerState<_ShareLinkSheet> createState() => _ShareLinkSheetState();
}

class _ShareLinkSheetState extends ConsumerState<_ShareLinkSheet> {
  bool _busy = false;
  String? _link;
  String? _error;

  Baby get _baby =>
      ref.read(babiesProvider).value!.firstWhere((b) => b.id == widget.babyId);

  void _set(VoidCallback f) {
    if (mounted) setState(f);
  }

  Future<void> _create() => GoogleAuth.userInitiated(_createInner);

  Future<void> _createInner() async {
    _set(() {
      _busy = true;
      _error = null;
    });
    try {
      final cloud = ref.read(cloudProvider);
      var baby = _baby;
      final babyFolder = await cloud.ensureBabyFolder(
        driveFolderNameFor(baby, ref.read(babiesProvider).value ?? const []),
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
      _set(() => _link = link);
    } catch (_) {
      _set(
        () => _error =
            'Could not create the link. Check your connection and try again.',
      );
    } finally {
      _set(() => _busy = false);
    }
  }

  Future<void> _stop() => GoogleAuth.userInitiated(_stopInner);

  Future<void> _stopInner() async {
    final id = _baby.driveSharedFolderId;
    if (id == null) return;
    _set(() => _busy = true);
    try {
      await ref.read(cloudProvider).unshareFolder(id);
      if (mounted) {
        Navigator.pop(context);
        _say(context, 'The link no longer works.');
      }
    } catch (_) {
      _set(() {
        _error = 'Could not stop sharing. Please try again.';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final shared = ref
        .watch(babiesProvider)
        .value
        ?.where((b) => b.id == widget.babyId)
        .firstOrNull
        ?.driveSharedFolderId;
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
            'We put a photobook (PDF) in a separate "Shared" folder in your Drive and make a '
            'link to it. The photobook contains ALL the photos plus your baby\'s name, birth '
            'date and place. Anyone you send the link to can view it. Your original photo '
            'folder stays private. You can stop sharing at any time.',
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
                    if (context.mounted) _say(context, 'Link copied');
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
                          : (shared == null
                                ? 'Create link'
                                : 'Update and get the link'),
                    ),
            ),
          if (shared != null) ...[
            const SizedBox(height: 8),
            const Text('Sharing is currently ON for this baby.'),
            TextButton(
              onPressed: _busy ? null : _stop,
              child: const Text('Stop sharing'),
            ),
          ],
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
