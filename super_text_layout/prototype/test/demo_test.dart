import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_text_layout/experimental_flow.dart';

import 'package:flow_layout_prototype/main.dart';

void main() {
  testWidgets(
      'demo composes custom content and retains counter state through resizing',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 1050));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final loader = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    await loader.load();
    await (FontLoader('FlowDemo')
          ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf')))
        .load();
    await (FontLoader('FlowCode')
          ..addFont(rootBundle.load('assets/fonts/FiraMono-Regular.ttf')))
        .load();
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey, child: const MaterialApp(home: FlowPrototypeDemo())));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final paragraph = tester.widget<FlowParagraph>(find.byType(FlowParagraph));
    expect(
        paragraph.controller.layout!.fragmentsFor('swatches'), hasLength(12));
    await tester.tap(find.text('0: 0'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Slider), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('0: 1'), findsOneWidget);
    final origin = tester.getTopLeft(find.byType(FlowParagraph));
    final gesture = await tester.startGesture(origin + const Offset(20, 10));
    await gesture.moveTo(origin + const Offset(140, 90));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(paragraph.controller.selection, isNotNull);
    expect(tester.takeException(), isNull);

    if (const bool.fromEnvironment('FLOW_CAPTURE_DEMO')) {
      await tester.runAsync(() async {
        final boundary = boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final target = File('build/flow-protocol-demo.png');
        await target.parent.create(recursive: true);
        await target.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
