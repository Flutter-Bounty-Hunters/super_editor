import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

const double _kToolbarHeight = 54.0;

/// A toolbar containing the given children. If they overflow the width
/// available, then the overflowing children will be displayed in an overflow
/// menu.
///
/// Extracted from Flutter's Material text selection toolbar implementation
/// from flutter/packages/flutter/lib/src/material/text_selection_toolbar.dart
class AndroidPopoverToolbar extends StatefulWidget {
  const AndroidPopoverToolbar({
    required this.isAbove,
    required this.toolbarBuilder,
    required this.children,
  });

  final List<Widget> children;

  // When true, the toolbar fits above its anchor and will be positioned there.
  final bool isAbove;

  // Builds the toolbar that will be populated with the children and fit inside
  // of the layout that adjusts to overflow.
  final ToolbarBuilder toolbarBuilder;

  @override
  _AndroidPopoverToolbarState createState() => _AndroidPopoverToolbarState();
}

class _AndroidPopoverToolbarState extends State<AndroidPopoverToolbar> with TickerProviderStateMixin {
  // Whether or not the overflow menu is open. When it is closed, the menu
  // items that don't overflow are shown. When it is open, only the overflowing
  // menu items are shown.
  bool _overflowOpen = false;

  // The key for _TextSelectionToolbarTrailingEdgeAlign.
  UniqueKey _containerKey = UniqueKey();

  // Close the menu and reset layout calculations, as in when the menu has
  // changed and saved values are no longer relevant. This should be called in
  // setState or another context where a rebuild is happening.
  void _reset() {
    // Change _TextSelectionToolbarTrailingEdgeAlign's key when the menu changes
    // in order to cause it to rebuild. This lets it recalculate its
    // saved width for the new set of children, and it prevents AnimatedSize
    // from animating the size change.
    _containerKey = UniqueKey();
    // If the menu items change, make sure the overflow menu is closed. This
    // prevents getting into a broken state where _overflowOpen is true when
    // there are not enough children to cause overflow.
    _overflowOpen = false;
  }

  @override
  void didUpdateWidget(AndroidPopoverToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the children are changing at all, the current page should be reset.
    if (!listEquals(widget.children, oldWidget.children)) {
      _reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterialLocalizations(context));
    final MaterialLocalizations localizations = MaterialLocalizations.of(context);
    final TextDirection textDirection = Directionality.of(context);

    return _TextSelectionToolbarTrailingEdgeAlign(
      key: _containerKey,
      overflowOpen: _overflowOpen,
      textDirection: textDirection,
      child: AnimatedSize(
        // This duration was eyeballed on a Pixel 2 emulator running Android
        // API 28.
        duration: const Duration(milliseconds: 140),
        child: widget.toolbarBuilder(
          context,
          _TextSelectionToolbarItemsLayout(
            isAbove: widget.isAbove,
            overflowOpen: _overflowOpen,
            textDirection: textDirection,
            children: <Widget>[
              // TODO(justinmc): This overflow button should have its own slot in
              // _TextSelectionToolbarItemsLayout separate from children, similar
              // to how it's done in Cupertino's text selection menu.
              // https://github.com/flutter/flutter/issues/69908
              // The navButton that shows and hides the overflow menu is the
              // first child.
              _TextSelectionToolbarOverflowButton(
                key: _overflowOpen ? StandardComponentType.backButton.key : StandardComponentType.moreButton.key,
                icon: Icon(_overflowOpen ? Icons.arrow_back : Icons.more_vert),
                onPressed: () {
                  setState(() {
                    _overflowOpen = !_overflowOpen;
                  });
                },
                tooltip: _overflowOpen ? localizations.backButtonTooltip : localizations.moreButtonTooltip,
              ),
              ...widget.children,
            ],
          ),
        ),
      ),
    );
  }
}

// When the overflow menu is open, it tries to align its trailing edge to the
// trailing edge of the closed menu. This widget handles this effect by
// measuring and maintaining the width of the closed menu and aligning the child
// to that side.
class _TextSelectionToolbarTrailingEdgeAlign extends SingleChildRenderObjectWidget {
  const _TextSelectionToolbarTrailingEdgeAlign({
    super.key,
    required Widget super.child,
    required this.overflowOpen,
    required this.textDirection,
  });

  final bool overflowOpen;
  final TextDirection textDirection;

  @override
  _TextSelectionToolbarTrailingEdgeAlignRenderBox createRenderObject(BuildContext context) {
    return _TextSelectionToolbarTrailingEdgeAlignRenderBox(
      overflowOpen: overflowOpen,
      textDirection: textDirection,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _TextSelectionToolbarTrailingEdgeAlignRenderBox renderObject,
  ) {
    renderObject
      ..overflowOpen = overflowOpen
      ..textDirection = textDirection;
  }
}

class _TextSelectionToolbarTrailingEdgeAlignRenderBox extends RenderProxyBox {
  _TextSelectionToolbarTrailingEdgeAlignRenderBox({
    required bool overflowOpen,
    required TextDirection textDirection,
  })  : _textDirection = textDirection,
        _overflowOpen = overflowOpen,
        super();

  // The width of the menu when it was closed. This is used to achieve the
  // behavior where the open menu aligns its trailing edge to the closed menu's
  // trailing edge.
  double? _closedWidth;

  bool _overflowOpen;
  bool get overflowOpen => _overflowOpen;
  set overflowOpen(bool value) {
    if (value == overflowOpen) {
      return;
    }
    _overflowOpen = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection value) {
    if (value == textDirection) {
      return;
    }
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    child!.layout(constraints.loosen(), parentUsesSize: true);

    // Save the width when the menu is closed. If the menu changes, this width
    // is invalid, so it's important that this RenderBox be recreated in that
    // case. Currently, this is achieved by providing a new key to
    // _TextSelectionToolbarTrailingEdgeAlign.
    if (!overflowOpen && _closedWidth == null) {
      _closedWidth = child!.size.width;
    }

    size = constraints.constrain(
      Size(
        // If the open menu is wider than the closed menu, just use its own width
        // and don't worry about aligning the trailing edges.
        // _closedWidth is used even when the menu is closed to allow it to
        // animate its size while keeping the same edge alignment.
        _closedWidth == null || child!.size.width > _closedWidth! ? child!.size.width : _closedWidth!,
        child!.size.height,
      ),
    );

    // Set the offset in the parent data such that the child will be aligned to
    // the trailing edge, depending on the text direction.
    final ToolbarItemsParentData childParentData = child!.parentData! as ToolbarItemsParentData;
    childParentData.offset = Offset(
      textDirection == TextDirection.rtl ? 0.0 : size.width - child!.size.width,
      0.0,
    );
  }

  // Paint at the offset set in the parent data.
  @override
  void paint(PaintingContext context, Offset offset) {
    final ToolbarItemsParentData childParentData = child!.parentData! as ToolbarItemsParentData;
    context.paintChild(child!, childParentData.offset + offset);
  }

  // Include the parent data offset in the hit test.
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    // The x, y parameters have the top left of the node's box as the origin.
    final ToolbarItemsParentData childParentData = child!.parentData! as ToolbarItemsParentData;
    return result.addWithPaintOffset(
      offset: childParentData.offset,
      position: position,
      hitTest: (BoxHitTestResult result, Offset transformed) {
        assert(transformed == position - childParentData.offset);
        return child!.hitTest(result, position: transformed);
      },
    );
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! ToolbarItemsParentData) {
      child.parentData = ToolbarItemsParentData();
    }
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    final ToolbarItemsParentData childParentData = child.parentData! as ToolbarItemsParentData;
    transform.translateByDouble(childParentData.offset.dx, childParentData.offset.dy, 0, 1);
    super.applyPaintTransform(child, transform);
  }
}

// Renders the menu items in the correct positions in the menu and its overflow
// submenu based on calculating which item would first overflow.
class _TextSelectionToolbarItemsLayout extends MultiChildRenderObjectWidget {
  const _TextSelectionToolbarItemsLayout({
    required this.isAbove,
    required this.overflowOpen,
    required this.textDirection,
    required super.children,
  });

  final bool isAbove;
  final bool overflowOpen;
  final TextDirection textDirection;

  @override
  _RenderTextSelectionToolbarItemsLayout createRenderObject(BuildContext context) {
    return _RenderTextSelectionToolbarItemsLayout(
      isAbove: isAbove,
      overflowOpen: overflowOpen,
      textDirection: textDirection,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderTextSelectionToolbarItemsLayout renderObject,
  ) {
    renderObject
      ..isAbove = isAbove
      ..textDirection = textDirection
      ..overflowOpen = overflowOpen;
  }

  @override
  _TextSelectionToolbarItemsLayoutElement createElement() => _TextSelectionToolbarItemsLayoutElement(this);
}

class _TextSelectionToolbarItemsLayoutElement extends MultiChildRenderObjectElement {
  _TextSelectionToolbarItemsLayoutElement(super.widget);

  static bool _shouldPaint(Element child) {
    return (child.renderObject!.parentData! as ToolbarItemsParentData).shouldPaint;
  }

  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    children.where(_shouldPaint).forEach(visitor);
  }
}

class _RenderTextSelectionToolbarItemsLayout extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, ToolbarItemsParentData> {
  _RenderTextSelectionToolbarItemsLayout({
    required bool isAbove,
    required bool overflowOpen,
    required TextDirection textDirection,
  })  : _isAbove = isAbove,
        _overflowOpen = overflowOpen,
        _textDirection = textDirection,
        super();

  // The index of the last item that doesn't overflow.
  int _lastIndexThatFits = -1;

  bool _isAbove;
  bool get isAbove => _isAbove;
  set isAbove(bool value) {
    if (value == isAbove) {
      return;
    }
    _isAbove = value;
    markNeedsLayout();
  }

  bool _overflowOpen;
  bool get overflowOpen => _overflowOpen;
  set overflowOpen(bool value) {
    if (value == overflowOpen) {
      return;
    }
    _overflowOpen = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection value) {
    if (value == textDirection) {
      return;
    }
    _textDirection = value;
    markNeedsLayout();
  }

  // Layout the necessary children, and figure out where the children first
  // overflow, if at all.
  void _layoutChildren() {
    // When overflow is not open, the toolbar is always a specific height.
    final BoxConstraints sizedConstraints =
        _overflowOpen ? constraints : BoxConstraints.loose(Size(constraints.maxWidth, _kToolbarHeight));

    int i = -1;
    double width = 0.0;
    visitChildren((RenderObject renderObjectChild) {
      i++;

      // No need to layout children inside the overflow menu when it's closed.
      // The opposite is not true. It is necessary to layout the children that
      // don't overflow when the overflow menu is open in order to calculate
      // _lastIndexThatFits.
      if (_lastIndexThatFits != -1 && !overflowOpen) {
        return;
      }

      final RenderBox child = renderObjectChild as RenderBox;
      child.layout(sizedConstraints.loosen(), parentUsesSize: true);
      width += child.size.width;

      if (width > sizedConstraints.maxWidth && _lastIndexThatFits == -1) {
        _lastIndexThatFits = i - 1;
      }
    });

    // If the last child overflows, but only because of the width of the
    // overflow button, then just show it and hide the overflow button.
    final RenderBox navButton = firstChild!;
    if (_lastIndexThatFits != -1 &&
        _lastIndexThatFits == childCount - 2 &&
        width - navButton.size.width <= sizedConstraints.maxWidth) {
      _lastIndexThatFits = -1;
    }
  }

  // Returns true when the child should be painted, false otherwise.
  bool _shouldPaintChild(RenderObject renderObjectChild, int index) {
    // Paint the navButton when there is overflow.
    if (renderObjectChild == firstChild) {
      return _lastIndexThatFits != -1;
    }

    // If there is no overflow, all children besides the navButton are painted.
    if (_lastIndexThatFits == -1) {
      return true;
    }

    // When there is overflow, paint if the child is in the part of the menu
    // that is currently open. Overflowing children are painted when the
    // overflow menu is open, and the children that fit are painted when the
    // overflow menu is closed.
    return (index > _lastIndexThatFits) == overflowOpen;
  }

  /// Horizontal layout.
  Size _placeChildrenHorizontally() {
    final RenderBox navButton = firstChild!;
    final bool isRtl = textDirection == TextDirection.rtl;

    final List<RenderBox> contentItems = <RenderBox>[];

    double totalWidth = 0.0;
    double maxHeight = 0.0;

    // First pass: calculate dimensions and collect items.
    int i = -1;
    visitChildren((RenderObject renderObjectChild) {
      final RenderBox child = renderObjectChild as RenderBox;
      final ToolbarItemsParentData childParentData = child.parentData! as ToolbarItemsParentData;
      i++;

      if (!_shouldPaintChild(child, i)) {
        // There is no need to update children that won't be painted.
        childParentData.shouldPaint = false;
      } else {
        childParentData.shouldPaint = true;

        totalWidth += child.size.width;
        maxHeight = math.max(maxHeight, child.size.height);

        if (child != navButton) {
          contentItems.add(child);
        }
      }
    });

    // Position items based on text direction.
    double currentX = 0.0;
    final bool showNavButton = _lastIndexThatFits >= 0;

    if (isRtl) {
      // In RTL, we want the nav button on the left and items right-aligned.
      if (showNavButton) {
        final ToolbarItemsParentData navParentData = navButton.parentData! as ToolbarItemsParentData;
        navParentData.offset = Offset.zero;
        currentX += navButton.size.width;
      }

      // Position content items from right to left.
      double rightEdge = totalWidth;
      for (final RenderBox item in contentItems) {
        rightEdge -= item.size.width;
        final ToolbarItemsParentData itemParentData = item.parentData! as ToolbarItemsParentData;
        itemParentData.offset = Offset(rightEdge, 0.0);
      }
    } else {
      // LTR: Place content items first, then nav button.
      // First position all content items from left to right.
      for (final RenderBox item in contentItems) {
        final ToolbarItemsParentData itemParentData = item.parentData! as ToolbarItemsParentData;
        itemParentData.offset = Offset(currentX, 0.0);
        currentX += item.size.width;
      }

      // Then place the nav button at the end.
      if (showNavButton) {
        final ToolbarItemsParentData navParentData = navButton.parentData! as ToolbarItemsParentData;
        navParentData.offset = Offset(currentX, 0.0);
      }
    }

    return Size(totalWidth, maxHeight);
  }

  /// Vertical layout (overflow menu).
  Size _placeChildrenVertically() {
    final RenderBox navButton = firstChild!;

    double currentY = 0.0;
    double maxWidth = 0.0;

    final ToolbarItemsParentData navButtonParentData = navButton.parentData! as ToolbarItemsParentData;

    if (_shouldPaintChild(navButton, 0)) {
      navButtonParentData.shouldPaint = true;
      if (!isAbove) {
        navButtonParentData.offset = Offset.zero;
        currentY += navButton.size.height;
        maxWidth = math.max(maxWidth, navButton.size.width);
      }
    } else {
      navButtonParentData.shouldPaint = false;
    }

    int i = -1;
    visitChildren((RenderObject renderObjectChild) {
      final RenderBox child = renderObjectChild as RenderBox;
      final ToolbarItemsParentData childParentData = child.parentData! as ToolbarItemsParentData;

      i++;

      // Ignore the navigation button.
      if (renderObjectChild == navButton) {
        return;
      }

      // There is no need to update children that won't be painted.
      if (!_shouldPaintChild(child, i)) {
        childParentData.shouldPaint = false;
        return;
      }

      childParentData.shouldPaint = true;
      childParentData.offset = Offset(0.0, currentY);
      currentY += child.size.height;
      maxWidth = math.max(maxWidth, child.size.width);
    });

    if (isAbove && navButtonParentData.shouldPaint) {
      navButtonParentData.offset = Offset(0.0, currentY);
      currentY += navButton.size.height;
      maxWidth = math.max(maxWidth, navButton.size.width);
    }

    maxWidth += 20;

    return Size(maxWidth, currentY);
  }

  // Decide which children will be painted, set their shouldPaint, and set the
  // offset that painted children will be placed at.
  void _placeChildren() {
    size = overflowOpen ? _placeChildrenVertically() : _placeChildrenHorizontally();
  }

  // Horizontally expand the children when the menu overflows so they can react to
  // pointer events into their whole area.
  void _resizeChildrenWhenOverflow() {
    if (!overflowOpen) {
      return;
    }

    final RenderBox navButton = firstChild!;
    int i = -1;

    visitChildren((RenderObject renderObjectChild) {
      final RenderBox child = renderObjectChild as RenderBox;
      final ToolbarItemsParentData childParentData = child.parentData! as ToolbarItemsParentData;

      i++;

      // Ignore the navigation button.
      if (renderObjectChild == navButton) {
        return;
      }

      // There is no need to update children that won't be painted.
      if (!_shouldPaintChild(renderObjectChild, i)) {
        childParentData.shouldPaint = false;
        return;
      }

      child.layout(BoxConstraints.tightFor(width: size.width), parentUsesSize: true);
    });
  }

  @override
  void performLayout() {
    _lastIndexThatFits = -1;
    if (firstChild == null) {
      size = constraints.smallest;
      return;
    }

    _layoutChildren();
    _placeChildren();
    _resizeChildrenWhenOverflow();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    visitChildren((RenderObject renderObjectChild) {
      final RenderBox child = renderObjectChild as RenderBox;
      final ToolbarItemsParentData childParentData = child.parentData! as ToolbarItemsParentData;
      if (!childParentData.shouldPaint) {
        return;
      }

      context.paintChild(child, childParentData.offset + offset);
    });
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! ToolbarItemsParentData) {
      child.parentData = ToolbarItemsParentData();
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    RenderBox? child = lastChild;
    while (child != null) {
      // The x, y parameters have the top left of the node's box as the origin.
      final ToolbarItemsParentData childParentData = child.parentData! as ToolbarItemsParentData;

      // Don't hit test children aren't shown.
      if (!childParentData.shouldPaint) {
        child = childParentData.previousSibling;
        continue;
      }

      final bool isHit = result.addWithPaintOffset(
        offset: childParentData.offset,
        position: position,
        hitTest: (BoxHitTestResult result, Offset transformed) {
          assert(transformed == position - childParentData.offset);
          return child!.hitTest(result, position: transformed);
        },
      );
      if (isHit) {
        return true;
      }
      child = childParentData.previousSibling;
    }
    return false;
  }

  // Visit only the children that should be painted.
  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    visitChildren((RenderObject renderObjectChild) {
      final RenderBox child = renderObjectChild as RenderBox;
      final ToolbarItemsParentData childParentData = child.parentData! as ToolbarItemsParentData;
      if (childParentData.shouldPaint) {
        visitor(renderObjectChild);
      }
    });
  }
}

// The Material-styled toolbar outline. Fill it with any widgets you want. No
// overflow ability.
class AndroidPopoverToolbarContainer extends StatelessWidget {
  const AndroidPopoverToolbarContainer({required this.child});

  final Widget child;

  // These colors were taken from a screenshot of a Pixel 6 emulator running
  // Android API level 35.
  static const Color _defaultColorLight = Color(0xFFE2E2EA);
  static const Color _defaultColorDark = Color(0xFF33343A);

  static Color _getColor(ColorScheme colorScheme) {
    return switch (colorScheme.brightness) {
      Brightness.light => _defaultColorLight,
      Brightness.dark => _defaultColorDark,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      // This value was eyeballed to match the native text selection menu on
      // a Pixel 6 emulator running Android API level 34.
      borderRadius: const BorderRadius.all(Radius.circular(_kToolbarHeight / 2)),
      clipBehavior: Clip.antiAlias,
      color: _getColor(theme.colorScheme),
      elevation: 1.0,
      type: MaterialType.card,
      child: child,
    );
  }
}

// A button styled like a Material native Android text selection overflow menu
// forward and back controls.
class _TextSelectionToolbarOverflowButton extends StatelessWidget {
  const _TextSelectionToolbarOverflowButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
  });

  final Icon icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.card,
      color: const Color(0x00000000),
      child: IconButton(
        // TODO(justinmc): This should be an AnimatedIcon, but
        // AnimatedIcons doesn't yet support arrow_back to more_vert.
        // https://github.com/flutter/flutter/issues/51209
        icon: icon,
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }
}
