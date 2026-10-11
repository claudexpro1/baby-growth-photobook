import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/providers.dart';
import '../../domain/baby.dart';

DateTime _day(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// Takes a photo with the camera, or picks one from the gallery, and files it.
/// Only one photo per day is kept, so a second photo asks before replacing.
Future<void> capturePhoto(
  BuildContext context,
  WidgetRef ref,
  Baby baby,
  ImageSource source,
) async {
  final picker = ImagePicker();
  final XFile? file;
  try {
    file = await picker.pickImage(source: source);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open the camera or photos. Check the app permissions in your phone settings.',
          ),
        ),
      );
    }
    return;
  }
  if (file == null || !context.mounted) return;

  var date = DateTime.now();
  if (source == ImageSource.gallery) {
    // Gallery photos may be from another day: let the parent confirm the date.
    final taken = await file.lastModified();
    if (!context.mounted) return;
    final picked = await showDatePicker(
      context: context,
      helpText: 'Which day is this photo for?',
      initialDate: taken.isBefore(baby.birth) ? DateTime.now() : taken,
      firstDate: DateTime(baby.birth.year, baby.birth.month, baby.birth.day),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    date = picked;
  }

  final photos = ref.read(photosProvider(baby.id).notifier);
  final existing = ref.read(photosProvider(baby.id)).value ?? [];
  if (existing.any((p) => p.date == _day(date)) && context.mounted) {
    final replace = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Replace the photo for this day?'),
        content: const Text(
          'There is already a photo for this day. Keep only the new one?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Keep old'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    if (replace != true) return;
  }
  await photos.addPhoto(await file.readAsBytes(), date);
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Photo saved ♥')));
  }
}
