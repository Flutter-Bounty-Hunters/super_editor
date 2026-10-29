import 'package:flutter/material.dart';
import 'package:super_text_layout/experimental_flow.dart';
import 'flow_palette.dart';
import 'demo_prose.dart';

class FlowLayoutDemo extends StatefulWidget {
  const FlowLayoutDemo({super.key});
  @override
  State<FlowLayoutDemo> createState() => _FlowLayoutDemoState();
}

class _FlowLayoutDemoState extends State<FlowLayoutDemo> {
  final _controller = FlowLayoutController();
  final _paragraphKey = GlobalKey();
  double _width = 620;
  bool _obstacle = true;
  bool _regions = false;
  bool _stress = false;
  bool _prose = false;
  FlowPosition? _anchor;
  String _measurement =
      'Drag to select. Click a counter, then resize: its state survives.';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(Offset global, {bool start = false}) {
    final render =
        _paragraphKey.currentContext?.findRenderObject() as RenderBox?;
    final layout = _controller.layout;
    if (render == null || layout == null) {
      return;
    }
    final position = layout.positionNearestTo(render.globalToLocal(global));
    if (position == null) {
      return;
    }
    if (start) {
      _anchor = position;
    }
    _controller.selection = FlowSelection(_anchor ?? position, position);
  }

  @override
  Widget build(BuildContext context) {
    const obstacle = Rect.fromLTWH(210, 20, 130, 80);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),
      appBar: AppBar(title: const Text('Flow layout')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('One widget. Multiple fragments.',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
              'Code wraps across lines and around the obstacle. Buttons remain ordinary stateful Flutter widgets.'),
          SizedBox(
              width: 720,
              child: Row(children: [
                const Text('Width'),
                Expanded(
                    child: Slider(
                        value: _width,
                        min: 260,
                        max: 720,
                        onChanged: (value) => setState(() => _width = value))),
                Text('${_width.round()}'),
              ])),
          Wrap(
              spacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilterChip(
                    label: const Text('Rectangular obstacle'),
                    selected: _obstacle,
                    onSelected: (value) => setState(() => _obstacle = value)),
                FilterChip(
                    label: const Text('Show line regions'),
                    selected: _regions,
                    onSelected: (value) => setState(() => _regions = value)),
                FilterChip(
                    label: const Text('Long prose'),
                    selected: _prose,
                    onSelected: (value) => setState(() {
                          _prose = value;
                          if (value) _stress = false;
                          _controller.selection = null;
                        })),
                FilterChip(
                    label: const Text('10k characters + 100 buttons'),
                    selected: _stress,
                    onSelected: (value) => setState(() {
                          _stress = value;
                          if (value) _prose = false;
                          _controller.selection = null;
                        })),
                TextButton(
                    onPressed: () {
                      final layout = _controller.layout;
                      if (layout == null) {
                        return;
                      }
                      setState(() => _measurement =
                          '${layout.lines.length} lines · ${layout.fragments.length} fragments · '
                              '${layout.lineRetries} height retries · ${layout.layoutDuration.inMicroseconds / 1000} ms layout '
                              '(current build, not a release benchmark)');
                    },
                    child: const Text('Read layout measurement')),
              ]),
          const SizedBox(height: 16),
          Container(
            color: Colors.white,
            width: _width,
            child: DefaultTextStyle(
              style: const TextStyle(
                  fontFamily: 'FlowDemo',
                  fontSize: 18,
                  color: Color(0xFF202630)),
              child: GestureDetector(
                onTapDown: (event) =>
                    _select(event.globalPosition, start: true),
                onPanStart: (event) =>
                    _select(event.globalPosition, start: true),
                onPanUpdate: (event) => _select(event.globalPosition),
                child: FlowParagraph(
                  key: _paragraphKey,
                  controller: _controller,
                  style: const TextStyle(
                      fontFamily: 'FlowDemo',
                      fontSize: 18,
                      color: Color(0xFF202630)),
                  regions: RectangularFlowRegions(
                      obstacles: _obstacle ? [obstacle] : []),
                  backgroundPainter: (canvas, layout) {
                    if (_obstacle) {
                      canvas.drawRRect(
                          RRect.fromRectAndRadius(
                              obstacle, const Radius.circular(8)),
                          Paint()..color = const Color(0xFFDEE5F1));
                      final label = TextPainter(
                          text: const TextSpan(
                              text: 'Obstacle',
                              style: TextStyle(
                                  color: Color(0xFF425578), fontSize: 16)),
                          textDirection: TextDirection.ltr)
                        ..layout();
                      label.paint(
                          canvas,
                          obstacle.center -
                              Offset(label.width / 2, label.height / 2));
                      label.dispose();
                    }
                    if (_regions) {
                      for (final line in layout.lines) {
                        for (final segment in line.segments) {
                          canvas.drawRect(
                              segment,
                              Paint()
                                ..color = const Color(0x337366E8)
                                ..style = PaintingStyle.stroke);
                        }
                      }
                    }
                  },
                  // Selection is entirely external to the participating widgets.
                  foregroundPainter: (canvas, layout) {
                    final selection = _controller.selection;
                    if (selection == null) {
                      return;
                    }
                    for (final box in layout.boxesForSelection(selection)) {
                      canvas.drawRect(
                          box, Paint()..color = const Color(0x553B82F6));
                    }
                    final caret = layout.caretFor(selection.extent);
                    if (caret != null) {
                      canvas.drawRect(
                          caret, Paint()..color = const Color(0xFF2563EB));
                    }
                  },
                  children: _prose
                      ? const [FlowText(demoProse, id: 'prose')]
                      : _stress
                          ? _stressContent()
                          : [
                              const FlowText(
                                  'This paragraph contains an inline code widget: ',
                                  id: 'intro'),
                              const FlowDecoration(
                                id: 'code',
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                child: FlowSequence(children: [
                                  FlowText('final result = ',
                                      id: 'code-start',
                                      style: TextStyle(fontFamily: 'FlowCode')),
                                  FlowDecoration(
                                      id: 'nested',
                                      color: Color(0xFFFEDC9A),
                                      radius: 3,
                                      child: FlowText(
                                          'widgets.where((widget) => widget.canFragment)',
                                          id: 'code-inner',
                                          style: TextStyle(
                                              fontFamily: 'FlowCode'))),
                                  FlowText('.toList();',
                                      id: 'code-end',
                                      style: TextStyle(fontFamily: 'FlowCode')),
                                ]),
                              ),
                              const FlowText(
                                  ' The text continues beside the final code fragment. Here is another participant: '),
                              FlowSequence(children: [
                                for (var i = 0; i < 5; i++)
                                  FlowBox(
                                      id: 'button-$i',
                                      child: Padding(
                                          padding:
                                              const EdgeInsets.only(right: 6),
                                          child: _CounterButton(
                                              key: ValueKey(i), number: i))),
                              ]),
                              const FlowText(
                                  ' A custom palette keeps each group of three swatches together: '),
                              const FlowDecoration(
                                  id: 'palette',
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 3),
                                  child: FlowPalette(id: 'swatches')),
                              const FlowText(
                                  ' The buttons wrap between pieces while retaining their state. '
                                  'The next word crosses a decoration-only boundary: '),
                              const FlowText('of'),
                              const FlowDecoration(
                                  color: Color(0xFFFEDC9A),
                                  child: FlowText('fi')),
                              const FlowText(
                                  'ce. Emoji remain whole: 👩🏽‍💻 👨‍👩‍👧‍👦.\n'
                                  'Explicit line breaks and empty padded content are also part of this experiment. '),
                              const FlowDecoration(
                                  id: 'empty',
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  child: FlowText('', id: 'empty-text')),
                              const FlowText(' End.'),
                            ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(width: 720, child: Text(_measurement)),
          const SizedBox(height: 12),
          const SizedBox(
              width: 720,
              child: Text(
                  'Experimental: horizontal LTR, greedy wrapping, no keyboard editing. '
                  'The text backend and public protocol are deliberately provisional.')),
        ])),
      ),
    );
  }

  List<Widget> _stressContent() => [
        for (var i = 0; i < 100; i++) ...[
          FlowText(
              ('A paragraph with fragmentable inline content and ordinary widgets. ' *
                      2)
                  .substring(0, 100),
              id: 'stress-text-$i'),
          FlowBox(
              id: 'stress-button-$i',
              child: _CounterButton(key: ValueKey(i), number: i)),
        ],
      ];
}

class _CounterButton extends StatefulWidget {
  const _CounterButton({super.key, required this.number});
  final int number;
  @override
  State<_CounterButton> createState() => _CounterButtonState();
}

class _CounterButtonState extends State<_CounterButton> {
  int _count = 0;
  @override
  Widget build(BuildContext context) => OutlinedButton(
      onPressed: () => setState(() => _count++),
      child: Text('${widget.number}: $_count'));
}
