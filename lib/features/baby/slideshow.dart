import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/age_label.dart';
import '../common/photo_image.dart';

/// Plays the baby's photos in order, one every few seconds, with the age on
/// each. Tap to pause or play.
class SlideshowPage extends ConsumerStatefulWidget {
  const SlideshowPage({
    super.key,
    required this.babyId,
    this.interval = const Duration(seconds: 3),
  });
  final String babyId;
  final Duration interval;

  @override
  ConsumerState<SlideshowPage> createState() => _SlideshowPageState();
}

class _SlideshowPageState extends ConsumerState<SlideshowPage> {
  int _index = 0;
  bool _playing = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.interval, (_) {
      final n = ref.read(photosProvider(widget.babyId)).value?.length ?? 0;
      if (n == 0 || !mounted) return;
      setState(() => _index = (_index + 1) % n);
    });
  }

  void _toggle() {
    setState(() => _playing = !_playing);
    if (_playing) {
      _start();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baby = ref
        .watch(babiesProvider)
        .value
        ?.where((b) => b.id == widget.babyId)
        .firstOrNull;
    final photos = ref.watch(photosProvider(widget.babyId)).value ?? [];
    if (baby == null || photos.isEmpty) return const Scaffold(body: SizedBox());
    final p = photos[_index.clamp(0, photos.length - 1)];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          ageLabel(baby.birth, p.date),
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
      body: GestureDetector(
        key: const Key('slideshow-surface'),
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: PhotoImage(
                p,
                key: ValueKey(p.name.fileName),
                fit: BoxFit.contain,
              ),
            ),
            if (!_playing)
              const Center(
                child: Icon(
                  Icons.play_circle_outline,
                  size: 72,
                  color: Colors.white70,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
