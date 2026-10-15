import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../camera/camera_service.dart';

/// What the camera screen hands back.
class CameraResult {
  const CameraResult.photo(this.bytes) : useCameraApp = false;
  const CameraResult.cameraApp() : bytes = null, useCameraApp = true;
  final Uint8List? bytes;

  /// The parent chose the phone's own camera app instead.
  final bool useCameraApp;
}

enum Ghost { last, first, off }

/// Full-screen camera with a see-through copy of an earlier photo on top, so
/// every photo of the baby lines up with the one before.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, required this.service, this.last, this.first});
  final CameraService service;

  /// The most recent photo and the very first one (null when there is none).
  final Uint8List? last;
  final Uint8List? first;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  bool _loading = true;
  String? _error;
  bool _front = false;
  bool _canSwitch = false;
  bool _busy = false;
  double _opacity = 0.35;
  late Ghost _ghost = widget.last != null ? Ghost.last : Ghost.off;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void dispose() {
    widget.service.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.service.start(front: _front);
      final multiple = await widget.service.canSwitch();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _canSwitch = multiple;
      });
    } catch (e) {
      if (!mounted) return;
      final blocked =
          '$e'.contains('NotAllowed') || '$e'.contains('Permission');
      setState(() {
        _loading = false;
        _error = blocked
            ? 'The camera is blocked. Allow the camera for this site in your '
                  'browser (look at the icon at the left of the address bar), '
                  'or use the camera app instead.'
            : 'Could not open the camera. You can use the camera app instead.';
      });
    }
  }

  Future<void> _shoot() async {
    if (_busy || _loading || _error != null) return;
    setState(() => _busy = true);
    try {
      final bytes = await widget.service.capture();
      if (mounted) Navigator.of(context).pop(CameraResult.photo(bytes));
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not take the picture. Try again.'),
          ),
        );
      }
    }
  }

  Uint8List? get _ghostBytes => switch (_ghost) {
    Ghost.last => widget.last,
    Ghost.first => widget.first ?? widget.last,
    Ghost.off => null,
  };

  @override
  Widget build(BuildContext context) {
    final hasGhost = widget.last != null;
    final ghost = _ghostBytes;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): _shoot,
        const SingleActivator(LogicalKeyboardKey.enter): _shoot,
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Close',
                        color: Colors.white,
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const Expanded(
                        child: Text(
                          'Take photo',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ),
                      if (_canSwitch)
                        IconButton(
                          tooltip: 'Switch camera',
                          color: Colors.white,
                          icon: const Icon(Icons.cameraswitch_outlined),
                          onPressed: _loading
                              ? null
                              : () {
                                  _front = !_front;
                                  _open();
                                },
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _error != null
                        ? _message(_error!)
                        : _loading
                        ? const CircularProgressIndicator()
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: AspectRatio(
                              aspectRatio: widget.service.aspect ?? 3 / 4,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    widget.service.buildPreview(),
                                    if (ghost != null)
                                      IgnorePointer(
                                        child: Opacity(
                                          key: const Key('ghost-overlay'),
                                          opacity: _opacity,
                                          child: Image.memory(
                                            ghost,
                                            fit: BoxFit.cover,
                                            gaplessPlayback: true,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
                if (hasGhost && _error == null) _ghostControls(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () =>
                              Navigator.of(context)
                                  .pop(const CameraResult.cameraApp()),
                          child: const Text(
                            'Use the camera app instead',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Take the photo',
                        child: GestureDetector(
                          key: const Key('shutter'),
                          onTap: _shoot,
                          child: Container(
                            width: 76,
                            height: 76,
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (_loading || _error != null || _busy)
                                    ? Colors.white24
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _message(String text) => Padding(
    padding: const EdgeInsets.all(32),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.no_photography_outlined,
            color: Colors.white70,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _open,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Try again'),
          ),
        ],
      ),
    ),
  );

  Widget _ghostControls() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<Ghost>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              foregroundColor: Colors.white70,
              selectedForegroundColor: Colors.black,
              selectedBackgroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
            ),
            segments: [
              const ButtonSegment(value: Ghost.last, label: Text('Last photo')),
              if (widget.first != null)
                const ButtonSegment(
                  value: Ghost.first,
                  label: Text('First photo'),
                ),
              const ButtonSegment(value: Ghost.off, label: Text('No guide')),
            ],
            selected: {_ghost},
            onSelectionChanged: (s) => setState(() => _ghost = s.first),
          ),
          if (_ghost != Ghost.off)
            Row(
              children: [
                const Icon(Icons.opacity, color: Colors.white54, size: 18),
                Expanded(
                  child: Slider(
                    value: _opacity,
                    min: 0.1,
                    max: 0.8,
                    onChanged: (v) => setState(() => _opacity = v),
                  ),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}
