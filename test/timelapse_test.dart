import 'dart:async';
import 'dart:typed_data';

import 'package:baby_growth_photobook/data/local_store.dart';
import 'package:baby_growth_photobook/data/photo_library.dart';
import 'package:baby_growth_photobook/data/providers.dart';
import 'package:baby_growth_photobook/domain/baby.dart';
import 'package:baby_growth_photobook/domain/schedule.dart';
import 'package:baby_growth_photobook/export/timelapse.dart';
import 'package:baby_growth_photobook/features/baby/baby_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

class FakeExporter implements TimelapseExporter {
  FakeExporter({this.supportedFlag = true, this.fail = false});
  final bool supportedFlag;
  final bool fail;
  final labels = <String>[];
  int? frameMs;
  bool? showLabel;
  String? savedAs;
  final gate = Completer<void>();

  @override
  bool get supported => supportedFlag;

  @override
  Future<TimelapseResult> make(
    List<TimelapseFrame> frames, {
    required int frameMs,
    bool showLabel = true,
    void Function(int done, int total)? onProgress,
  }) async {
    if (fail) throw StateError('no recorder');
    this.frameMs = frameMs;
    this.showLabel = showLabel;
    for (var i = 0; i < frames.length; i++) {
      labels.add(frames[i].label);
      await frames[i].load(); // frames load one by one
      onProgress?.call(i + 1, frames.length);
    }
    await gate.future;
    return TimelapseResult(Uint8List.fromList([1, 2, 3]), 'video/mp4', 'mp4');
  }

  @override
  Future<void> save(TimelapseResult result, String fileName) async =>
      savedAs = fileName;
}

void main() {
  test('file names are safe and speeds add up', () {
    expect(timelapseFileName('Luna', 'mp4'), 'Luna-timelapse.mp4');
    expect(
      timelapseFileName('  Anna Maria / 2 ', 'webm'),
      'Anna-Maria-2-timelapse.webm',
    );
    expect(timelapseFileName('???', 'mp4'), 'baby-timelapse.mp4');
    expect(
      timelapseSeconds(14, TimelapseSpeed.normal),
      8,
    ); // 7s + the last hold
    expect(timelapseSeconds(100, TimelapseSpeed.fast), 26);
    expect(
      TimelapseSpeed.slow.frameMs,
      greaterThan(TimelapseSpeed.fast.frameMs),
    );
  });

  Future<(MemoryStore, MemoryRepository)> setup(
    WidgetTester t,
    int photos,
  ) async {
    final store = MemoryStore();
    final lib = PhotoLibrary(store, 'photos/a');
    await t.runAsync(() async {
      for (var i = 0; i < photos; i++) {
        await lib.add(_png, DateTime(2026, 10, 1 + i * 7));
      }
    });
    final baby = Baby(
      id: 'a',
      name: 'Anna',
      gender: Gender.girl,
      birth: DateTime(2026, 10, 1),
      phases: const [Phase(start: Age.birth, frequency: Frequency.weekly)],
    );
    return (store, MemoryRepository()..data = [baby]);
  }

  Future<void> openPage(
    WidgetTester t,
    MemoryStore store,
    MemoryRepository repo,
    TimelapseExporter exporter,
    Size size,
  ) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWith((_) async => store),
          babyRepositoryProvider.overrideWith((_) async => repo),
          timelapseExporterProvider.overrideWithValue(exporter),
        ],
        child: const MaterialApp(home: BabyPage(babyId: 'a')),
      ),
    );
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 400)));
    await t.pumpAndSettle();
  }

  testWidgets(
    'desktop: the side panel offers the video; the dialog makes and saves it',
    (t) async {
      final (store, repo) = await setup(t, 3);
      final ex = FakeExporter();
      await openPage(t, store, repo, ex, const Size(1440, 900));
      expect(find.text('Make timelapse video'), findsOneWidget);
      await t.ensureVisible(find.text('Make timelapse video'));
      await t.pumpAndSettle();
      await t.tap(find.text('Make timelapse video'));
      await t.pumpAndSettle();
      expect(find.textContaining("Anna's 3 photos"), findsOneWidget);
      expect(find.textContaining('About 3 seconds'), findsOneWidget);
      await t.tap(find.text('Fast'));
      await t.tap(find.byType(Switch)); // no age labels
      await t.pump();
      await t.tap(find.text('Make video'));
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
      await t.pump();
      expect(find.text('Making your video...'), findsOneWidget);
      expect(find.text('Photo 3 of 3'), findsOneWidget);
      ex.gate.complete();
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
      await t.pumpAndSettle();
      expect(find.text('Your video is ready'), findsOneWidget);
      expect(find.textContaining('Anna-timelapse.mp4'), findsOneWidget);
      expect(ex.savedAs, 'Anna-timelapse.mp4');
      expect(ex.frameMs, 250);
      expect(ex.showLabel, isFalse);
      expect(ex.labels, ['Birth day', '7 days', '2 weeks']);
      await t.tap(find.text('Close'));
      await t.pumpAndSettle();
      expect(find.text('Your video is ready'), findsNothing);
    },
  );

  testWidgets('a failing browser gives a plain message and a retry', (t) async {
    final (store, repo) = await setup(t, 2);
    await openPage(
      t,
      store,
      repo,
      FakeExporter(fail: true),
      const Size(1440, 900),
    );
    await t.ensureVisible(find.text('Make timelapse video'));
    await t.pumpAndSettle();
    await t.tap(find.text('Make timelapse video'));
    await t.pumpAndSettle();
    await t.tap(find.text('Make video'));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await t.pumpAndSettle();
    expect(find.text('Could not make the video'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    await t.tap(find.text('Try again'));
    await t.pumpAndSettle();
    expect(find.text('Make video'), findsOneWidget);
  });

  testWidgets('hidden with one photo or where videos are not supported', (
    t,
  ) async {
    final (store1, repo1) = await setup(t, 1);
    await openPage(t, store1, repo1, FakeExporter(), const Size(1440, 900));
    expect(find.text('Make timelapse video'), findsNothing);

    final (store2, repo2) = await setup(t, 3);
    await openPage(
      t,
      store2,
      repo2,
      FakeExporter(supportedFlag: false),
      const Size(1440, 900),
    );
    expect(find.text('Make timelapse video'), findsNothing);
  });

  testWidgets('phone: it is in the three-dots menu', (t) async {
    final (store, repo) = await setup(t, 3);
    await openPage(t, store, repo, FakeExporter(), const Size(400, 800));
    await t.tap(find.byType(PopupMenuButton<String>));
    await t.pumpAndSettle();
    expect(find.text('Make timelapse video'), findsOneWidget);
  });
}
