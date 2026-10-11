// Renders the main screens to PNG files in docs/screenshots.
// Run: flutter test test/screenshots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:baby_growth_photobook/data/providers.dart';
import 'package:baby_growth_photobook/domain/baby.dart';
import 'package:baby_growth_photobook/domain/naming.dart';
import 'package:baby_growth_photobook/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'app_flow_test.dart' show MemoryRepository;

Future<void> _font(String family, List<String> paths) async {
  final l = FontLoader(family);
  for (final p in paths) {
    final b = File(p).readAsBytesSync();
    l.addFont(Future.value(ByteData.view(b.buffer)));
  }
  await l.load();
}

void main() {
  var key = GlobalKey();
  testWidgets('screenshots', (tester) async {
    stdout.writeln('start');
    final flutter = Platform.environment['FLUTTER_ROOT'] ??
        '${Platform.environment['HOME']}/.local/flutter';
    final fonts = '$flutter/bin/cache/artifacts/material_fonts';
    await _font('Roboto', ['$fonts/Roboto-Regular.ttf']);
    await _font('MaterialIcons', ['$fonts/MaterialIcons-Regular.otf']);

    final dir = Directory.systemTemp.createTempSync('shots');
    final out = Directory('docs/screenshots')..createSync(recursive: true);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    tester.view.devicePixelRatio = 2;
    addTearDown(() => tester.view.resetDevicePixelRatio());

    final repo = MemoryRepository();
    Future<void> shot(String name) async {
      stdout.writeln('shot $name');
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
        final b = key.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final image = await b.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${out.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
      });
    }

    Future<void> settle() async {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    stdout.writeln('fonts ok');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDirProvider.overrideWith((_) async => dir),
          babyRepositoryProvider.overrideWith((_) async => repo),
        ],
        child: RepaintBoundary(key: key, child: const PhotobookApp()),
      ),
    );
    stdout.writeln('pumped');
    await settle();
    stdout.writeln('settled');
    await shot('01_welcome');

    await tester.tap(find.text('Start with your baby'));
    await settle();
    await tester.enterText(find.byType(TextField).first, 'Luna');
    await tester.tap(find.text('Girl'));
    await settle();
    await shot('02_about');
    await tester.tap(find.text('Next'));
    await settle();
    await shot('03_storage');
    await tester.tap(find.text('Only in this app'));
    await settle();
    await tester.tap(find.text('Keep in the app only'));
    await settle();
    await tester.tap(find.text('Next'));
    await settle();
    await tester.tap(find.text('Daily, then weekly, then monthly'));
    await settle();
    await shot('04_schedule');
    await tester.tap(find.text('Next'));
    await settle();
    await shot('05_reminders');
    await tester.tap(find.byType(Switch));
    await tester.tap(find.text('Finish'));
    await settle();
    await shot('06_home');

    // A second run of the app with a baby who already has photos.
    final birth = DateTime.now().subtract(const Duration(days: 45));
    final luna = Baby(
      id: 'luna',
      name: 'Luna',
      gender: Gender.girl,
      birth: birth,
      phases: repo.data.first.phases,
      reminder: const ReminderSettings(enabled: false),
    );
    final pdir = Directory('${dir.path}/photos/luna')..createSync(recursive: true);
    final colors = [0xF4A6B7, 0xF6C28B, 0xA8D5BA, 0xA7C7E7, 0xD8B4E2, 0xF9E2A0];
    for (var i = 0; i < 6; i++) {
      final im = img.Image(width: 300, height: 300);
      img.fill(im, color: img.ColorRgb8((colors[i] >> 16) & 255, (colors[i] >> 8) & 255, colors[i] & 255));
      final d = DateTime.utc(birth.year, birth.month, birth.day).add(Duration(days: i * 7));
      File('${pdir.path}/${photoFileName(i + 1, d)}').writeAsBytesSync(img.encodeJpg(im));
    }
    final repo2 = MemoryRepository()..data = [luna];
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDirProvider.overrideWith((_) async => dir),
          babyRepositoryProvider.overrideWith((_) async => repo2),
        ],
        child: RepaintBoundary(key: key = GlobalKey(), child: const PhotobookApp()),
      ),
    );
    await settle();
    await tester.tap(find.text('Luna'));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 400)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await shot('07_baby');
  });
}
