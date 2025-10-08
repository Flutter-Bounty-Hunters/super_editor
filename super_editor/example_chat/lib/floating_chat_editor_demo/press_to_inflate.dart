import 'package:flutter/cupertino.dart';

/// Inflates/enlarges [child] by a small amount, whenever the user presses down
/// anywhere on the [child].
///
/// This effect uses pointer events, it doesn't interfered with the gesture arena.
class PressToInflate extends StatefulWidget {
  const PressToInflate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<PressToInflate> createState() => _PressToInflateState();
}

class _PressToInflateState extends State<PressToInflate> {
  var _isUserPressingDown = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() {
        _isUserPressingDown = true;
      }),
      onPointerUp: (_) => setState(() {
        _isUserPressingDown = false;
      }),
      onPointerCancel: (_) => setState(() {
        _isUserPressingDown = false;
      }),
      child: Transform.scale(
        scale: 1.0, //_isUserPressingDown ? 1.02 : 1,
        child: widget.child,
      ),
    );
  }
}
