import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/baby.dart';
import 'google_auth.dart';
import 'providers.dart';

/// Google's browser sign-in lasts about an hour and can only be renewed from
/// a tap. So the taps that lead to Drive (open a baby, take a photo) renew it
/// first, when it has lapsed: the "Reconnect" banner then rarely shows up.
/// Never throws and never waits long; a failed renewal leaves the banner.
Future<void> renewDriveOnTap(WidgetRef ref, Baby baby) async {
  if (baby.driveFolderId == null) return; // Drive was never connected
  final cloud = ref.read(cloudProvider);
  try {
    if (await cloud.isSignedIn()) return;
    await GoogleAuth.userInitiated(() => cloud.signIn())
        .timeout(const Duration(seconds: 8));
    ref.read(driveReconnectProvider.notifier).set(false);
  } catch (_) {
    // Still lapsed (window blocked or closed): the Reconnect banner stays.
  }
}
