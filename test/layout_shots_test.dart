// Dev tool, not a check: renders every main screen at many window sizes to
// PNG files with the app's real fonts. Only runs when SHOTS_DIR is set:
//   SHOTS_DIR=/tmp/shots flutter test test/layout_shots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:baby_growth_photobook/data/local_store.dart';
import 'package:baby_growth_photobook/data/photo_library.dart';
import 'package:baby_growth_photobook/data/providers.dart';
import 'package:baby_growth_photobook/domain/baby.dart';
import 'package:baby_growth_photobook/domain/schedule.dart';
import 'package:baby_growth_photobook/features/baby/baby_page.dart';
import 'package:baby_growth_photobook/features/baby/camera_screen.dart';
import 'package:baby_growth_photobook/features/baby/edit_baby_page.dart';
import 'package:baby_growth_photobook/features/baby/photo_viewer.dart';
import 'package:baby_growth_photobook/features/home/home_page.dart';
import 'package:baby_growth_photobook/features/onboarding/onboarding_page.dart';
import 'package:baby_growth_photobook/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_flow_test.dart' show MemoryRepository;
import 'camera_screen_test.dart' show FakeCamera;
import 'photo_sync_test.dart' show FakeCloud;
import 'timelapse_test.dart' show FakeExporter;

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

const sizes = <(String, Size)>[
  ('phone-360x640', Size(360, 640)),
  ('iphone-390x844', Size(390, 844)),
  ('phone-landscape-844x390', Size(844, 390)),
  ('tablet-portrait-768x1024', Size(768, 1024)),
  ('narrow-861x762', Size(861, 762)),
  ('tablet-landscape-1024x768', Size(1024, 768)),
  ('laptop-1280x800', Size(1280, 800)),
  ('desktop-1440x900', Size(1440, 900)),
  ('fullhd-1920x1080', Size(1920, 1080)),
];

Future<void> _font(String family, List<String> paths) async {
  final l = FontLoader(family);
  for (final p in paths) {
    final b = File(p).readAsBytesSync();
    l.addFont(Future.value(ByteData.view(b.buffer)));
  }
  await l.load();
}

class _Gate extends ConsumerWidget {
  const _Gate(this.child);
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(babiesProvider).hasValue ? child : const SizedBox();
}

void main() {
  final dir = Platform.environment['SHOTS_DIR'];
  if (dir == null) return;
  Directory(dir).createSync(recursive: true);
  final key = GlobalKey();

  setUpAll(() async {
    await _font('DMSans', ['assets/fonts/DMSans-Variable.ttf']);
    await _font('NotoSans', [
      'assets/fonts/NotoSans-Regular.ttf',
      'assets/fonts/NotoSans-Bold.ttf',
    ]);
    final flutter =
        Platform.environment['FLUTTER_ROOT'] ??
        '${Platform.environment['HOME']}/.local/flutter';
    await _font('MaterialIcons', [
      '$flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ]);
  });

  final baby = Baby(
    id: 'a',
    name: 'Luna',
    gender: Gender.girl,
    birth: DateTime.now().subtract(const Duration(days: 64)),
    birthPlace: 'Athens',
    phases: const [
      Phase(start: Age.birth, frequency: Frequency.daily),
      Phase(start: Age(1, TimeUnit.month), frequency: Frequency.weekly),
    ],
    driveFolderId: 'f',
  );
  final second = Baby(
    id: 'b',
    name: 'Noah',
    gender: Gender.boy,
    birth: DateTime.now().subtract(const Duration(days: 9)),
    phases: const [Phase(start: Age.birth, frequency: Frequency.weekly)],
  );

  Future<void> shot(WidgetTester t, String name) async {
    await t.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final b =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await b.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$dir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
    });
  }

  Future<void> show(
    WidgetTester t,
    Size size,
    Widget home, {
    List<Baby>? babies,
    int photos = 0,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    final store = MemoryStore();
    final lib = PhotoLibrary(store, 'photos/a');
    await t.runAsync(() async {
      for (var i = 0; i < photos; i++) {
        await lib.add(
          _png,
          DateTime.now().subtract(Duration(days: 60 - i * 5)),
        );
      }
    });
    final repo = MemoryRepository()..data = babies ?? [baby];
    await t.pumpWidget(const SizedBox()); // a fresh app for every screen
    await t.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          localStoreProvider.overrideWith((_) async => store),
          babyRepositoryProvider.overrideWith((_) async => repo),
          cloudProvider.overrideWithValue(FakeCloud()),
          timelapseExporterProvider.overrideWithValue(FakeExporter()),
        ],
        child: RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildTheme(Gender.neutral, wide: size.width >= 700),
            home: _Gate(home),
          ),
        ),
      ),
    );
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await t.pumpAndSettle();
    t.takeException();
  }

  for (final (name, size) in sizes) {
    // Tall version of the same width, so a long page shows in one picture.
    final tall = Size(size.width, 2400);
    testWidgets('shots $name', (t) async {
      addTearDown(t.view.reset);
      await show(t, tall, const HomePage(), babies: []);
      await shot(t, '$name-1-welcome');
      await show(t, size, const HomePage(), babies: [baby, second], photos: 3);
      await shot(t, '$name-2-home');
      await show(t, tall, const BabyPage(babyId: 'a'), photos: 12);
      await shot(t, '$name-3-baby');
      await show(t, tall, const EditBabyPage(babyId: 'a'));
      await shot(t, '$name-4-settings');
      await show(t, size, const OnboardingPage(), babies: []);
      await t.enterText(find.byType(TextField).first, 'Luna');
      await shot(t, '$name-5-onboarding1');
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      await shot(t, '$name-6-onboarding2');
      await t.tap(find.widgetWithText(FilledButton, 'Connect Google Drive'));
      await t.pumpAndSettle();
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      await shot(t, '$name-7-onboarding3');
      await show(
        t,
        size,
        const PhotoViewer(babyId: 'a', initial: 0),
        photos: 4,
      );
      await shot(t, '$name-8-viewer');
      await show(
        t,
        size,
        CameraScreen(service: FakeCamera(), last: _png, first: _png),
      );
      await shot(t, '$name-9-camera');
      await t.pumpWidget(const SizedBox());
    });
  }
}
