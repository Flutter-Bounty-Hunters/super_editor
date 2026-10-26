import 'package:flutter/material.dart';
import 'package:super_text_layout/experimental_flow.dart';
import 'profile_fixture_data.dart';

List<Widget> buildProfileFixture(String scenario, {ProfileEdit? edit}) =>
    scenario == 'long_prose'
        ? [FlowText(profileChunkText(scenario, 0, edit), id: 'long-text')]
        : [
            for (var i = 0; i < 100; i++) ...[
              if (scenario == 'decorated_code')
                FlowDecoration(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: FlowSequence(children: [
                      FlowText(profileChunkText(scenario, i, edit, end: 12),
                          id: 'text-$i-head',
                          style:
                              const TextStyle(fontFamily: 'FlowBenchmarkCode')),
                      FlowDecoration(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 2, vertical: 1),
                          child: FlowText(
                              profileChunkText(scenario, i, edit,
                                  start: 12, end: 76),
                              id: 'text-$i-body',
                              style: const TextStyle(
                                  fontFamily: 'FlowBenchmarkCode',
                                  color: Color(0xff24558a)))),
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
                      : const SizedBox(width: 30, height: 25)),
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
