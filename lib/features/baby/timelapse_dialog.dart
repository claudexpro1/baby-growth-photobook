import 'package:flutter/material.dart';

import '../../data/photo_library.dart';
import '../../domain/age_label.dart';
import '../../domain/baby.dart';
import '../../export/timelapse.dart';

/// Asks how the video should look, makes it and saves it as a download.
Future<void> showTimelapseDialog(
  BuildContext context, {
  required TimelapseExporter exporter,
  required Baby baby,
  required List<PhotoEntry> photos,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _TimelapseDialog(exporter: exporter, baby: baby, photos: photos),
  );
}

enum _Stage { options, working, done, failed }

class _TimelapseDialog extends StatefulWidget {
  const _TimelapseDialog({
    required this.exporter,
    required this.baby,
    required this.photos,
  });
  final TimelapseExporter exporter;
  final Baby baby;
  final List<PhotoEntry> photos;

  @override
  State<_TimelapseDialog> createState() => _TimelapseDialogState();
}

class _TimelapseDialogState extends State<_TimelapseDialog> {
  _Stage _stage = _Stage.options;
  TimelapseSpeed _speed = TimelapseSpeed.normal;
  bool _showAge = true;
  int _done = 0;
  String? _file;
  String? _error;

  Future<void> _make() async {
    setState(() {
      _stage = _Stage.working;
      _done = 0;
    });
    try {
      final frames = [
        for (final p in widget.photos)
          TimelapseFrame(ageLabel(widget.baby.birth, p.date), p.bytes),
      ];
      final result = await widget.exporter.make(
        frames,
        frameMs: _speed.frameMs,
        showLabel: _showAge,
        onProgress: (done, total) {
          if (mounted) setState(() => _done = done);
        },
      );
      final name = timelapseFileName(widget.baby.name, result.extension);
      await widget.exporter.save(result, name);
      if (!mounted) return;
      setState(() {
        _stage = _Stage.done;
        _file = name;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.failed;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.photos.length;
    final working = _stage == _Stage.working;
    return AlertDialog(
      title: Text(switch (_stage) {
        _Stage.options => 'Make a timelapse video',
        _Stage.working => 'Making your video...',
        _Stage.done => 'Your video is ready',
        _Stage.failed => 'Could not make the video',
      }),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: switch (_stage) {
          _Stage.options => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.baby.name}\'s $total photos, from the first to the '
                'latest, as one short video. It is made in your browser and '
                'never leaves this device.',
              ),
              const SizedBox(height: 16),
              const Text('How fast?'),
              const SizedBox(height: 8),
              SegmentedButton<TimelapseSpeed>(
                showSelectedIcon: false,
                segments: [
                  for (final s in TimelapseSpeed.values)
                    ButtonSegment(value: s, label: Text(s.label)),
                ],
                selected: {_speed},
                onSelectionChanged: (s) => setState(() => _speed = s.first),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show the age on each photo'),
                value: _showAge,
                onChanged: (v) => setState(() => _showAge = v),
              ),
              Text(
                'About ${timelapseSeconds(total, _speed)} seconds long.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          _Stage.working => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(value: total == 0 ? null : _done / total),
              const SizedBox(height: 12),
              Text('Photo $_done of $total'),
              const SizedBox(height: 4),
              const Text('Keep this page open until it is done.'),
            ],
          ),
          _Stage.done => Text(
            'Saved as "$_file". Look in your Downloads folder.',
          ),
          _Stage.failed => Text(
            'Your browser could not record the video. Try Chrome, Edge or '
            'Safari, or try again.\n\n($_error)',
          ),
        },
      ),
      actions: [
        if (_stage == _Stage.options)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        if (_stage == _Stage.options)
          FilledButton(onPressed: _make, child: const Text('Make video')),
        if (_stage == _Stage.failed)
          TextButton(
            onPressed: () => setState(() => _stage = _Stage.options),
            child: const Text('Try again'),
          ),
        if (!working && _stage != _Stage.options)
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
      ],
    );
  }
}
