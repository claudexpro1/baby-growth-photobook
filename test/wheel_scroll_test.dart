import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baby_growth_photobook/ui/responsive.dart';

void main() {
  testWidgets('wheel over the side margin scrolls the page', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryScrollController(
            controller: controller,
            child: Builder(
              builder: (context) => WheelScrollArea(
                child: ContentFrame(
                  maxWidth: 600,
                  child: ListView(
                    children: [
                      for (var i = 0; i < 60; i++)
                        SizedBox(height: 80, child: Text('row $i')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // x=50 is far outside the centred 600px column.
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(const Offset(50, 400)));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 200)));
    await tester.pump();
    expect(controller.offset, 200);

    // Over the column the list scrolls once, not twice.
    await tester.sendEventToBinding(pointer.hover(const Offset(800, 400)));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 100)));
    await tester.pump();
    expect(controller.offset, 300);
  });
}
