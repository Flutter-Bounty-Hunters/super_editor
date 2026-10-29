import 'package:flutter/material.dart';
import 'package:super_text_layout/experimental_flow.dart';
import 'profile_fixture_data.dart';

const profileObstacle = Rect.fromLTWH(210, 20, 130, 80);

/// Optional paint-only changes for a dark preview. The default benchmark
/// retains its original colors and invisible, fixed-size boxes.
class ProfileFixtureColors {
  const ProfileFixtureColors(
      {required this.decoration,
      required this.code,
      required this.boxFill,
      required this.boxBorder});
  final Color decoration, code, boxFill, boxBorder;
}

List<Widget> buildProfileFixture(String scenario,
        {ProfileEdit? edit, ProfileFixtureColors? colors}) =>
    scenario == 'long_prose'
        ? [FlowText(profileChunkText(scenario, 0, edit), id: 'long-text')]
        : [
            for (var i = 0; i < 100; i++) ...[
              if (scenario == 'decorated_code')
                FlowDecoration(
                    color: colors?.decoration ?? const Color(0xFFE8EAF0),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: FlowSequence(children: [
                      FlowText(profileChunkText(scenario, i, edit, end: 12),
                          id: 'text-$i-head',
                          style:
                              const TextStyle(fontFamily: 'FlowBenchmarkCode')),
                      FlowDecoration(
                          color: colors?.decoration ?? const Color(0xFFE8EAF0),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 2, vertical: 1),
                          child: FlowText(
                              profileChunkText(scenario, i, edit,
                                  start: 12, end: 76),
                              id: 'text-$i-body',
                              style: colors == null
                                  ? const TextStyle(
                                      fontFamily: 'FlowBenchmarkCode',
                                      color: Color(0xff24558a))
                                  : TextStyle(
                                      fontFamily: 'FlowBenchmarkCode',
                                      color: colors.code))),
                      FlowText(profileChunkText(scenario, i, edit, start: 76),
                          id: 'text-$i-tail',
                          style:
                              const TextStyle(fontFamily: 'FlowBenchmarkCode')),
                    ]))
              else
                FlowText(profileChunkText(scenario, i, edit), id: 'text-$i'),
              FlowBox(
                  id: 'box-$i',
                  child: scenario == 'demo_buttons'
                      ? _Counter(key: ValueKey(i), number: i)
                      : colors == null
                          ? const SizedBox(width: 30, height: 25)
                          : SizedBox(
                              width: 30,
                              height: 25,
                              child: DecoratedBox(
                                  decoration: BoxDecoration(
                                      color: colors.boxFill,
                                      border:
                                          Border.all(color: colors.boxBorder),
                                      borderRadius:
                                          BorderRadius.circular(3))))),
            ],
          ];

class _Counter extends StatefulWidget {
  const _Counter({super.key, required this.number});
  final int number;
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;
  @override
  Widget build(BuildContext context) => OutlinedButton(
      onPressed: () => setState(() => count++),
      child: Text('${widget.number}: $count'));
}
