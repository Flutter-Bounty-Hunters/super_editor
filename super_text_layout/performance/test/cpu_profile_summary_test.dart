import 'package:flutter_test/flutter_test.dart';
import 'package:performance/profiling/cpu_profile_summary.dart';

void main() {
  test('profile attribution disambiguates owners and separates concurrent GC',
      () {
    final capture = _capture();
    final report = summarizeLayoutCpu(capture);
    final phase = (report['phases']! as List).single as Map;
    expect(phase['sampleCount'], 4);
    expect(phase['truncatedStacks'], 1);
    expect(phase['exclusiveBuckets'], {
      'numeric_model_preparation': 1,
      'numeric_exact_widths': 1,
      'exact_fragment_artifacts': 1,
      'gc': 1,
    });
    final layout = (phase['layoutsSlowestFirst'] as List).single as Map;
    // Nested UI GC is counted once; a long worker event is separate evidence.
    expect(layout['gcEventOverlapUs'], 65);
    expect(layout['layoutThreadGcEventOverlapUs'], 10);
    expect(layout['timelineCoversLayout'], isTrue);
    expect(phase['layoutsWithoutSamples'], 0);
  });

  test('missing CPU samples and truncated timeline coverage remain visible',
      () {
    final capture = _capture();
    (capture['cpu'] as Map)['samples'] = [
      {
        'timestamp': 200,
        'tid': 7,
        'stack': [0],
        'userTag': 'Flow.layout'
      },
      {'timestamp': 150, 'tid': 8, 'stack': [], 'userTag': 'Default'},
    ];
    (capture['timeline'] as Map)['timeOriginMicros'] = 150;
    final report = summarizeLayoutCpu(capture);
    final phase = (report['phases']! as List).single as Map;
    expect(phase['layoutsWithoutSamples'], 1);
    expect(phase['sampleCount'], 0);
    final layout = (phase['layoutsSlowestFirst'] as List).single as Map;
    expect(layout['timelineCoversLayout'], isFalse);
    expect(layout['layoutThreadGcEventOverlapUs'], 0);
  });
}

Map<String, dynamic> _capture() => {
      'cpu': {
        'samplePeriod': 1000,
        'functions': [
          _function('measure', '_CompactTextCache'),
          _function('measureRange', '_PreparedText'),
          _function('_CompactTextModel', '_CompactTextModel'),
        ],
        'samples': [
          {
            'timestamp': 110,
            'tid': 7,
            'stack': [0, 2],
            'userTag': 'Flow.firstAttempt'
          },
          {
            'timestamp': 120,
            'tid': 7,
            'stack': [0],
            'userTag': 'Flow.firstAttempt'
          },
          {
            'timestamp': 130,
            'tid': 7,
            'stack': [1],
            'userTag': 'Flow.firstAttempt',
            'truncated': true
          },
          {
            'timestamp': 140,
            'tid': 7,
            'stack': [],
            'userTag': 'Flow.firstAttempt',
            'vmTag': 'GC'
          },
          {'timestamp': 160, 'tid': 8, 'stack': [], 'userTag': 'Default'},
        ],
      },
      'benchmark': {
        'scenarios': [
          {
            'name': 'example',
            'samples': {
              'initial': [
                {
                  'fullLayoutUs': 100,
                  'layoutStartMicros': 100,
                  'layoutEndMicros': 200
                },
              ]
            }
          },
        ]
      },
      'timeline': {
        'timeOriginMicros': 100,
        'timeExtentMicros': 100,
        'traceEvents': [
          {
            'cat': 'GC',
            'name': 'CollectNewGeneration',
            'ph': 'B',
            'pid': 1,
            'tid': 7,
            'ts': 120
          },
          {
            'cat': 'GC',
            'name': 'Scavenge',
            'ph': 'X',
            'pid': 1,
            'tid': 7,
            'ts': 121,
            'dur': 7
          },
          {
            'cat': 'GC',
            'name': 'CollectNewGeneration',
            'ph': 'E',
            'pid': 1,
            'tid': 7,
            'ts': 130
          },
          {
            'cat': 'GC',
            'name': 'ConcurrentMark',
            'ph': 'X',
            'pid': 1,
            'tid': 8,
            'ts': 115,
            'dur': 65
          },
        ],
      },
    };

Map<String, dynamic> _function(String name, String owner) => {
      'resolvedUrl':
          'package:super_text_layout/src/experimental/flow/compact_text.dart',
      'function': {
        'name': name,
        'owner': {'type': '@Class', 'name': owner}
      },
    };
