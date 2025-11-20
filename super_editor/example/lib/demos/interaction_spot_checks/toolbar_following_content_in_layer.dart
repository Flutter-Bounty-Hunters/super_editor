import 'dart:math';

import 'package:flutter/material.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:overlord/follow_the_leader.dart';
import 'package:overlord/overlord.dart';
import 'package:super_editor/super_editor.dart';

import 'spot_check_scaffold.dart';

class ToolbarFollowingContentInLayer extends StatefulWidget {
  const ToolbarFollowingContentInLayer({super.key});

  @override
  State<ToolbarFollowingContentInLayer> createState() => _ToolbarFollowingContentInLayerState();
}

class _ToolbarFollowingContentInLayerState extends State<ToolbarFollowingContentInLayer> {
  final _leaderLink = LeaderLink();
  final _viewportKey = GlobalKey();
  final _leaderBoundsKey = GlobalKey();

  final _baseContentWidth = 10.0;
  final _expansionExtent = ValueNotifier<double>(0);

  final OverlayPortalController _overlayPortalController = OverlayPortalController();

  @override
  void initState() {
    super.initState();

    // Can't call `show` during build or Flutter blows up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overlayPortalController.show();
    });
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _overlayPortalController,
      overlayChildBuilder: _buildToolbarOverlay,
      child: SpotCheckScaffold(
        content: KeyedSubtree(
          key: _viewportKey,
          child: CustomScrollView(
            shrinkWrap: true,
            slivers: [
              SliverContentLayers(
                overlays: [
                  (_) => LeaderLayoutLayer(
                        leaderLink: _leaderLink,
                        leaderBoundsKey: _leaderBoundsKey,
                      ),
                ],
                content: (_) => SliverToBoxAdapter(
                  child: Column(
                    children: [
                      ValueListenableBuilder(
                        valueListenable: _expansionExtent,
                        builder: (context, expansionExtent, _) {
                          return Container(
                            height: 12,
                            width: _baseContentWidth + (2 * expansionExtent) + 2, // +2 for border
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                key: _leaderBoundsKey,
                                width: _baseContentWidth + expansionExtent,
                                height: 10,
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 96),
                      TextButton(
                        onPressed: () {
                          _expansionExtent.value = Random().nextDouble() * 200;
                        },
                        child: Text("Change Size"),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbarOverlay(BuildContext context) {
    return FollowerFadeOutBeyondBoundary(
      link: _leaderLink,
      boundary: WidgetFollowerBoundary(
        boundaryKey: _viewportKey,
      ),
      child: Follower.withAligner(
        link: _leaderLink,
        aligner: CupertinoPopoverToolbarAligner(),
        child: CupertinoPopoverToolbar(
          focalPoint: LeaderMenuFocalPoint(link: _leaderLink),
          children: [
            CupertinoPopoverToolbarMenuItem(
              label: 'Cut',
              onPressed: () {
                print("Pressed 'Cut'");
              },
            ),
            CupertinoPopoverToolbarMenuItem(
              label: 'Copy',
              onPressed: () {
                print("Pressed 'Copy'");
              },
            ),
            CupertinoPopoverToolbarMenuItem(
              label: 'Paste',
              onPressed: () {
                print("Pressed 'Paste'");
              },
            ),
          ],
        ),
      ),
    );
  }
}

class LeaderLayoutLayer extends ContentLayerStatefulWidget {
  const LeaderLayoutLayer({
    super.key,
    required this.leaderLink,
    required this.leaderBoundsKey,
  });

  final LeaderLink leaderLink;
  final GlobalKey leaderBoundsKey;

  @override
  ContentLayerState<ContentLayerStatefulWidget, Rect> createState() => LeaderLayoutLayerState();
}

class LeaderLayoutLayerState extends ContentLayerState<LeaderLayoutLayer, Rect> {
  @override
  Rect? computeLayoutData(Element? contentElement, RenderObject? contentLayout) {
    final boundsBox = widget.leaderBoundsKey.currentContext?.findRenderObject() as RenderBox?;
    if (boundsBox == null) {
      return null;
    }

    return Rect.fromLTWH(0, 0, boundsBox.size.width, boundsBox.size.height);
  }

  @override
  Widget doBuild(BuildContext context, Rect? layoutData) {
    if (layoutData == null) {
      return const SizedBox();
    }

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 24.0),
        child: SizedBox(
          width: layoutData.size.width * 2,
          height: layoutData.size.height,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Leader(
              link: widget.leaderLink,
              child: SizedBox.fromSize(
                size: layoutData.size,
                child: ColoredBox(
                  color: Colors.red,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
