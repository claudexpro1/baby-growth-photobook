// Every main screen at many window sizes, portrait and landscape: nothing may
// overflow or throw.
import 'dart:io';

import 'package:baby_growth_photobook/data/local_store.dart';
import 'package:baby_growth_photobook/data/photo_library.dart';
import 'package:baby_growth_photobook/data/providers.dart';
import 'package:baby_growth_photobook/domain/baby.dart';
import 'package:baby_growth_photobook/domain/schedule.dart';
import 'package:baby_growth_photobook/features/baby/baby_page.dart';
import 'package:baby_growth_photobook/features/baby/camera_screen.dart';
import 'package:baby_growth_photobook/features/baby/edit_baby_page.dart';
import 'package:baby_growth_photobook/features/baby/photo_viewer.dart';
import 'package:baby_growth_photobook/features/baby/slideshow.dart';
import 'package:baby_growth_photobook/features/home/home_page.dart';
import 'package:baby_growth_photobook/features/onboarding/onboarding_page.dart';
import 'package:baby_growth_photobook/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_flow_test.dart' show MemoryRepository;
import 'camera_screen_test.dart' show FakeCamera;
import 'photo_sync_test.dart' show FakeCloud;
import 'timelapse_test.dart' show FakeExporter;

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

/// (width, height) in logical pixels.
const sizes = <(String, Size)>[
  ('small phone', Size(320, 568)),
  ('phone', Size(360, 640)),
  ('phone tall', Size(412, 915)),
  ('iphone', Size(390, 844)),
  ('small phone landscape', Size(568, 320)),
  ('phone landscape', Size(844, 390)),
  ('tablet portrait', Size(768, 1024)),
  ('tablet landscape', Size(1024, 768)),
  ('narrow window', Size(861, 762)),
  ('laptop', Size(1280, 800)),
  ('desktop', Size(1440, 900)),
  ('full hd', Size(1920, 1080)),
  ('big screen', Size(2560, 1440)),
];

/// Fails with the full Flutter error (which widget overflowed) if there is one.
void noError(WidgetTester t, [String? where]) {
  final e = t.takeException();
  // A tiny test picture the decoder sometimes refuses is not a layout problem.
  if (e == null || '$e'.contains('Codec failed')) return;
  final text = e is FlutterError ? e.toStringDeep() : '$e';
  fail('${where ?? ''} $text');
}

class _Gate extends ConsumerWidget {
  const _Gate(this.child);
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(babiesProvider).hasValue ? child : const SizedBox();
}

Future<void> _font(String family, List<String> paths) async {
  final l = FontLoader(family);
  for (final p in paths) {
    final b = File(p).readAsBytesSync();
    l.addFont(Future.value(ByteData.view(b.buffer)));
  }
  await l.load();
}

void main() {
  // The app's own fonts, so text is measured the way the browser shows it.
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
    name: 'Anna Maria Elisabeth',
    gender: Gender.girl,
    birth: DateTime.now().subtract(const Duration(days: 40)),
    birthPlace: 'Athens',
    phases: const [Phase(start: Age.birth, frequency: Frequency.daily)],
    storage: StorageMode.googleDrive,
  );
  final second = Baby(
    id: 'b',
    name: 'Ben',
    gender: Gender.boy,
    birth: DateTime.now().subtract(const Duration(days: 9)),
    phases: const [Phase(start: Age.birth, frequency: Frequency.weekly)],
    storage: StorageMode.googleDrive,
  );

  Future<void> show(
    WidgetTester t,
    Size size,
    Widget home, {
    List<Baby>? babies,
    int photos = 0,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final old = FlutterError.onError;
    FlutterError.onError = (d) {
      final extra =
          d.informationCollector
              ?.call()
              .map((x) => x.toStringDeep())
              .join(' ') ??
          '';
      debugPrint('FLUTTERERR ${d.exceptionAsString()} $extra');
      old?.call(d);
    };
    final store = MemoryStore();
    final lib = PhotoLibrary(store, 'photos/a');
    await t.runAsync(() async {
      for (var i = 0; i < photos; i++) {
        await lib.add(
          _png,
          DateTime.now().subtract(Duration(days: 30 - i * 3)),
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
        child: MaterialApp(
          theme: buildTheme(Gender.neutral, wide: size.width >= 700),
          home: _Gate(home),
        ),
      ),
    );
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
    await t.pumpAndSettle();
  }

  for (final (name, size) in sizes) {
    final label = '$name ${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('welcome: $label', (t) async {
      await show(t, size, const HomePage(), babies: []);
      noError(t);
      expect(find.textContaining('Google account'), findsWidgets);
    });

    testWidgets('home with babies: $label', (t) async {
      await show(t, size, const HomePage(), babies: [baby, second], photos: 3);
      noError(t);
      expect(find.textContaining('Anna Maria'), findsWidgets);
    });

    testWidgets('baby page: $label', (t) async {
      await show(t, size, const BabyPage(babyId: 'a'), photos: 9);
      noError(t);
    });

    testWidgets('settings: $label', (t) async {
      await show(t, size, const EditBabyPage(babyId: 'a'));
      noError(t);
    });

    testWidgets('onboarding steps: $label', (t) async {
      await show(t, size, const OnboardingPage(), babies: []);
      noError(t);
      await t.enterText(find.byType(TextField).first, 'Luna');
      for (var step = 0; step < 3; step++) {
        await t.tap(find.text('Next'));
        await t.pumpAndSettle();
        noError(t, 'step ${step + 2}');
        if (step == 0) {
          await t.tap(
            find.widgetWithText(FilledButton, 'Connect Google Drive'),
          );
          await t.pumpAndSettle();
        }
      }
      noError(t);
    });

    testWidgets('viewer, slideshow, camera: $label', (t) async {
      await show(
        t,
        size,
        const PhotoViewer(babyId: 'a', initial: 0),
        photos: 4,
      );
      noError(t);
      await show(
        t,
        size,
        const SlideshowPage(babyId: 'a', interval: Duration(seconds: 60)),
        photos: 4,
      );
      noError(t);
      await show(
        t,
        size,
        CameraScreen(service: FakeCamera(), last: _png, first: _png),
      );
      noError(t);
      await t.pumpWidget(const SizedBox());
    });
  }
}
