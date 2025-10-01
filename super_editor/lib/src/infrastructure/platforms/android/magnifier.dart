import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/src/super_textfield/infrastructure/magnifier.dart';
import 'package:super_editor/src/super_textfield/infrastructure/outer_box_shadow.dart';

/// An Android magnifying glass that follows a [LeaderLink].
class AndroidFollowingMagnifier extends StatelessWidget {
  const AndroidFollowingMagnifier({
    Key? key,
    required this.layerLink,
    this.offsetFromFocalPoint = Offset.zero,
  }) : super(key: key);

  final LeaderLink layerLink;
  final Offset offsetFromFocalPoint;

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

    return Follower.withOffset(
      link: layerLink,
      offset: offsetFromFocalPoint,
      leaderAnchor: Alignment.center,
      followerAnchor: Alignment.center,
      boundary: const ScreenFollowerBoundary(),
      child: AndroidMagnifyingGlass(
        magnificationScale: 1.5,
        offsetFromFocalPoint: Offset(
          offsetFromFocalPoint.dx / devicePixelRatio,
          offsetFromFocalPoint.dy / devicePixelRatio,
        ),
      ),
    );
  }
}

class AndroidMagnifyingGlass extends StatelessWidget {
  static const _width = 92.0;
  static const _height = 48.0;
  static const _cornerRadius = 8.0;

  const AndroidMagnifyingGlass({
    super.key,
    this.magnificationScale = 1.5,
    this.offsetFromFocalPoint = Offset.zero,
  });

  final double magnificationScale;
  final Offset offsetFromFocalPoint;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MagnifyingGlass(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_cornerRadius),
          ),
          offsetFromFocalPoint: offsetFromFocalPoint,
          size: const Size(_width, _height),
          magnificationScale: magnificationScale,
        ),
        Container(
          width: _width,
          height: _height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_cornerRadius),
            boxShadow: const [
              OuterBoxShadow(
                color: Color(0x44000000),
                blurRadius: 8,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
