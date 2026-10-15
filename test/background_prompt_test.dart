import 'dart:typed_data';

import 'package:baby_growth_photobook/data/drive_cloud.dart';
import 'package:baby_growth_photobook/data/google_auth.dart';
import 'package:baby_growth_photobook/data/local_store.dart';
import 'package:baby_growth_photobook/data/providers.dart';
import 'package:baby_growth_photobook/domain/baby.dart';
import 'package:baby_growth_photobook/domain/schedule.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_flow_test.dart' show MemoryRepository;
import 'photo_sync_test.dart' show FakeCloud;

class _Cloud extends FakeCloud {
  bool signedIn = true;
  Object? failWith;
  @override
  Future<bool> isSignedIn() async => signedIn;
  @override
  Future<String> ensureBabyFolder(String babyName, {String? existingId}) async {
    if (failWith != null) throw failWith!;
    return super.ensureBabyFolder(babyName, existingId: existingId);
  }
}

Baby _baby() => Baby(
  id: 'b',
  name: 'Luna',
  gender: Gender.girl,
  birth: DateTime(2026, 10, 10),
  phases: const [Phase(start: Age.birth, frequency: Frequency.daily)],
  storage: StorageMode.googleDrive,
);

void main() {
  test('Google may only open its window inside a user tap', () async {
    expect(GoogleAuth.mayPrompt, isFalse);
    await GoogleAuth.userInitiated(() async {
      expect(GoogleAuth.mayPrompt, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(GoogleAuth.mayPrompt, isTrue); // still, after waiting
    });
    expect(GoogleAuth.mayPrompt, isFalse);
    // background work started from a tap handler later is quiet again
    await Future<void>.delayed(Duration.zero);
    expect(GoogleAuth.mayPrompt, isFalse);
  });

  Future<(ProviderContainer, _Cloud)> setup() async {
    final store = MemoryStore();
    store.data['photos/b/00001_2026-10-10.jpg'] = Uint8List.fromList([1]);
    final cloud = _Cloud();
    final c = ProviderContainer(
      overrides: [
        localStoreProvider.overrideWith((_) async => store),
        babyRepositoryProvider.overrideWith(
          (_) async => MemoryRepository()..data = [_baby()],
        ),
        cloudProvider.overrideWithValue(cloud),
      ],
    );
    addTearDown(c.dispose);
    await c.read(babiesProvider.future);
    return (c, cloud);
  }

  test(
    'a background sync without a sign-in asks for a Reconnect tap',
    () async {
      final (c, cloud) = await setup();
      cloud.signedIn = false;
      final r = await c.read(photosProvider('b').notifier).sync();
      expect(r.ok, isFalse);
      expect(r.needsReconnect, isTrue);
      expect(c.read(driveReconnectProvider), isTrue);
    },
  );

  test(
    'Google refusing in the background is a Reconnect, not an error',
    () async {
      final (c, cloud) = await setup();
      cloud.failWith = const DriveNeedsReconnect();
      var r = await c.read(photosProvider('b').notifier).sync();
      expect(r.needsReconnect, isTrue);
      cloud.failWith = const GoogleReauthFailed('x');
      r = await c.read(photosProvider('b').notifier).sync();
      expect(r.needsReconnect, isTrue);
      // a plain network error is not a reconnect
      cloud.failWith = Exception('offline');
      r = await c.read(photosProvider('b').notifier).sync();
      expect(r.needsReconnect, isFalse);
    },
  );

  test('a good sync clears the Reconnect note', () async {
    final (c, cloud) = await setup();
    cloud.signedIn = false;
    await c.read(photosProvider('b').notifier).sync();
    expect(c.read(driveReconnectProvider), isTrue);
    cloud.signedIn = true;
    final r = await c
        .read(photosProvider('b').notifier)
        .sync(interactive: true);
    expect(r.ok, isTrue);
    expect(c.read(driveReconnectProvider), isFalse);
  });
}
