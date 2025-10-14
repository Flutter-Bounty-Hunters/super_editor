import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:super_editor/super_editor.dart';

/// The whole bottom sheet for the floating editor demo, which includes a [FloatingShadowSheet] with
/// a banner, which then contains an [FloatingEditorSheet], which has a drag handle, an
/// editor, and a toolbar.
class BottomFloatingChatSheet extends StatefulWidget {
  const BottomFloatingChatSheet({
    super.key,
    required this.messagePageController,
    this.shadowSheetBanner,
    required this.editorSheet,
    this.style = const FloatingEditorStyle(),
  });

  final MessagePageController messagePageController;

  final Widget? shadowSheetBanner;

  final Widget editorSheet;

  final FloatingEditorStyle style;

  @override
  State<BottomFloatingChatSheet> createState() => _BottomFloatingChatSheetState();
}

class _BottomFloatingChatSheetState extends State<BottomFloatingChatSheet> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.style.margin,
      child: FloatingShadowSheet(
        banner: widget.shadowSheetBanner,
        editorSheet: widget.editorSheet,
        style: widget.style.shadowSheet,
      ),
    );
  }
}

class FloatingEditorStyle {
  const FloatingEditorStyle({
    this.margin = const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    this.borderRadius = const Radius.circular(28),
    this.shadow = const FloatingEditorShadow(),
    this.shadowSheetBackground = Colors.grey,
    this.shadowSheetPadding = const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 8),
    this.editorSheetBackground = Colors.white,
  });

  final EdgeInsets margin;
  final Radius borderRadius;
  final FloatingEditorShadow shadow;

  final Color shadowSheetBackground;
  final EdgeInsets shadowSheetPadding;

  final Color editorSheetBackground;

  EditorSheetStyle get editorSheet => EditorSheetStyle(
        borderRadius: borderRadius,
        background: editorSheetBackground,
      );

  FloatingShadowSheetStyle get shadowSheet => FloatingShadowSheetStyle(
        borderRadius: borderRadius,
        background: shadowSheetBackground,
        padding: shadowSheetPadding,
        shadow: shadow,
      );
}

/// Shadow configuration for a [BottomFloatingChatSheet].
///
/// This configuration is a custom selection of properties because with the way that
/// the bottom sheet is clipped, a shadow with any y-offset will look buggy. Therefore,
/// we can't allow for a typical `BoxShadow` or other shadow configuration. We can only
/// support a color and a blur amount.
class FloatingEditorShadow {
  const FloatingEditorShadow({
    this.color = const Color(0x33000000),
    this.blur = 12,
  });

  final Color color;
  final double blur;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FloatingEditorShadow && runtimeType == other.runtimeType && color == other.color && blur == other.blur;

  @override
  int get hashCode => color.hashCode ^ blur.hashCode;
}

/// A superellipse sheet which has a [banner] at the top and an [editorSheet] below that.
///
/// This widget paints a superellipse background around the [banner] and the [editorSheet], but
/// it then cuts out another superellipse around the [editorSheet]. The final effect is as if the
/// [banner] is popping up from behind the [editorSheet], but in such a way that the [editorSheet]
/// can be translucent, showing what's behind it.
class FloatingShadowSheet extends SlottedMultiChildRenderObjectWidget<ShadowSheetSlot, RenderBox> {
  const FloatingShadowSheet({
    super.key,
    this.banner,
    required this.editorSheet,
    this.style = const FloatingShadowSheetStyle(),
  });

  /// The banner that's displayed within the shadow sheet, just above the [editorSheet].
  final Widget? banner;

  /// A floating editor sheet that sits on top of this shadow sheet, aligned a the bottom.
  final Widget editorSheet;

  /// The visual style of this shadow sheet.
  final FloatingShadowSheetStyle style;

  @override
  Iterable<ShadowSheetSlot> get slots => ShadowSheetSlot.values;

  @override
  Widget? childForSlot(ShadowSheetSlot slot) {
    switch (slot) {
      case ShadowSheetSlot.banner:
        return banner;
      case ShadowSheetSlot.editorSheet:
        return editorSheet;
    }
  }

  @override
  RenderShadowSheet createRenderObject(BuildContext context) {
    return RenderShadowSheet(style: style);
  }

  @override
  void updateRenderObject(BuildContext context, RenderShadowSheet renderObject) {
    renderObject.style = style;
  }
}

class FloatingShadowSheetStyle {
  const FloatingShadowSheetStyle({
    this.background = Colors.grey,
    this.padding = const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 8),
    this.borderRadius = const Radius.circular(28),
    this.shadow = const FloatingEditorShadow(),
  });

  final Color background;
  final EdgeInsets padding;
  final Radius borderRadius;
  final FloatingEditorShadow shadow;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FloatingShadowSheetStyle &&
          runtimeType == other.runtimeType &&
          background == other.background &&
          padding == other.padding &&
          borderRadius == other.borderRadius &&
          shadow == other.shadow;

  @override
  int get hashCode => background.hashCode ^ padding.hashCode ^ borderRadius.hashCode ^ shadow.hashCode;
}

enum ShadowSheetSlot {
  banner,
  editorSheet;
}

class RenderShadowSheet extends RenderBox with SlottedContainerRenderObjectMixin<ShadowSheetSlot, RenderBox> {
  RenderShadowSheet({
    required FloatingShadowSheetStyle style,
  }) : _style = style;

  FloatingShadowSheetStyle _style;
  set style(FloatingShadowSheetStyle newStyle) {
    if (newStyle == _style) {
      return;
    }

    _style = newStyle;
    markNeedsLayout();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final editorSheet = childForSlot(ShadowSheetSlot.editorSheet)!;
    final editorSheetSize = editorSheet.computeDryLayout(constraints);

    final banner = childForSlot(ShadowSheetSlot.banner);
    // We force the banner to be the same width as the editor sheet.
    final bannerContentWidth = editorSheetSize.width - _style.padding.horizontal;
    final bannerSize = banner?.computeDryLayout(
          constraints.copyWith(minWidth: bannerContentWidth, maxWidth: bannerContentWidth),
        ) ??
        Size.zero;
    final bannerAndPadding = banner != null
        ? Size(bannerSize.width + _style.padding.horizontal, bannerSize.height + _style.padding.vertical)
        : Size.zero;

    return Size(editorSheetSize.width, bannerAndPadding.height + editorSheetSize.height);
  }

  @override
  bool hitTestSelf(Offset position) => false;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final slot in ShadowSheetSlot.values) {
      final child = childForSlot(slot);
      if (child == null) {
        continue;
      }

      final childParentData = child.parentData as BoxParentData;
      final isHit = result.addWithPaintOffset(
        offset: childParentData.offset,
        position: position,
        hitTest: (BoxHitTestResult result, Offset transformed) {
          return child.hitTest(result, position: transformed);
        },
      );

      if (isHit) {
        return true; // stop if a child was hit
      }
    }

    return false;
  }

  @override
  void performLayout() {
    final editorSheet = childForSlot(ShadowSheetSlot.editorSheet)!;
    editorSheet.layout(constraints, parentUsesSize: true);
    var editorSheetSize = editorSheet.size;

    final banner = childForSlot(ShadowSheetSlot.banner);
    // We force the banner to be the same width as the editor sheet.
    final bannerContentWidth = editorSheetSize.width - _style.padding.horizontal;
    banner?.layout(
      constraints.copyWith(minWidth: bannerContentWidth, maxWidth: bannerContentWidth),
      parentUsesSize: true,
    );
    final bannerSize = banner?.size ?? Size.zero;
    final bannerAndPaddingHeight = banner != null ? bannerSize.height + _style.padding.vertical : 0.0;

    // If the banner + editor ended up being taller than allowed, re-layout the
    // editor, forcing it to be shorter.
    if (bannerAndPaddingHeight + editorSheetSize.height > constraints.maxHeight) {
      editorSheet.layout(
        constraints.copyWith(maxHeight: constraints.maxHeight - bannerAndPaddingHeight),
        parentUsesSize: true,
      );
      editorSheetSize = editorSheet.size;
    }

    // Show the banner at the top, with the editor sheet below it.
    banner?.parentData = BoxParentData()..offset = Offset(_style.padding.left, _style.padding.top);
    editorSheet.parentData = BoxParentData()..offset = Offset(0, bannerAndPaddingHeight);

    // The editor sheet determines our width - we don't want to expand the editor
    // sheet to fit a wide banner width.
    size = Size(editorSheetSize.width, bannerAndPaddingHeight + editorSheetSize.height);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final banner = childForSlot(ShadowSheetSlot.banner);
    final editorSheet = childForSlot(ShadowSheetSlot.editorSheet)!;

    final editorSheetOffset = offset + (editorSheet.parentData as BoxParentData).offset;
    final editorSheetBoundary = Path()
      ..addRSuperellipse(
        RSuperellipse.fromLTRBR(
          editorSheetOffset.dx,
          editorSheetOffset.dy,
          editorSheetOffset.dx + size.width,
          editorSheetOffset.dy + editorSheet.size.height,
          _style.borderRadius,
        ),
      );

    // Shadow sheet includes the banner and the editor sheet.
    final shadowSheetBoundary = RSuperellipse.fromLTRBR(
      offset.dx,
      offset.dy,
      offset.dx + size.width,
      offset.dy + size.height,
      _style.borderRadius,
    );
    final shadowSheetBoundaryPath = Path()..addRSuperellipse(shadowSheetBoundary);

    // Paint the shadow for the entire shadow sheet.
    // final shadowPaint = Paint()
    //   ..color = Colors.black.withValues(alpha: 0.2)
    //   ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12);
    final shadowPaint = Paint()
      ..color = _style.shadow.color
      // Note: We use a normal blur instead of an outer blur because we have to
      // clip the shadow no matter what. If we do an outer blur without clipping
      // the shadow then any backdrop blur that the editor sheet applies will pull
      // in a little bit of that surrounding shadow, giving a beveled or shaded edge
      // look that we don't want.
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, _style.shadow.blur);

    context.canvas.saveLayer(null, Paint());
    context.canvas
      ..save()
      ..drawPath(shadowSheetBoundaryPath, shadowPaint);
    context.canvas.restore();

    // Cut the sheet out of the shadow, so the sheet can be translucent without
    // showing an ugly shadow behind it.
    final clearPaint = Paint()..blendMode = BlendMode.dstOut;
    context.canvas.drawPath(shadowSheetBoundaryPath, clearPaint);

    // Paint the shadow sheet and the banner at the top of the shadow sheet.
    //
    // This also requires cutting the editor sheet out of the shadow sheet, to
    // support translucent editor sheets.
    if (banner != null) {
      final hollowShadowSheet = Path.combine(PathOperation.xor, shadowSheetBoundaryPath, editorSheetBoundary);
      context.canvas.drawPath(hollowShadowSheet, Paint()..color = _style.background);

      // Clip the banner at the shadow sheet boundary.
      context.canvas
        ..save()
        ..clipRSuperellipse(shadowSheetBoundary);

      banner.paint(context, offset + (banner.parentData as BoxParentData).offset);

      // Get rid of the banner clip.
      context.canvas.restore();
    }

    // Clip any part of the editor sheet outside the expected superellipse shape.
    //
    // We do this by pushing a clip layer because there's a high likelihood that the editor
    // sheet blurs its backdrop, which can only be clipped by pushing a clip path.
    final clipLayer = (layer as ClipPathLayer? ?? ClipPathLayer())
      ..clipPath = editorSheetBoundary
      ..clipBehavior = Clip.hardEdge;
    layer = clipLayer;

    context.pushLayer(clipLayer, (clippedContext, clippedOffset) {
      // Paint the editor sheet.
      editorSheet.paint(clippedContext, clippedOffset);
    }, editorSheetOffset);
  }
}

/// A super ellipse sheet, which contains a drag handle, editor, and toolbar.
class FloatingEditorSheet extends StatefulWidget {
  const FloatingEditorSheet({
    super.key,
    this.sheetKey,
    required this.messagePageController,
    required this.editor,
    this.style = const EditorSheetStyle(),
  });

  /// A [GlobalKey] that's attached to the outermost boundary of the sheet that
  /// contains this [FloatingEditorSheet].
  ///
  /// In the typical case, [FloatingEditorSheet] is the outermost boundary, in which case
  /// no key needs to be provided. This widget will create a key internally.
  ///
  /// However, if additional content is added above or below this [FloatingEditorSheet] then
  /// we need to be able to account for the global offset of that content. To make layout
  /// decisions based on the entire sheet, clients must wrap the whole sheet with a [GlobalKey]
  /// and provide that key as [sheetKey].
  final GlobalKey? sheetKey;

  final MessagePageController messagePageController;

  final Widget editor;

  final EditorSheetStyle style;

  @override
  State<FloatingEditorSheet> createState() => _FloatingEditorSheetState();
}

class _FloatingEditorSheetState extends State<FloatingEditorSheet> {
  // final _dragIndicatorKey = GlobalKey();

  final _scrollController = ScrollController();

  final _editorFocusNode = FocusNode();
  late GlobalKey _sheetKey;
  final _editorSheetKey = GlobalKey(debugLabel: "editor-sheet-within-bigger-sheet");
  // late final Editor _editor;
  // late final SoftwareKeyboardController _softwareKeyboardController;

  // final _hasSelection = ValueNotifier(false);

  bool _isUserPressingDown = false;

  @override
  void initState() {
    super.initState();

    // _softwareKeyboardController = SoftwareKeyboardController();

    _sheetKey = widget.sheetKey ?? GlobalKey();

    // _editor = createDefaultDocumentEditor(
    //   document: MutableDocument.empty(),
    //   composer: MutableDocumentComposer(),
    // );
    // _editor.composer.selectionNotifier.addListener(_onSelectionChange);
  }

  @override
  void didUpdateWidget(FloatingEditorSheet oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.sheetKey != _sheetKey) {
      _sheetKey = widget.sheetKey ?? GlobalKey();
    }
  }

  @override
  void dispose() {
    // _editor.composer.selectionNotifier.removeListener(_onSelectionChange);
    // _editor.dispose();

    _editorFocusNode.dispose();

    _scrollController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      // If we're provided with a [widget.sheetKey] it means the full sheet boundary
      // expands beyond this widget, and that key is attached to that outer boundary.
      // If we're not provided with a [widget.sheetKey], it's because we are the outer
      // boundary, so we need to key our subtree for layout calculations.
      key: widget.sheetKey == null ? _sheetKey : _editorSheetKey,
      child: Listener(
        onPointerDown: (_) => setState(() {
          _isUserPressingDown = true;
        }),
        onPointerUp: (_) => setState(() {
          _isUserPressingDown = false;
        }),
        onPointerCancel: (_) => setState(() {
          _isUserPressingDown = false;
        }),
        child: ClipRSuperellipse(
          borderRadius: BorderRadius.all(widget.style.borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4, tileMode: TileMode.decal),
            child: Container(
              decoration: ShapeDecoration(
                color: widget.style.background.withValues(alpha: _isUserPressingDown ? 1.0 : 0.8),
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.all(widget.style.borderRadius),
                ),
              ),
              child: KeyboardScaffoldSafeArea(
                child: widget.editor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EditorSheetStyle {
  const EditorSheetStyle({
    this.background = Colors.white,
    this.borderRadius = const Radius.circular(28),
  });

  final Color background;
  final Radius borderRadius;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EditorSheetStyle &&
          runtimeType == other.runtimeType &&
          background == other.background &&
          borderRadius == other.borderRadius;

  @override
  int get hashCode => background.hashCode ^ borderRadius.hashCode;
}
