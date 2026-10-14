import 'package:baby_growth_photobook/features/common/drive_consent.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _open(WidgetTester t, Size size) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (c) => TextButton(
          onPressed: () => showDriveConsent(c),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('wide screens get a centred dialog', (t) async {
    await _open(t, const Size(1200, 900));
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Before you connect Google Drive'), findsOneWidget);
    expect(
      t.getSize(find.text('Before you connect Google Drive')).width,
      lessThan(520),
    );
  });

  testWidgets('phones keep the bottom sheet', (t) async {
    await _open(t, const Size(400, 900));
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
  });
}
