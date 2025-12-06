import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/src/super_textfield/infrastructure/outer_box_shadow.dart';
import 'package:super_editor/super_editor.dart';

/// An iOS magnifying glass that follows a [LayerLink].
class IOSFollowingMagnifier extends StatefulWidget {
  const IOSFollowingMagnifier.roundedRectangle({
    Key? key,
    this.magnifierKey,
    required this.leaderLink,
    this.show = true,
    this.offsetFromFocalPoint = Offset.zero,
    this.handleColor,
  }) : magnifierBuilder = _roundedRectangleMagnifierBuilder;

  const IOSFollowingMagnifier.circle({
    Key? key,
    this.magnifierKey,
    required this.leaderLink,
    this.show = true,
    this.offsetFromFocalPoint = Offset.zero,
    this.handleColor,
  }) : magnifierBuilder = _circleMagnifierBuilder;

  const IOSFollowingMagnifier({
    Key? key,
    this.magnifierKey,
    required this.leaderLink,
    this.show = true,
    this.offsetFromFocalPoint = Offset.zero,
    this.handleColor,
    required this.magnifierBuilder,
  }) : super(key: key);

  final Key? magnifierKey;
  final LeaderLink leaderLink;
  final bool show;

  /// The distance, in density independent pixels, from the focal point to the magnifier.
  final Offset offsetFromFocalPoint;

  final Color? handleColor;
  final MagnifierBuilder magnifierBuilder;

  @override
  State<IOSFollowingMagnifier> createState() => _IOSFollowingMagnifierState();
}

class _IOSFollowingMagnifierState extends State<IOSFollowingMagnifier> with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  /// Wether or not the magnifier should be displayed.
  ///
  /// The magnifier can still be displayed event when [widget.show] is `false`
  /// because the magnifier should be visible during the exit animation.
  bool get _shouldShowMagnifier => widget.show || _animationController.status != AnimationStatus.dismissed;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: defaultIosMagnifierEnterAnimationDuration,
      reverseDuration: defaultIosMagnifierExitAnimationDuration,
    );
  }

  @override
  void didUpdateWidget(IOSFollowingMagnifier oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.show != oldWidget.show) {
      _onWantsToShowMagnifierChanged();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onWantsToShowMagnifierChanged() {
    if (widget.show) {
      _animationController.forward();
    } else {
      // The desire to show the magnifier changed from visible to invisible. Run the exit
      // animation and set the magnifier to invisible when the animation finishes.
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        if (!_shouldShowMagnifier) {
          return const SizedBox();
        }

        final percentage = _animationController.value;
        final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

        return Follower.withOffset(
          link: widget.leaderLink,
          showWhenUnlinked: false,
          // Center-align the magnifier with the focal point, so when the animation starts
          // the magnifier is displayed in the same position as the focal point.
          leaderAnchor: Alignment.center,
          followerAnchor: Alignment.center,
          offset: Offset(
            widget.offsetFromFocalPoint.dx * devicePixelRatio,
            // Animate the magnfier up on entrance and down on exit.
            widget.offsetFromFocalPoint.dy * devicePixelRatio * percentage,
          ),
          boundary: const ScreenFollowerBoundary(),
          child: widget.magnifierBuilder(
            context,
            IosMagnifierViewModel(
              offsetFromFocalPoint: Offset(
                widget.offsetFromFocalPoint.dx * percentage,
                widget.offsetFromFocalPoint.dy * percentage,
              ),
              animationValue: _animationController.value,
              animationDirection:
                  const [AnimationStatus.forward, AnimationStatus.completed].contains(_animationController.status)
                      ? AnimationDirection.forward
                      : AnimationDirection.reverse,
              borderColor: widget.handleColor ?? Theme.of(context).primaryColor,
            ),
            widget.magnifierKey,
          ),
        );
      },
    );
  }
}

typedef MagnifierBuilder = Widget Function(BuildContext, IosMagnifierViewModel magnifierInfo, [Key? magnifierKey]);

Widget _roundedRectangleMagnifierBuilder(BuildContext context, IosMagnifierViewModel magnifierInfo,
        [Key? magnifierKey]) =>
    IOSRoundedRectangleMagnifyingGlass(
      key: magnifierKey,
      offsetFromFocalPoint: magnifierInfo.offsetFromFocalPoint,
      animationValue: magnifierInfo.animationValue,
      borderColor: magnifierInfo.borderColor,
    );

Widget _circleMagnifierBuilder(BuildContext context, IosMagnifierViewModel magnifierInfo, [Key? magnifierKey]) =>
    IOSCircleMagnifyingGlass(
      key: magnifierKey,
      offsetFromFocalPoint: magnifierInfo.offsetFromFocalPoint,
    );

class IOSRoundedRectangleMagnifyingGlass extends StatelessWidget {
  static const _magnification = 1.5;

  const IOSRoundedRectangleMagnifyingGlass({
    super.key,
    this.offsetFromFocalPoint = Offset.zero,
    this.animationValue = 1.0,
    required this.borderColor,
  });

  /// The distance, in density independent pixels, from the focal point to the magnifier.
  final Offset offsetFromFocalPoint;
  final double animationValue;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final percent = defaultIosMagnifierAnimationCurve.transform(animationValue);

    final height = lerpDouble(30, defaultIosMagnifierSize.height, percent)!;
    final width = lerpDouble(4, defaultIosMagnifierSize.width, percent)!;
    final size = Size(width, height);

    final tintOpacity = 1.0 - Curves.easeIn.transform(animationValue);
    final borderRadius = lerpDouble(30.0, 50.0, percent)!;
    final borderWidth = lerpDouble(15.0, 3.0, percent)!;

    return SizedBox(
      width: size.width,
      height: size.height,
      child: ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
        child: Stack(
          children: [
            if (percent >= 0.3)
              MagnifyingGlass(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
                ),
                size: size,
                offsetFromFocalPoint: Offset(offsetFromFocalPoint.dx, offsetFromFocalPoint.dy),
                magnificationScale: _magnification,
              ),
            Opacity(
              opacity: Curves.easeOutQuint.transform(percent),
              child: Container(
                decoration: ShapeDecoration(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
                    side: BorderSide(
                      color: borderColor,
                      width: borderWidth,
                    ),
                  ),
                  color: borderColor.withValues(alpha: tintOpacity),
                  shadows: const [
                    OuterBoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class IOSCircleMagnifyingGlass extends StatelessWidget {
  static const _diameter = 92.0;
  static const _magnification = 2.0;

  const IOSCircleMagnifyingGlass({
    super.key,
    this.offsetFromFocalPoint = Offset.zero,
  });

  /// The distance, in density independent pixels, from the focal point to the magnifier.
  final Offset offsetFromFocalPoint;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MagnifyingGlass(
          shape: const CircleBorder(),
          size: const Size(_diameter, _diameter),
          offsetFromFocalPoint: offsetFromFocalPoint,
          magnificationScale: _magnification,
        ),
        Container(
          width: _diameter,
          height: _diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFAAAAAA), width: 1),
            gradient: const LinearGradient(
              colors: [
                Color(0x22000000),
                Color(0x00000000),
              ],
              stops: [
                0.0,
                0.5,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
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

/// Parameters used to render an iOS magnifier.
class IosMagnifierViewModel {
  IosMagnifierViewModel({
    required this.offsetFromFocalPoint,
    this.animationValue = 1.0,
    this.animationDirection = AnimationDirection.forward,
    required this.borderColor,
  });

  /// The distance, in density independent pixels, from the focal point to the magnifier.
  final Offset offsetFromFocalPoint;

  final double animationValue;
  final AnimationDirection animationDirection;
  final Color borderColor;
}

enum AnimationDirection { forward, reverse }
