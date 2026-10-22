import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

const _canvasSize = Size(300, 300);
const _editorSheetSize = Size(200, 100);
const _bannerSize = Size(160, 40);

// No shadow, so that every pixel we inspect comes from the content under test.
const _style = FloatingShadowSheetStyle(
  background: Color(0xFF00FF00),
  shadow: FloatingEditorShadow(color: Color(0x00000000)),
);

void main() {
  group('FloatingShadowSheet >', () {
    group('editor sheet clip behavior >', () {
      testWidgets('clips an editor sheet that paints outside its bounds by default', (tester) async {
        final pixels = await _renderSheet(
          tester,
          const FloatingShadowSheet(style: _style, editorSheet: _OverflowingBox()),
        );

        // Just above the top of the editor sheet.
        expect(pixels.colorAt(150, pixels.editorSheetTop - 5), _white);
      });

      testWidgets('does not clip an editor sheet that paints outside its bounds with Clip.none', (tester) async {
        final pixels = await _renderSheet(
          tester,
          const FloatingShadowSheet(style: _style, editorSheetClipBehavior: Clip.none, editorSheet: _OverflowingBox()),
        );

        expect(pixels.colorAt(150, pixels.editorSheetTop - 5), _black);
      });

      testWidgets('can switch between clipping and not clipping at runtime', (tester) async {
        Widget sheet(Clip clip) =>
            FloatingShadowSheet(style: _style, editorSheetClipBehavior: clip, editorSheet: const _OverflowingBox());

        final hardEdge = await _renderSheet(tester, sheet(Clip.hardEdge));
        final none = await _renderSheet(tester, sheet(Clip.none));
        final hardEdgeAgain = await _renderSheet(tester, sheet(Clip.hardEdge));

        expect(hardEdge.colorAt(150, hardEdge.editorSheetTop - 5), _white);
        expect(none.colorAt(150, none.editorSheetTop - 5), _black);
        expect(hardEdgeAgain.colorAt(150, hardEdgeAgain.editorSheetTop - 5), _white);
      });
    });

    group('banner >', () {
      for (final clip in [Clip.hardEdge, Clip.none]) {
        testWidgets('paints the banner and its background with $clip', (tester) async {
          final pixels = await _renderSheet(
            tester,
            FloatingShadowSheet(
              style: _style,
              editorSheetClipBehavior: clip,
              banner: const _OverflowingBox(size: _bannerSize, color: Color(0xFF0000FF)),
              editorSheet: const _OverflowingBox(color: Color(0xFFFF0000)),
            ),
          );

          // The banner sits below the top padding and left padding.
          expect(pixels.colorAt(150, pixels.sheetTop + 12 + 20), const Color(0xFF0000FF));
          // The sheet background shows in the padding to the left of the banner.
          expect(pixels.colorAt(60, pixels.sheetTop + 30), _style.background);
        });

        testWidgets('still clips a banner that paints outside the sheet with $clip', (tester) async {
          final pixels = await _renderSheet(
            tester,
            FloatingShadowSheet(
              style: _style,
              editorSheetClipBehavior: clip,
              banner: const _OverflowingBox(size: _bannerSize, color: Color(0xFF0000FF)),
              editorSheet: const _OverflowingBox(color: Color(0xFFFF0000)),
            ),
          );

          // The banner's overflow reaches above the top of the sheet.
          expect(pixels.colorAt(150, pixels.sheetTop - 5), _white);
        });
      }
    });
  });
}

const _white = Color(0xFFFFFFFF);
const _black = Color(0xFF000000);

/// A box that fills [size] with [color], and also paints a [color] band that extends
/// 20px above its own bounds.
class _OverflowingBox extends StatelessWidget {
  const _OverflowingBox({this.size = _editorSheetSize, this.color = _black});

  final Size size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: size, painter: _OverflowingPainter(color));
  }
}

class _OverflowingPainter extends CustomPainter {
  _OverflowingPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, -20, size.width, size.height + 20), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_OverflowingPainter oldDelegate) => oldDelegate.color != color;
}

/// Pumps [sheet] centered on a white background and captures what was painted.
Future<_Pixels> _renderSheet(WidgetTester tester, Widget sheet) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = _canvasSize;
  addTearDown(tester.view.reset);

  final captureKey = GlobalKey();
  final sheetKey = GlobalKey();
  final editorSheetHeight = _editorSheetSize.height;
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: captureKey,
        child: ColoredBox(
          color: _white,
          child: Center(
            child: KeyedSubtree(key: sheetKey, child: sheet),
          ),
        ),
      ),
    ),
  );

  late Uint8List bytes;
  await tester.runAsync(() async {
    final boundary = captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
  });

  final sheetRect = tester.getRect(find.byKey(sheetKey));
  return _Pixels(
    bytes,
    _canvasSize.width.toInt(),
    sheetTop: sheetRect.top.round(),
    editorSheetTop: (sheetRect.bottom - editorSheetHeight).round(),
  );
}

class _Pixels {
  _Pixels(this._rgba, this._width, {required this.sheetTop, required this.editorSheetTop});

  final Uint8List _rgba;
  final int _width;

  /// The y coordinate of the top of the whole shadow sheet, including the banner.
  final int sheetTop;

  /// The y coordinate of the top of the editor sheet.
  final int editorSheetTop;

  Color colorAt(int x, int y) {
    final i = (y * _width + x) * 4;
    return Color.fromARGB(_rgba[i + 3], _rgba[i], _rgba[i + 1], _rgba[i + 2]);
  }
}
