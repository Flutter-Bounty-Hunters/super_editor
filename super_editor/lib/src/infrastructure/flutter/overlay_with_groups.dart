import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';

/// An [OverlayPortalController], which re-orders itself with all other [GroupedOverlayPortalController]s
/// such that each controller's [displayPriority] is honored by their z-indices.
///
/// For example, regardless of when they're shown, if there three [GroupedOverlayPortalController]s
/// with priorities of `10`, `100`, and `1`, those overlays will be displayed in the order of
/// `1`, `10`, `100`. In other words, the overlay with priority of `100` appears in front of
/// the one with `10`, which appears in front of the one with `1`. Z-index re-ordering occurs
/// every time a [GroupedOverlayPortalController] is [show]n.
///
/// Priority is based on an [OverlayGroupPriority]. There are some priority levels that are already
/// defined for common use-cases, so that those use-cases remain consistent across apps.
class GroupedOverlayPortalController extends OverlayPortalController {
  static final _visibleControllers =
      PriorityQueue<GroupedOverlayPortalController>((a, b) => a.displayPriority.compareTo(b.displayPriority));

  static bool _isReworkingOrder = false;

  static void _show(GroupedOverlayPortalController controller) {
    if (_isReworkingOrder) {
      return;
    }

    if (controller.isShowing) {
      return;
    }

    // A listed controller that isn't showing was detached from its OverlayPortal without being
    // hidden, e.g., because the OverlayPortal left the tree. Drop it, so that we don't show it
    // again below.
    for (final listedController in _visibleControllers.toUnorderedList()) {
      if (!listedController.isShowing) {
        _visibleControllers.remove(listedController);
      }
    }

    if (!_visibleControllers.contains(controller)) {
      _visibleControllers.add(controller);
    }

    _isReworkingOrder = true;

    // When calling `show()` on an `OverlayPortalController` that's already visible, its
    // overlay becomes the top overlay in the stack. Therefore, by calling `show()` on all
    // of our controllers, from low priority to high priority, we ensure the desired painting order.
    for (final visiblePortal in _visibleControllers.toList()) {
      visiblePortal.show();
    }

    _isReworkingOrder = false;
  }

  static void _hide(GroupedOverlayPortalController controller) {
    if (_isReworkingOrder) {
      return;
    }

    _isReworkingOrder = true;

    _visibleControllers.remove(controller);
    controller.hide();

    _isReworkingOrder = false;
  }

  GroupedOverlayPortalController({
    required this.displayPriority,
    super.debugLabel,
  });

  /// Relative display priority which determines the z-index of this [GroupedOverlayPortalController]
  /// relative to other [GroupedOverlayPortalController]s in the app [Overlay].
  final OverlayGroupPriority displayPriority;

  @override
  void show() {
    if (!_isReworkingOrder) {
      _show(this);
      return;
    }

    super.show();
  }

  @override
  void hide() {
    if (!_isReworkingOrder) {
      _hide(this);
      return;
    }

    super.hide();
  }
}

class OverlayGroupPriority implements Comparable<OverlayGroupPriority> {
  /// Standard group priority for editing controls, e.g., drag handles, toolbars,
  /// magnifiers.
  static const editingControls = OverlayGroupPriority(10000);

  /// Standard group priority for window chrome, e.g., a toolbar mounted above the
  /// software keyboard.
  static const windowChrome = OverlayGroupPriority(1000000);

  const OverlayGroupPriority(this.priority);

  /// Relative priority for display z-index - higher priority means higher on the
  /// z-index stack, e.g., a priority of `1000` will appear in front of a priority
  /// of `10`, which will appear in front of a priority of `1`.
  final int priority;

  @override
  int compareTo(OverlayGroupPriority other) => priority.compareTo(other.priority);
}
