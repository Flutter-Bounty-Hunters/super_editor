import 'package:example/demos/in_the_lab/in_the_lab_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:overlord/follow_the_leader.dart';
import 'package:overlord/overlord.dart';
import 'package:super_editor/super_editor.dart';

class SelectedTextColorsDemo extends StatefulWidget {
  const SelectedTextColorsDemo({super.key});

  @override
  State<SelectedTextColorsDemo> createState() => _SelectedTextColorsDemoState();
}

class _SelectedTextColorsDemoState extends State<SelectedTextColorsDemo> {
  late final MutableDocument _document;
  late final MutableDocumentComposer _composer;
  late final Editor _editor;

  final _regularTextColorLeaderLink = LeaderLink();
  Color _regularTextColor = const Color(0xFFCCCCCC);

  final _selectionHighlightColorLeaderLink = LeaderLink();
  Color _selectionHighlightColor = const Color(0xFFACCEF7);

  final _selectedTextColorLeaderLink = LeaderLink();
  Color _selectedTextColor = const Color(0xFF000000);

  LeaderLink? _activeColorSelectorLink;

  @override
  void initState() {
    super.initState();

    _document = MutableDocument(nodes: [
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
            "SuperEditor can dynamically change color of selected text to better contrast with the highlight."),
      ),
    ]);
    _composer = MutableDocumentComposer();
    _editor = Editor(
      editables: {
        Editor.documentKey: _document,
        Editor.composerKey: _composer,
      },
      requestHandlers: [
        ...defaultRequestHandlers,
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InTheLabScaffold(
      content: Center(
        child: _buildEditor(),
      ),
      supplemental: _buildControlPanel(),
      overlay: _buildOverlay(),
    );
  }

  Widget _buildEditor() {
    return SuperEditor(
      editor: _editor,
      shrinkWrap: true,
      stylesheet: defaultStylesheet.copyWith(
        selectedTextColorStrategy: _selectedTextColorStrategy,
        addRulesAfter: [
          ...darkModeStyles,
          ...largeTextStyles,
          StyleRule(
            BlockSelector.all,
            (doc, docNode) {
              return {
                Styles.textStyle: TextStyle(
                  color: _regularTextColor,
                ),
              };
            },
          ),
        ],
      ),
      selectionStyle: SelectionStyles(selectionColor: _selectionHighlightColor),
      documentOverlayBuilders: [
        DefaultCaretOverlayBuilder(
          caretStyle: CaretStyle().copyWith(color: Colors.redAccent),
        ),
      ],
    );
  }

  Color _selectedTextColorStrategy({required Color originalTextColor, required Color selectionHighlightColor}) {
    return _selectedTextColor;
  }

  Widget _buildControlPanel() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildColorSelector(_regularTextColor, "REGULAR TEXT", _regularTextColorLeaderLink),
          const SizedBox(height: 24),
          _buildColorSelector(_selectionHighlightColor, "SELECTION HIGHLIGHT", _selectionHighlightColorLeaderLink),
          const SizedBox(height: 24),
          _buildColorSelector(_selectedTextColor, "SELECTED TEXT", _selectedTextColorLeaderLink),
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    if (_activeColorSelectorLink == null) {
      return const SizedBox();
    }

    return ColorPickerPopoverModal(
      leaderLink: _activeColorSelectorLink!,
      onTapOutside: () {
        setState(() {
          _activeColorSelectorLink = null;
        });
      },
      onColorSelected: (color) {
        if (_activeColorSelectorLink == _regularTextColorLeaderLink) {
          setState(() {
            _regularTextColor = color;
          });
        } else if (_activeColorSelectorLink == _selectionHighlightColorLeaderLink) {
          setState(() {
            _selectionHighlightColor = color;
          });
        } else if (_activeColorSelectorLink == _selectedTextColorLeaderLink) {
          setState(() {
            _selectedTextColor = color;
          });
        }
      },
    );
  }

  Widget _buildColorSelector(Color currentColor, String label, [LeaderLink? leaderLink]) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => setState(() {
            _activeColorSelectorLink = leaderLink;
          }),
          child: _buildLargeColorCircle(currentColor, leaderLink),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildLargeColorCircle(Color color, [LeaderLink? leaderLink]) {
    final circle = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          color: color,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 5, offset: Offset(0, 5)),
          ],
        ),
      ),
    );

    return leaderLink != null
        ? Leader(
            link: leaderLink,
            child: circle,
          )
        : circle;
  }
}

class ColorPickerPopoverModal extends StatelessWidget {
  const ColorPickerPopoverModal({
    Key? key,
    required this.leaderLink,
    required this.onTapOutside,
    required this.onColorSelected,
  }) : super(key: key);

  final LeaderLink leaderLink;

  final VoidCallback onTapOutside;

  final void Function(Color) onColorSelected;

  @override
  Widget build(BuildContext context) {
    return BuildInOrder(
      children: [
        GestureDetector(
          onTap: onTapOutside,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.transparent,
          ),
        ),
        Follower.withAligner(
          link: leaderLink,
          aligner: StaticOffsetAligner(
            leaderAnchor: Alignment.centerLeft,
            followerAnchor: Alignment.centerRight,
            offset: Offset(-24, 0),
          ),
          boundary: const ScreenFollowerBoundary(),
          child: CupertinoPopoverMenu(
            focalPoint: LeaderMenuFocalPoint(link: leaderLink),
            backgroundColor: const Color(0xFF111111),
            child: _buildColorPalette(),
          ),
        ),
      ],
    );
  }

  Widget _buildColorPalette() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSelectableColorCircle(Colors.red),
              const SizedBox(width: 12),
              _buildSelectableColorCircle(Colors.orange),
              const SizedBox(width: 12),
              _buildSelectableColorCircle(Colors.yellow),
              const SizedBox(width: 12),
              _buildSelectableColorCircle(Colors.green),
              const SizedBox(width: 12),
              _buildSelectableColorCircle(Colors.blue),
              const SizedBox(width: 12),
              _buildSelectableColorCircle(Colors.purple),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSelectableColorCircle(Colors.black),
              const SizedBox(width: 12),
              _buildSelectableColorCircle(Colors.black54),
              const SizedBox(width: 12),
              _buildSelectableColorCircle(Colors.black12),
              const SizedBox(width: 12),
              _buildSelectableColorCircle(Colors.white24),
              const SizedBox(width: 12),
              _buildSelectableColorCircle(Colors.white60),
              const SizedBox(width: 12),
              _buildSelectableColorCircle(Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectableColorCircle(Color color) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onColorSelected(color),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            color: color,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 3, offset: Offset(0, 3)),
            ],
          ),
        ),
      ),
    );
  }
}
