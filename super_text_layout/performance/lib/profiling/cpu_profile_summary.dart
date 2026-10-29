import 'dart:math' as math;

/// CPU samples are statistical evidence; GC overlap is wall time during which
/// a GC event was recorded, not a measurement of a stop-the-world pause.
Map<String, Object?> summarizeLayoutCpu(Map<String, dynamic> capture) {
  final cpu = capture['cpu'] as Map<String, dynamic>;
  final functions = cpu['functions'] as List<dynamic>;
  final samples = cpu['samples'] as List<dynamic>;
  final benchmark = capture['benchmark'] as Map<String, dynamic>;
  final gc = _gcIntervals(capture['timeline'] as Map<String, dynamic>?);
  final phases = <Map<String, Object?>>[];
  final timestamps = samples.map((dynamic s) => s['timestamp'] as int).toList()
    ..sort();
  for (final dynamic scenario in benchmark['scenarios'] as List<dynamic>) {
    for (final phase in (scenario['samples'] as Map<String, dynamic>).entries) {
      final totals = <String, int>{}, hotspots = <String, int>{};
      final layouts = <Map<String, Object?>>[];
      var totalSamples = 0, truncated = 0;
      for (final dynamic layout in phase.value as List<dynamic>) {
        final start = layout['layoutStartMicros'] as int;
        final end = layout['layoutEndMicros'] as int;
        final buckets = <String, int>{}, local = <String, int>{};
        var count = 0;
        final layoutThreads = <int>{};
        for (final dynamic sample in samples) {
          final at = sample['timestamp'] as int;
          if (at < start || at >= end) continue;
          final names = <String>{};
          final ownNames = <String>{};
          for (final dynamic index in sample['stack'] as List<dynamic>) {
            final fn = functions[index as int] as Map<String, dynamic>;
            final name = _functionName(fn['function'] as Map<String, dynamic>);
            names.add(name);
            if ((fn['resolvedUrl'] as String? ?? '')
                .contains('/experimental/flow/')) {
              ownNames.add(name);
            }
          }
          final tag = sample['userTag'] as String? ?? '';
          if (!tag.startsWith('Flow.') &&
              !names.any(
                  (n) => n.contains('RenderFlowParagraph.performLayout'))) {
            continue;
          }
          count++;
          layoutThreads.add(sample['tid'] as int);
          if (sample['truncated'] == true) truncated++;
          final bucket = _bucket(names, tag, sample['vmTag'] as String? ?? '');
          buckets.update(bucket, (v) => v + 1, ifAbsent: () => 1);
          totals.update(bucket, (v) => v + 1, ifAbsent: () => 1);
          for (final name in ownNames) {
            local.update(name, (v) => v + 1, ifAbsent: () => 1);
            hotspots.update(name, (v) => v + 1, ifAbsent: () => 1);
          }
        }
        totalSamples += count;
        final overlapUs = _overlapDuration(start, end, gc);
        final layoutGcUs = _overlapDuration(start, end,
            gc.where((interval) => layoutThreads.contains(interval.$3)));
        final timeline = capture['timeline'] as Map<String, dynamic>?;
        final timelineStart = timeline?['timeOriginMicros'] as int?;
        final timelineExtent = timeline?['timeExtentMicros'] as int?;
        layouts.add({
          'fullLayoutUs': layout['fullLayoutUs'],
          'layoutStartMicros': start,
          'sampleCount': count,
          'buckets': buckets,
          'gcEventOverlapUs': overlapUs,
          'layoutThreadGcEventOverlapUs': layoutGcUs,
          'timelineCoversLayout': timelineStart != null &&
              timelineExtent != null &&
              timelineStart <= start &&
              timelineStart + timelineExtent >= end,
          'topInclusiveLocalFunctions': _rank(local, 12),
        });
      }
      layouts.sort((a, b) =>
          (b['fullLayoutUs'] as num).compareTo(a['fullLayoutUs'] as num));
      phases.add({
        'scenario': scenario['name'],
        'phase': phase.key,
        'layoutCount': layouts.length,
        'sampleCount': totalSamples,
        'layoutsWithoutSamples':
            layouts.where((l) => l['sampleCount'] == 0).length,
        'truncatedStacks': truncated,
        'exclusiveBuckets': totals,
        'topInclusiveLocalFunctions': _rank(hotspots, 20),
        'layoutsSlowestFirst': layouts,
      });
    }
  }
  return {
    'samplePeriodUs': cpu['samplePeriod'],
    'captureSamples': samples.length,
    'firstSampleMicros': timestamps.isEmpty ? null : timestamps.first,
    'lastSampleMicros': timestamps.isEmpty ? null : timestamps.last,
    'timelineFlags': capture['timelineFlags'],
    'recordedGcIntervals': gc.length,
    'interpretation':
        'Exclusive buckets partition sampled layout CPU. Inclusive functions overlap. GC overlap includes concurrent activity and is not pause time. Unsampled wall time is not attributed.',
    'phases': phases,
  };
}

String _bucket(Set<String> names, String tag, String vmTag) {
  bool has(String value) => names.any((n) => n.contains(value));
  if (vmTag == 'GC' || has('Scavenger') || has('CollectGarbage')) return 'gc';
  if (has('_CompactTextModel.') || has('_CompactTextCache.get')) {
    return 'numeric_model_preparation';
  }
  if (has('_CompactTextCache.measure')) return 'numeric_exact_widths';
  if (has('_numericChunks')) return 'numeric_chunk_preparation';
  if (has('_CompactPaddedText.rejectedWidth') ||
      has('_CompactPreparedText.rejectedWidth') ||
      has('furthestPotentialBreak')) {
    return 'numeric_candidate_search';
  }
  if (has('_PreparedText.measureRange') ||
      has('_TextMeasurement.') ||
      has('_CompoundTextMeasurement.')) {
    return 'exact_fragment_artifacts';
  }
  if (tag == 'Flow.prepare' ||
      has('_prepareRuns') ||
      has('_TextBreakAnalysis.') ||
      has('_TextAnalysisCache.get')) {
    return 'source_preparation';
  }
  if (tag == 'Flow.children') return 'child_layout';
  if (has('_Composer._commit') || has('commitFragments')) {
    return 'fragment_commit';
  }
  return 'other_layout';
}

List<Map<String, Object>> _rank(Map<String, int> counts, int limit) {
  final entries = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries
      .take(limit)
      .map((e) => <String, Object>{'function': e.key, 'samples': e.value})
      .toList();
}

List<(int, int, int)> _gcIntervals(Map<String, dynamic>? timeline) {
  final result = <(int, int, int)>[];
  final pending = <String, List<int>>{};
  for (final dynamic e in timeline?['traceEvents'] as List<dynamic>? ?? []) {
    if (!(e['cat'] as String? ?? '').split(',').contains('GC')) continue;
    final at = (e['ts'] as num?)?.toInt();
    if (at == null) continue;
    final key = '${e['pid']}/${e['tid']}/${e['name']}';
    if (e['ph'] == 'X') {
      result
          .add((at, at + ((e['dur'] as num?)?.toInt() ?? 0), e['tid'] as int));
    } else if (e['ph'] == 'B') {
      (pending[key] ??= []).add(at);
    } else if (e['ph'] == 'E' && (pending[key]?.isNotEmpty ?? false)) {
      result.add((pending[key]!.removeLast(), at, e['tid'] as int));
    }
  }
  return result;
}

String _functionName(Map<String, dynamic> function) {
  final owner = function['owner'] as Map<String, dynamic>?;
  final name = function['name'] as String;
  if (owner != null &&
      (owner['type'] == '@Class' || owner['type'] == '@Function')) {
    return '${owner['name']}.$name';
  }
  return name;
}

int _overlapDuration(int start, int end, Iterable<(int, int, int)> events) {
  final intervals = <(int, int)>[];
  for (final event in events) {
    final a = math.max(start, event.$1), b = math.min(end, event.$2);
    if (a < b) intervals.add((a, b));
  }
  intervals.sort((a, b) => a.$1.compareTo(b.$1));
  var duration = 0, previousEnd = start;
  for (final interval in intervals) {
    duration += math.max(0, interval.$2 - math.max(previousEnd, interval.$1));
    previousEnd = math.max(previousEnd, interval.$2);
  }
  return duration;
}
