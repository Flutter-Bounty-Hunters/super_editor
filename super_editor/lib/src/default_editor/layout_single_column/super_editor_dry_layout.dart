import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A custom [Viewport] that wraps a given [superEditor] so that this subtree can run
/// dry layout, reporting the intrinsic height of the [superEditor].
///
/// This widget doesn't change the actual height or scrolling behavior of `SuperEditor` - it
/// only adds the ability to ask `SuperEditor` for its size during dry layout.
///
/// If you're looking for a way to have `SuperEditor` expand its height to display all of its
/// content without internally scrolling, don't use this widget. Instead, set `shrinkWrap` to `true`
/// on `SuperEditor`.
///
/// Without this widget, `SuperEditor`s sliver layout either uses a shrink wrapping viewport,
/// which doesn't support dry layout, or a regular viewport, which throws an error during dry
/// layout if there's an unbounded height.
///
/// This widget installs a custom viewport, which supports dry layout with an unbounded height,
/// by returning the intrinsic height of [superEditor]. This works because of two things we know
/// about [superEditor]. First, we know that [superEditor] is a single widget, so we don't have to worry
/// about multiple slivers and how they interact with each other. Second, we know that
/// [superEditor] has `RenderBox`s at the top of its widget tree as ancestors above the slivers
/// deeper within [superEditor]. Therefore, the custom viewport in this widget can reach down
/// into [superEditor], find the top-level `RenderBox`, and then return the intrinsic size of
/// that `RenderBox` as the intrinsic size for the entire [superEditor]. If those two details
/// weren't true, then this approach wouldn't work.
///
/// The child of this widget is called [superEditor] because this widget was made specifically
/// to enable dry layout for a `SuperEditor`. Generally speaking, the direct child of this widget,
/// given by [superEditor] should be a `SuperEditor` widget, without any other widgets
/// between [SuperEditorDryLayout] and `SuperEditor`.
class SuperEditorDryLayout extends CustomScrollView {
  const SuperEditorDryLayout({
    super.key,
    super.scrollDirection,
    super.reverse,
    super.controller,
    super.primary,
    super.physics,
    super.scrollBehavior,
    super.shrinkWrap,
    super.center,
    super.anchor,
    super.cacheExtent,
    super.semanticChildCount,
    super.dragStartBehavior,
    super.keyboardDismissBehavior,
    super.restorationId,
    super.clipBehavior,
    super.hitTestBehavior,
    required this.superEditor,
  });

  final Widget superEditor;

  @override
  List<Widget> get slivers => [superEditor];

  @override
  Widget buildViewport(BuildContext context, ViewportOffset offset, AxisDirection axisDirection, List<Widget> slivers) {
    return ViewportWithDryLayout(
      axisDirection: axisDirection,
      offset: offset,
      slivers: slivers,
    );
  }
}

class ViewportWithDryLayout extends Viewport {
  ViewportWithDryLayout({
    super.key,
    super.axisDirection = AxisDirection.down,
    super.crossAxisDirection,
    super.anchor = 0.0,
    required super.offset,
    super.center,
    super.cacheExtent,
    super.cacheExtentStyle = CacheExtentStyle.pixel,
    super.clipBehavior = Clip.hardEdge,
    super.slivers = const <Widget>[],
  });

  @override
  RenderViewportWithDryLayout createRenderObject(BuildContext context) {
    return RenderViewportWithDryLayout(
      axisDirection: axisDirection,
      crossAxisDirection: crossAxisDirection ?? Viewport.getDefaultCrossAxisDirection(context, axisDirection),
      anchor: anchor,
      offset: offset,
      cacheExtent: cacheExtent,
      cacheExtentStyle: cacheExtentStyle,
      clipBehavior: clipBehavior,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderViewportWithDryLayout renderObject) {
    renderObject
      ..axisDirection = axisDirection
      ..crossAxisDirection = crossAxisDirection ?? Viewport.getDefaultCrossAxisDirection(context, axisDirection)
      ..anchor = anchor
      ..offset = offset
      ..cacheExtent = cacheExtent
      ..cacheExtentStyle = cacheExtentStyle
      ..clipBehavior = clipBehavior;
  }
}

class RenderViewportWithDryLayout extends RenderViewport {
  RenderViewportWithDryLayout({
    super.axisDirection,
    required super.crossAxisDirection,
    required super.offset,
    super.anchor = 0.0,
    super.center,
    super.cacheExtent,
    super.cacheExtentStyle,
    super.clipBehavior,
    super.children,
  });

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final layoutBox = _findFirstRenderBoxInSliverList(child);
    return layoutBox.computeDryLayout(constraints);
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final layoutBox = _findFirstRenderBoxInSliverList(child);
    return layoutBox.computeMaxIntrinsicWidth(height);
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    final layoutBox = _findFirstRenderBoxInSliverList(child);
    return layoutBox.computeMinIntrinsicWidth(height);
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final layoutBox = _findFirstRenderBoxInSliverList(child);
    return layoutBox.computeMaxIntrinsicHeight(width);
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    final layoutBox = _findFirstRenderBoxInSliverList(child);
    return layoutBox.computeMinIntrinsicHeight(width);
  }

  RenderSliver get child => childrenInPaintOrder.first;

  RenderBox _findFirstRenderBoxInSliverList(RenderSliver sliver) {
    RenderSliver? firstSliver;
    RenderBox? firstBox;
    sliver.visitChildren((child) {
      if (child is RenderSliver && firstSliver == null) {
        firstSliver = child;
      }
      if (child is RenderBox && firstBox == null) {
        firstBox = child;
      }
    });
    return firstSliver != null ? _findFirstRenderBoxInSliverList(firstSliver!) : firstBox!;
  }
}
