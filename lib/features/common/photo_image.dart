import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/photo_library.dart';

/// Shows a stored photo. Loads the bytes once and reloads only if the picture
/// was replaced (retake).
class PhotoImage extends StatefulWidget {
  const PhotoImage(this.photo, {super.key, this.fit = BoxFit.cover, this.cacheWidth});
  final PhotoEntry photo;
  final BoxFit fit;
  final int? cacheWidth;

  @override
  State<PhotoImage> createState() => _PhotoImageState();
}

class _PhotoImageState extends State<PhotoImage> {
  Uint8List? _bytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PhotoImage old) {
    super.didUpdateWidget(old);
    if (old.photo.rev != widget.photo.rev || old.photo.name.fileName != widget.photo.name.fileName) {
      _load();
    }
  }

  Future<void> _load() async {
    final photo = widget.photo;
    try {
      final b = await photo.bytes();
      if (mounted && photo == widget.photo) setState(() => _bytes = b);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const Center(child: Icon(Icons.broken_image_outlined));
    final b = _bytes;
    if (b == null) return const SizedBox.expand();
    return Image.memory(
      b,
      fit: widget.fit,
      cacheWidth: widget.cacheWidth,
      gaplessPlayback: true,
    );
  }
}
