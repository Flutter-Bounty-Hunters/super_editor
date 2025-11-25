import 'package:flutter/widgets.dart';
import 'package:flutter/gestures.dart';

/// Singleton that tracks the global scroll lock
class GlobalScrollCoordinator {
  static final GlobalScrollCoordinator instance = GlobalScrollCoordinator._();

  GlobalScrollCoordinator._();

  Object? _owner;

  /// Request the global lock. Returns true if granted.
  /// [owner] can be a ScrollableState, ScrollController, or a manual handler entry
  bool requestLock(Object owner) {
    if (_owner == null || _owner == owner) {
      _owner = owner;
      return true;
    }
    return false;
  }

  /// Release the lock if this owner holds it
  void release(Object owner) {
    if (_owner == owner) {
      _owner = null;
    }
  }

  /// Returns true if a different scrollable owns the lock
  bool isLockedByOther(Object owner) => _owner != null && _owner != owner;
}

class ScrollConfigurationWithCoordinator extends ScrollBehavior {
  const ScrollConfigurationWithCoordinator();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return CoordinatedScrollPhysics(parent: super.getScrollPhysics(context));
  }

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    // Don't wrap with another Scrollbar
    return child;
  }
}

class CoordinatedScrollPhysics extends ScrollPhysics {
  const CoordinatedScrollPhysics({ScrollPhysics? parent}) : super(parent: parent);

  @override
  CoordinatedScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return CoordinatedScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (position is! ScrollPositionWithSingleContext) {
      return super.applyPhysicsToUserOffset(position, offset);
    }

    // The ScrollableState is used as the owner identifier
    final scrollerId = position.context;
    if (GlobalScrollCoordinator.instance.isLockedByOther(scrollerId)) {
      return 0.0;
    }

    if (GlobalScrollCoordinator.instance._owner == null) {
      GlobalScrollCoordinator.instance.requestLock(scrollerId);

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
      GlobalScrollCoordinator.instance.release(_position.context);
      _position.isScrollingNotifier.removeListener(_onScrollingStateChange);
    }
  }
}

class ManualScrollHandler extends StatefulWidget {
  const ManualScrollHandler({
    super.key,
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
  State<ManualScrollHandler> createState() => _ManualScrollHandlerState();
}

class _ManualScrollHandlerState extends State<ManualScrollHandler> {
  late final _ManualHandlerEntry _entry;

  @override
  void initState() {
    super.initState();
    _entry = _ManualHandlerEntry(
      id: this,
      onStart: _internalOnStart,
      onUpdate: _internalOnUpdate,
      onEnd: _internalOnEnd,
      onScrollWheel: _internalOnScrollWheel,
    );
  }

  void _internalOnStart(PointerPanZoomStartEvent e) {
    widget.onPanZoomStart?.call(e);
  }

  void _internalOnUpdate(PointerPanZoomUpdateEvent e) {
    if (GlobalScrollCoordinator.instance._owner == null) {
      switch (widget.scrollAxis) {
        case Axis.horizontal:
          if (e.panDelta.dx.abs() > e.panDelta.dy.abs()) {
            GlobalScrollCoordinator.instance.requestLock(_entry);
          }
        case Axis.vertical:
          if (e.panDelta.dy.abs() > e.panDelta.dx.abs()) {
            GlobalScrollCoordinator.instance.requestLock(_entry);
          }
      }
    }

    if (GlobalScrollCoordinator.instance._owner != _entry) {
      return;
    }

    widget.onPanZoomUpdate?.call(e);
  }

  void _internalOnEnd(PointerPanZoomEndEvent e) {
    if (GlobalScrollCoordinator.instance._owner != _entry) {
      return;
    }

    widget.onPanZoomEnd?.call(e);
    GlobalScrollCoordinator.instance.release(_entry);
  }

  void _internalOnScrollWheel(PointerScrollEvent e) {
    if (GlobalScrollCoordinator.instance._owner != null) {
      return;
    }

    widget.onScrollWheel?.call(e);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerPanZoomStart: _entry.onStart,
      onPointerPanZoomUpdate: _entry.onUpdate,
      onPointerPanZoomEnd: _entry.onEnd,
      onPointerSignal: (ev) {
        if (ev is PointerScrollEvent) _entry.onScrollWheel(ev);
      },
      behavior: HitTestBehavior.opaque,
      child: widget.child,
    );
  }
}

class _ManualHandlerEntry {
  final Object id;
  final void Function(PointerPanZoomStartEvent) onStart;
  final void Function(PointerPanZoomUpdateEvent) onUpdate;
  final void Function(PointerPanZoomEndEvent) onEnd;
  final void Function(PointerScrollEvent) onScrollWheel;

  _ManualHandlerEntry({
    required this.id,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.onScrollWheel,
  });

  @override
  bool operator ==(Object other) => other is _ManualHandlerEntry && identical(other.id, id);
  @override
  int get hashCode => identityHashCode(id);
}
