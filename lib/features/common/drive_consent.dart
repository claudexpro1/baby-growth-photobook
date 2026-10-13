import 'package:flutter/material.dart';

/// Plain-language explanation shown before the Google sign-in. Keep this in
/// step with docs/PRIVACY_POLICY.md ("Google Drive").
const driveConsentPoints = <(IconData, String)>[
  (
    Icons.folder_special_outlined,
    'The app can only see what it creates itself: a "BabyPhotobook" folder '
        'and the photos and settings inside it. It cannot see the rest of your Drive.',
  ),
  (
    Icons.schedule,
    'The folder is created in your Drive when you finish setting up (or '
        'connect later) and the first photo or settings are saved. Each baby gets '
        'their own folder, plus a small "_App data" folder with the profiles.',
  ),
  (
    Icons.lock_outline,
    'Everything stays in your own Google account. We have no server, so no '
        'one else, including the developer, can see your photos or your baby\'s details.',
  ),
  (
    Icons.link,
    'Photos are only visible to others if you create a share link yourself. '
        'You can stop sharing at any time.',
  ),
];

/// Asks the parent to read what connecting Drive means. Returns true on
/// "Continue", false on "Not now" or dismissal.
Future<bool> showDriveConsent(BuildContext context) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              // Only the text scrolls; the buttons stay in reach on small screens.
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Before you connect Google Drive',
                      style: Theme.of(c).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'One photo now and then, saved in your own Drive, '
                      'becomes a story you will treasure.',
                    ),
                    const SizedBox(height: 16),
                    for (final (icon, text) in driveConsentPoints)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(icon, color: Theme.of(c).colorScheme.primary),
                            const SizedBox(width: 12),
                            Expanded(child: Text(text)),
                          ],
                        ),
                      ),
                    const Text(
                      'Next, Google asks you to allow this. You can take the access away '
                      'any time at myaccount.google.com/permissions.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('Not now'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Continue'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return ok == true;
}
