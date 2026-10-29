import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:super_text_layout/experimental_flow.dart';
import '../fixtures/profile_fixture_data.dart';
import '../fixtures/profile_fixture_widgets.dart';
import 'metrics.dart';
import 'widgets.dart';

Future<void> showBenchmarkLayout(BuildContext context, Benchmark benchmark,
        {required int fixtureVersion, String phase = 'initial'}) =>
    showDialog<void>(
      context: context,
      builder: (context) => BenchmarkLayoutPopover(
          benchmark: benchmark,
          fixtureVersion: fixtureVersion,
          initialPhase: phase),
    );

/// A live rendering of the shared fixture, not a timing run or a screenshot.
class BenchmarkLayoutPopover extends StatefulWidget {
  const BenchmarkLayoutPopover(
      {super.key,
      required this.benchmark,
      required this.fixtureVersion,
      this.initialPhase = 'initial'});
  final Benchmark benchmark;
  final int fixtureVersion;
  final String initialPhase;
  @override
  State<BenchmarkLayoutPopover> createState() => _BenchmarkLayoutPopoverState();
}

class _BenchmarkLayoutPopoverState extends State<BenchmarkLayoutPopover> {
  final controller = FlowLayoutController();
  final vertical = ScrollController(), horizontal = ScrollController();
  late String phase = widget.initialPhase;
  double get layoutWidth => phase == 'initial' ? 600 : 320;
  ProfileEdit? get edit => switch (phase) {
        'edit_beginning' => ProfileEdit.beginning,
        'edit_middle' => ProfileEdit.middle,
        'edit_end' => ProfileEdit.end,
        _ => null,
      };

  @override
  void dispose() {
    controller.dispose();
    vertical.dispose();
    horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final benchmark = widget.benchmark;
    final supported = widget.fixtureVersion == profileFixtureVersion &&
        profileFixtureMetadata.containsKey(benchmark.id);
    return Dialog(
      key: const ValueKey('benchmark-layout-popover'),
      backgroundColor: Palette.surface,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Palette.border)),
      child: SizedBox(
        width: 780,
        height: math.min(850, MediaQuery.sizeOf(context).height - 64),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 12, 0),
              child: Row(children: [
                const Icon(Icons.notes_rounded, color: Palette.green, size: 20),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(benchmark.title,
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w500))),
                IconButton(
                    key: const ValueKey('close-layout-preview'),
                    tooltip: 'Close layout preview',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20)),
              ])),
          Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
              child: muted(benchmark.description, size: 11)),
          const Divider(height: 1),
          if (supported) ...[
            Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                child: Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      caption('OPERATION'),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                            key: const ValueKey('preview-operation'),
                            value: phase,
                            dropdownColor: Palette.raised,
                            style: const TextStyle(
                                fontFamily: 'DashboardSans',
                                color: Palette.text,
                                fontSize: 12),
                            items: [
                              for (final entry in operations.entries)
                                DropdownMenuItem(
                                    value: entry.key, child: Text(entry.value))
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  phase = value;
                                  if (vertical.hasClients) vertical.jumpTo(0);
                                  if (horizontal.hasClients) {
                                    horizontal.jumpTo(0);
                                  }
                                });
                              }
                            }),
                      ),
                      Tag('${layoutWidth.toInt()} px wide'),
                      Tag('Fixture v${widget.fixtureVersion}'),
                    ])),
            Expanded(
                child: Container(
              color: Palette.background,
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                  builder: (context, constraints) => Scrollbar(
                        controller: vertical,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: vertical,
                          child: SingleChildScrollView(
                            controller: horizontal,
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                                constraints: BoxConstraints(
                                    minWidth: constraints.maxWidth),
                                child: Align(
                                    widthFactor: 1,
                                    heightFactor: 1,
                                    alignment: Alignment.topCenter,
                                    child: SizedBox(
                                        width: layoutWidth, child: _layout()))),
                          ),
                        ),
                      )),
            )),
            Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                child: muted(
                    'Live fixture preview · recorded timings stay unchanged. Colors are adapted for the dark theme; box outlines and the shaded obstacle mark layout bounds.',
                    size: 10)),
          ] else
            Expanded(
                child: Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: muted(
                            'No matching preview is available for fixture v${widget.fixtureVersion}.')))),
        ]),
      ),
    );
  }

  Widget _layout() {
    final metadata = profileFixtureMetadata[widget.benchmark.id]!;
    final style = TextStyle(
        fontFamily: 'FlowBenchmark',
        fontSize: (metadata['fontSize']! as num).toDouble(),
        color: Palette.text);
    final obstacle = metadata['obstacle']! as bool;
    // Keep the benchmark's default Material button sizing rather than inheriting
    // the dashboard's custom controls. Only the palette is changed.
    final fixtureTheme = ThemeData(
        fontFamily: 'FlowBenchmark',
        brightness: Brightness.dark,
        useMaterial3: true);
    return Theme(
        data: fixtureTheme,
        child: DefaultTextStyle(
          style: style,
          child: Stack(clipBehavior: Clip.hardEdge, children: [
            FlowParagraph(
              key: const ValueKey('preview-paragraph'),
              controller: controller,
              style: style,
              regions: RectangularFlowRegions(
                  obstacles: obstacle ? [profileObstacle] : []),
              children: buildProfileFixture(widget.benchmark.id,
                  edit: edit,
                  colors: const ProfileFixtureColors(
                      decoration: Color(0xFF26332E),
                      code: Color(0xFF91D9BB),
                      boxFill: Color(0x1354DCA0),
                      boxBorder: Color(0x6654DCA0))),
            ),
            if (obstacle)
              Positioned.fromRect(
                rect: profileObstacle,
                child: IgnorePointer(
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            color: Palette.baseline.withValues(alpha: .2),
                            border: Border.all(color: Palette.border),
                            borderRadius: BorderRadius.circular(5)),
                        child: Center(
                            child: Text('Flow obstacle',
                                style: style.copyWith(
                                    fontFamily: 'DashboardSans',
                                    fontSize: 10,
                                    color: Palette.muted))))),
              ),
          ]),
        ));
  }
}
