import 'dart:typed_data';

import 'package:baby_growth_photobook/camera/camera_service.dart';
import 'package:baby_growth_photobook/data/local_store.dart';
import 'package:baby_growth_photobook/data/photo_library.dart';
import 'package:baby_growth_photobook/data/providers.dart';
import 'package:baby_growth_photobook/domain/baby.dart';
import 'package:baby_growth_photobook/domain/schedule.dart';
import 'package:baby_growth_photobook/features/baby/camera_screen.dart';
import 'package:baby_growth_photobook/features/baby/capture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'app_flow_test.dart' show MemoryRepository;

/// A real 1x1 PNG.
final _png = Uint8List.fromList(const [
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  13,
  73,
  68,
  65,
  84,
  120,
  156,
  99,
  248,
  255,
  255,
  63,
  0,
  5,
  254,
  2,
  254,
  167,
  53,
  129,
  132,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
]);

class FakeCamera implements CameraService {
  FakeCamera({this.fail});
  final Object? fail;
  bool started = false;
  bool disposed = false;
  bool front = false;
  int shots = 0;
  @override
  bool get supported => true;
  @override
  double? get aspect => 3 / 4;
  @override
  Future<void> start({bool front = false}) async {
    if (fail != null) throw fail!;
    started = true;
    this.front = front;
  }

  @override
  Future<bool> canSwitch() async => true;
  @override
  Widget buildPreview() =>
      const ColoredBox(key: Key('preview'), color: Colors.teal);
  @override
  Future<Uint8List> capture() async {
    shots++;
    return _png;
  }

  @override
  void dispose() => disposed = true;
}

Future<CameraResult?> _open(
  WidgetTester t,
  FakeCamera cam, {
  Uint8List? last,
  Uint8List? first,
}) async {
  CameraResult? result;
  await t.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (c) => TextButton(
          onPressed: () async => result = await Navigator.of(c).push(
            MaterialPageRoute(
              builder: (_) =>
                  CameraScreen(service: cam, last: last, first: first),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('no earlier photo: no guide controls, shutter takes the photo', (
    t,
  ) async {
    final cam = FakeCamera();
    CameraResult? got;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () async => got = await Navigator.of(c).push(
              MaterialPageRoute(builder: (_) => CameraScreen(service: cam)),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('preview')), findsOneWidget);
    expect(find.byKey(const Key('ghost-overlay')), findsNothing);
    expect(find.text('Last photo'), findsNothing);
    await t.tap(find.byKey(const Key('shutter')));
    await t.pumpAndSettle();
    expect(got!.bytes, _png);
    expect(cam.disposed, isTrue);
  });

  testWidgets(
    'with an earlier photo the guide shows; options and slider work',
    (t) async {
      final cam = FakeCamera();
      await _open(t, cam, last: _png, first: _png);
      expect(find.byKey(const Key('ghost-overlay')), findsOneWidget);
      expect(find.text('Last photo'), findsOneWidget);
      expect(find.text('First photo'), findsOneWidget);
      expect(find.text('No guide'), findsOneWidget);
      final op = t.widget<Opacity>(find.byKey(const Key('ghost-overlay')));
      expect(op.opacity, closeTo(0.35, 0.001));
      await t.tap(find.text('No guide'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('ghost-overlay')), findsNothing);
      expect(find.byType(Slider), findsNothing);
      await t.tap(find.text('First photo'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('ghost-overlay')), findsOneWidget);
      await t.drag(find.byType(Slider), const Offset(300, 0));
      await t.pumpAndSettle();
      expect(
        t.widget<Opacity>(find.byKey(const Key('ghost-overlay'))).opacity,
        greaterThan(0.5),
      );
    },
  );

  testWidgets('switch camera reopens it facing the other way', (t) async {
    final cam = FakeCamera();
    await _open(t, cam);
    expect(cam.front, isFalse);
    await t.tap(find.byTooltip('Switch camera'));
    await t.pumpAndSettle();
    expect(cam.front, isTrue);
  });

  testWidgets('blocked camera explains itself and offers the camera app', (
    t,
  ) async {
    final cam = FakeCamera(
      fail: Exception('NotAllowedError: Permission denied'),
    );
    await _open(t, cam, last: _png);
    expect(find.textContaining('camera is blocked'), findsOneWidget);
    expect(find.text('Last photo'), findsNothing);
    expect(find.text('Use the camera app instead'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('"Use the camera app instead" returns that choice', (t) async {
    final cam = FakeCamera();
    CameraResult? got;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () async => got = await Navigator.of(c).push(
              MaterialPageRoute(builder: (_) => CameraScreen(service: cam)),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.text('Use the camera app instead'));
    await t.pumpAndSettle();
    expect(got!.useCameraApp, isTrue);
    expect(got!.bytes, isNull);
  });

  testWidgets('taking a photo with the in-app camera files it for today', (
    t,
  ) async {
    final store = MemoryStore();
    final baby = Baby(
      id: 'a',
      name: 'Anna',
      gender: Gender.girl,
      birth: DateTime.now().subtract(const Duration(days: 3)),
      phases: const [Phase(start: Age.birth, frequency: Frequency.daily)],
    );
    final repo = MemoryRepository()..data = [baby];
    final cam = FakeCamera();
    late WidgetRef ref0;
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWith((_) async => store),
          babyRepositoryProvider.overrideWith((_) async => repo),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (c, ref, _) {
              ref0 = ref;
              return Scaffold(
                body: TextButton(
                  onPressed: () => capturePhoto(
                    c,
                    ref,
                    baby,
                    ImageSource.camera,
                    cameraFactory: () => cam,
                  ),
                  child: const Text('take'),
                ),
              );
            },
          ),
        ),
      ),
    );
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await t.tap(find.text('take'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('shutter')));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await t.pumpAndSettle();
    final photos = await t.runAsync(
      () => PhotoLibrary(store, 'photos/a').list(),
    );
    expect(photos!.length, 1);
    final today = DateTime.now();
    expect(
      photos.single.date,
      DateTime.utc(today.year, today.month, today.day),
    );
    expect(find.text('Photo saved ♥'), findsOneWidget);
    expect(ref0, isNotNull);
  });
}
