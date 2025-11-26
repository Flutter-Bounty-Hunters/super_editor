import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:flutter/gestures.dart';

/// A widget that scrolls a given [controller], either vertically or horizontally, when the user
/// interacts with the widget via a trackpad or a mouse wheel, but only when no other scrollable
/// has claimed scrolling ownership.
///
/// Integrating trackpad and mouse wheel scrolling is a challenge because those pointer and
/// scrolling events don't participate in the gesture arena. Therefore, you have to implement
/// scrolling ownership yourself.
///
/// This widget participates in a custom scrolling ownership behavior. This widget talks to
/// a [GlobalScrollLock]. The global scroll lock assigns scrolling ownership based
/// on whether a given pointer event is mostly vertical, or mostly horizontal. This way, you can
/// use a trackpad or a Magic Mouse to scroll something like a chat conversation vertically,
/// while also scrolling a table horizontally, without scrolling both at the same time.
///
/// This scroll ownership system is very basic, but it should be sufficient for common use-cases.
class SingleAxisTrackpadAndWheelScroller extends StatefulWidget {
  const SingleAxisTrackpadAndWheelScroller({
    super.key,
    required this.axis,
    required this.controller,
    required this.child,
  });

  final Axis axis;
  final ScrollController controller;
  final Widget child;

  @override
  State<SingleAxisTrackpadAndWheelScroller> createState() => _SingleAxisTrackpadAndWheelScrollerState();
}

class _SingleAxisTrackpadAndWheelScrollerState extends State<SingleAxisTrackpadAndWheelScroller> {
  final _velocitySamples = ListQueue<(Duration timestamp, double offset)>(10);

  void _onTrackpadStart(PointerPanZoomStartEvent event) {
    // Immediately stop any on-going scrolling.
    //
    // This fixes a common Flutter bug. A user fling scrolls a scrollable with a
    // trackpad, then the user touches the trackpad again to continue scrolling, or
    // to launch another fling. But when the user touches back down, the previous
    // scroll momentum continues, and there's nothing the user can do to stop it.
    // This line stops it.
    (widget.controller.position as ScrollPositionWithSingleContext).goIdle();
  }

  void _onTrackpadUpdate(PointerPanZoomUpdateEvent event) {
    switch (widget.axis) {
      case Axis.horizontal:
        if (event.panDelta.dx == 0) {
          return;
        }
        widget.controller.position.pointerScroll(-event.panDelta.dx);

      case Axis.vertical:
        if (event.panDelta.dy == 0) {
          return;
        }
        widget.controller.position.pointerScroll(-event.panDelta.dy);
    }

    // Only save 10 most recent position samples for velocity estimation.
    if (_velocitySamples.length == 10) {
      _velocitySamples.removeLast();
    }

    // Add the latest scroll offset to the velocity samples.
    _velocitySamples.addFirst(
      (event.timeStamp, widget.controller.position.pixels),
    );
  }

  void _onTrackpadEnd(PointerPanZoomEndEvent event) {
    if (_velocitySamples.length < 2) {
      // We didn't collect enough samples to calculate a velocity. Fizzle.
      return;
    }

    // Launch the scrollable with an estimated final trackpad scroll velocity.
    (widget.controller.position as ScrollPositionWithSingleContext).goBallistic(
      (_velocitySamples.first.$2 - _velocitySamples.last.$2) /
          ((_velocitySamples.first.$1 - _velocitySamples.last.$1).inMilliseconds / 1000),
    );

    // Clear the velocity log.
    _velocitySamples.clear();
  }

  void _onScrollWheel(PointerScrollEvent event) {
    switch (widget.axis) {
      case Axis.horizontal:
        if (event.scrollDelta.dx == 0) {
          return;
        }
        widget.controller.position.pointerScroll(event.scrollDelta.dx);

      case Axis.vertical:
        if (event.scrollDelta.dy == 0) {
          return;
        }
        widget.controller.position.pointerScroll(event.scrollDelta.dy);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DeferredOwnershipTrackpadAndMouseWheelScroller(
      scrollAxis: widget.axis,
      onPanZoomStart: _onTrackpadStart,
      onPanZoomUpdate: _onTrackpadUpdate,
      onPanZoomEnd: _onTrackpadEnd,
      onScrollWheel: _onScrollWheel,
      child: widget.child,
    );
  }
}

/// A widget that forwards callbacks for trackpad and mouse wheel events, but only when this
/// widget has obtained the global scrolling lock from the [GlobalScrollLock].
class _DeferredOwnershipTrackpadAndMouseWheelScroller extends StatefulWidget {
  const _DeferredOwnershipTrackpadAndMouseWheelScroller({
    required this.scrollAxis,
    this.onPanZoomStart,
    this.onPanZoomUpdate,
    this.onPanZoomEnd,
    this.onScrollWheel,
    required this.child,
  });

  final Axis scrollAxis;

  final void Function(PointerPanZoomStartEvent)? onPanZoomStart;
  final void Function(PointerPanZoomUpdateEvent)? onPanZoomUpdate;
  final void Function(PointerPanZoomEndEvent)? onPanZoomEnd;
  final void Function(PointerScrollEvent)? onScrollWheel;

  final Widget child;

  @override
  State<_DeferredOwnershipTrackpadAndMouseWheelScroller> createState() =>
      _DeferredOwnershipTrackpadAndMouseWheelScrollerState();
}

class _DeferredOwnershipTrackpadAndMouseWheelScrollerState
    extends State<_DeferredOwnershipTrackpadAndMouseWheelScroller> {
  void _onTrackpadStart(PointerPanZoomStartEvent e) {
    widget.onPanZoomStart?.call(e);
  }

  void _onTrackpadUpdate(PointerPanZoomUpdateEvent e) {
    if (GlobalScrollLock.instance._owner == null) {
      switch (widget.scrollAxis) {
        case Axis.horizontal:
          if (e.panDelta.dx.abs() > e.panDelta.dy.abs()) {
            GlobalScrollLock.instance.requestLock(this);
          }
        case Axis.vertical:
          if (e.panDelta.dy.abs() > e.panDelta.dx.abs()) {
            GlobalScrollLock.instance.requestLock(this);
          }
      }
    }

    if (GlobalScrollLock.instance._owner != this) {
      return;
    }

    widget.onPanZoomUpdate?.call(e);
  }

  void _onTrackpadEnd(PointerPanZoomEndEvent e) {
    if (GlobalScrollLock.instance._owner != this) {
      return;
    }

    widget.onPanZoomEnd?.call(e);
    GlobalScrollLock.instance.release(this);
  }

  void _onScrollWheelChange(PointerScrollEvent e) {
    if (GlobalScrollLock.instance._owner != null) {
      return;
    }

    widget.onScrollWheel?.call(e);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerPanZoomStart: _onTrackpadStart,
      onPointerPanZoomUpdate: _onTrackpadUpdate,
      onPointerPanZoomEnd: _onTrackpadEnd,
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          _onScrollWheelChange(event);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: widget.child,
    );
  }
}

/// A singleton that provides a lock for interested/participating scrollables.
///
/// This lock is intended to help integrate trackpad and mouse wheel scrolling into a
/// UI that may also include traditional gesture-based scrollables. This is needed because
/// trackpad and mouse wheel scrolling behaviors don't participate in the gesture arena,
/// and therefore have no natural ownership mechanism. Not only do those scrolling behaviors
/// need to defer to ongoing gesture scrolling, but there also needs to be a mechanism to
/// force traditional gesture scrollables to defer to trackpade and mouse wheel scrollables.
///
/// To force traditional scrollables to defer to trackpads and mouse wheels, apply a
/// [DeferToTrackpadsAndMouseWheelsScrollBehavior] `ScrollBehavior` to your entire widget tree.
///
/// To integrate trackpad and mouse wheel scrolling around an existing scrollable widget,
/// use [SingleAxisTrackpadAndWheelScroller] or [VerticalTrackpadAndWheelScroller]. Or, build
/// your own with a [_DeferredOwnershipTrackpadAndMouseWheelScroller].
class GlobalScrollLock {
  static final GlobalScrollLock instance = GlobalScrollLock._();

  GlobalScrollLock._();

  Object? _owner;

  /// Returns `true` if the global scroll lock is currently held by some scrollable,
  /// or `false` if the lock isn't held at all.
  bool get isLocked => _owner != null;

  /// Returns `true` if the global scroll lock is held by [me], or `false` if its
  /// held by some other owner, or not held at all.
  bool isLockedByMe(Object me) => _owner == me;

  /// Returns `true` if the global scroll lock is held by an owner that IS NOT [me],
  /// or `false` if the lock is held by [me] or not held by any owner at all.
  bool isLockedByOther(Object me) => _owner != null && _owner != me;

  /// Request ownership of the global scroll lock, returns `true` if granted.
  bool requestLock(Object owner) {
    if (_owner == null || _owner == owner) {
      _owner = owner;
      return true;
    }
    return false;
  }

  /// Releases the global scroll lock, if it's currently owned by [owner].
  void release(Object owner) {
    if (_owner == owner) {
      _owner = null;
    }
  }
}

/// A [ScrollBehavior] that prevents gesture-based scrolling when a trackpad or mouse wheel
/// is already scrolling.
///
/// This is needed because trackpad and mouse wheel scrolling do not participate in the
/// gesture arena, and therefore there is no built-in mechanism for gesture-based scrollables
/// to defer to on-going trackpad and mouse wheel scrolling. This [ScrollBehavior] intercepts
/// attempts to scroll a gesture-based scrollable, and zeros out the scroll offset, if
/// a trackpad or mouse wheel scroll is currently on-going.
///
/// To apply this behavior to all scrollables in a given widget tree, surround the tree
/// with a [ScrollConfiguration] widget.
///
/// ```dart
/// ScrollConfiguration(
///   behavior: const DeferToTrackpadsAndMouseWheelsScrollBehavior(),
///   child: MyWidgetTree(),
/// );
/// ```
class DeferToTrackpadsAndMouseWheelsScrollBehavior extends ScrollBehavior {
  const DeferToTrackpadsAndMouseWheelsScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return _DeferToTrackpadsAndMouseWheelsScrollPhysics(parent: super.getScrollPhysics(context));
  }

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    // Don't wrap with another Scrollbar
    return child;
  }
}

class _DeferToTrackpadsAndMouseWheelsScrollPhysics extends ScrollPhysics {
  const _DeferToTrackpadsAndMouseWheelsScrollPhysics({ScrollPhysics? parent}) : super(parent: parent);

  @override
  _DeferToTrackpadsAndMouseWheelsScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _DeferToTrackpadsAndMouseWheelsScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (position is! ScrollPositionWithSingleContext) {
      return super.applyPhysicsToUserOffset(position, offset);
    }

    // The ScrollableState is used as the owner identifier
    final scrollerId = position.context;
    if (GlobalScrollLock.instance.isLockedByOther(scrollerId)) {
      return 0.0;
    }

    if (GlobalScrollLock.instance._owner == null) {
      GlobalScrollLock.instance.requestLock(scrollerId);

      // Watch scrolling until it ends and then release our ownership.
      //
      // We have to do this in its own object because this class is immutable
      // and we need to store a reference to the scroll position.
      _ScrollEndHandler(position);
    }

    return super.applyPhysicsToUserOffset(position, offset);
  }
}

class _ScrollEndHandler {
  _ScrollEndHandler(this._position) {
    _position.isScrollingNotifier.addListener(_onScrollingStateChange);
  }

  final ScrollPosition _position;

  void _onScrollingStateChange() {
    final isScrolling = _position.isScrollingNotifier.value;
    if (!isScrolling) {
      // Release the global lock
      GlobalScrollLock.instance.release(_position.context);
      _position.isScrollingNotifier.removeListener(_onScrollingStateChange);
    }
  }
}
