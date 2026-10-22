import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group("Chat > FloatingShadowSheet >", () {
    group("editor sheet clip behavior >", () {
      testWidgets("clips an editor sheet that paints outside its bounds by default", (tester) async {
        final pixels = await _pumpSheet(
          tester,
          const FloatingShadowSheet(style: _style, editorSheet: _OverflowingBox()),
        );

        // Just above the top of the editor sheet.
        expect(pixels.colorAt(pixels.sheetCenterX, pixels.editorSheetTop - 5), _white);
      });

      testWidgets("does not clip an editor sheet that paints outside its bounds with Clip.none", (tester) async {
        final pixels = await _pumpSheet(
          tester,
          const FloatingShadowSheet(style: _style, editorSheetClipBehavior: Clip.none, editorSheet: _OverflowingBox()),
        );

        expect(pixels.colorAt(pixels.sheetCenterX, pixels.editorSheetTop - 5), _black);
      });

      testWidgets("can switch between clipping and not clipping at runtime", (tester) async {
        Widget sheet(Clip clip) =>
            FloatingShadowSheet(style: _style, editorSheetClipBehavior: clip, editorSheet: const _OverflowingBox());

        // Each call re-pumps the same tree, so the existing render object is updated
        // rather than replaced.
        final hardEdge = await _pumpSheet(tester, sheet(Clip.hardEdge));
        final renderSheet = tester.renderObject(find.byType(FloatingShadowSheet));
        expect(hardEdge.colorAt(hardEdge.sheetCenterX, hardEdge.editorSheetTop - 5), _white);

        final none = await _pumpSheet(tester, sheet(Clip.none));
        expect(tester.renderObject(find.byType(FloatingShadowSheet)), same(renderSheet));
        expect(none.colorAt(none.sheetCenterX, none.editorSheetTop - 5), _black);

        final hardEdgeAgain = await _pumpSheet(tester, sheet(Clip.hardEdge));
        expect(tester.renderObject(find.byType(FloatingShadowSheet)), same(renderSheet));
        expect(hardEdgeAgain.colorAt(hardEdgeAgain.sheetCenterX, hardEdgeAgain.editorSheetTop - 5), _white);
      });
    });

    group("banner >", () {
      for (final clip in [Clip.hardEdge, Clip.none]) {
        testWidgets("paints the banner, its background, and clips its overflow with $clip", (tester) async {
          final pixels = await _pumpSheet(
            tester,
            FloatingShadowSheet(
              style: _style,
              editorSheetClipBehavior: clip,
              banner: const _OverflowingBox(size: _bannerSize, color: _blue),
              editorSheet: const _OverflowingBox(color: _red),
            ),
          );

          // The banner sits below the top padding.
          final bannerCenterY = pixels.sheetTop + _style.padding.top.round() + _bannerSize.height ~/ 2;
          expect(pixels.colorAt(pixels.sheetCenterX, bannerCenterY), _blue);

          // The sheet background shows in the padding to the left of the banner.
          expect(pixels.colorAt(pixels.sheetLeft + _style.padding.left ~/ 2, bannerCenterY), _style.background);

          // The banner's overflow reaches above the top of the sheet, but is clipped.
          expect(pixels.colorAt(pixels.sheetCenterX, pixels.sheetTop - 5), _white);
        });
      }
    });
  });
}

/// Pumps [sheet] centered on a white background and captures what was painted.
///
/// Calling this again within the same test updates the existing widget tree, rather
/// than replacing it.
Future<_Pixels> _pumpSheet(WidgetTester tester, Widget sheet) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = _canvasSize;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: _captureKey,
        child: ColoredBox(
          color: _white,
          child: Center(
            child: KeyedSubtree(key: _sheetKey, child: sheet),
          ),
        ),
      ),
    ),
  );

  late Uint8List bytes;
  await tester.runAsync(() async {
    final boundary = _captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
  });

  final sheetRect = tester.getRect(find.byKey(_sheetKey));
  return _Pixels(
    bytes,
    _canvasSize.width.toInt(),
    sheetLeft: sheetRect.left.round(),
    sheetTop: sheetRect.top.round(),
    sheetCenterX: sheetRect.center.dx.round(),
    editorSheetTop: (sheetRect.bottom - _editorSheetSize.height).round(),
  );
}

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

class _Pixels {
  _Pixels(
    this._rgba,
    this._width, {
    required this.sheetLeft,
    required this.sheetTop,
    required this.sheetCenterX,
    required this.editorSheetTop,
  });

  final Uint8List _rgba;
  final int _width;

  /// The x coordinate of the left edge of the whole shadow sheet.
  final int sheetLeft;

  /// The y coordinate of the top of the whole shadow sheet, including the banner.
  final int sheetTop;

  /// The x coordinate of the horizontal center of the whole shadow sheet.
  final int sheetCenterX;

  /// The y coordinate of the top of the editor sheet.
  final int editorSheetTop;

  Color colorAt(int x, int y) {
    final i = (y * _width + x) * 4;
    return Color.fromARGB(_rgba[i + 3], _rgba[i], _rgba[i + 1], _rgba[i + 2]);
  }
}

// Stable keys, so that re-pumping within a test updates the tree instead of rebuilding it.
final _captureKey = GlobalKey();
final _sheetKey = GlobalKey();

const _canvasSize = Size(300, 300);
const _editorSheetSize = Size(200, 100);
const _bannerSize = Size(160, 40);

// No shadow, so that every pixel we inspect comes from the content under test. Explicit
// padding, so that pixel offsets don't depend on the default style.
const _style = FloatingShadowSheetStyle(
  background: Color(0xFF00FF00),
  padding: EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 8),
  shadow: FloatingEditorShadow(color: Color(0x00000000)),
);

const _white = Color(0xFFFFFFFF);
const _black = Color(0xFF000000);
const _red = Color(0xFFFF0000);
const _blue = Color(0xFF0000FF);
