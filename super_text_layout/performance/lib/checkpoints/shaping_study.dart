/// Host-specific research corpus. Fonts are loaded, never copied into the repo.
library;

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'prepared_text.dart';
import 'prepared_text_benchmark.dart';

const _fonts = <String, String>{
  'StudyTimes': '/System/Library/Fonts/Supplemental/Times New Roman.ttf',
  'StudyPalatino': '/System/Library/Fonts/Palatino.ttc',
  'StudyArabic': '/System/Library/Fonts/GeezaPro.ttc',
  'StudyNastaliq': '/System/Library/Fonts/NotoNastaliq.ttc',
  'StudyDevanagari':
      '/System/Library/Fonts/Supplemental/Devanagari Sangam MN.ttc',
  'StudyBengali': '/System/Library/Fonts/KohinoorBangla.ttc',
  'StudyTamil': '/System/Library/Fonts/Supplemental/Tamil Sangam MN.ttc',
  'StudySinhala': '/System/Library/Fonts/Supplemental/Sinhala Sangam MN.ttc',
  'StudyThai': '/System/Library/Fonts/Supplemental/Thonburi.ttc',
  'StudyKhmer': '/System/Library/Fonts/Supplemental/Khmer Sangam MN.ttf',
  'StudyCJK': '/System/Library/Fonts/Hiragino Sans GB.ttc',
  'StudyEmoji': '/System/Library/Fonts/Apple Color Emoji.ttc',
};

class _Case {
  const _Case(this.name, this.font, this.text, {this.spacing = 0});
  final String name, font, text;
  final double spacing;
  final double size = 20;
}

const _cases = [
  _Case('latin_control', 'CheckpointRoboto',
      'office affinity AVATAR To Wi final'),
  _Case('mono_control', 'CheckpointMono', 'office affinity AVATAR To Wi final'),
  _Case('times_ligatures', 'StudyTimes',
      'office affinity efficient AVATAR To Wi'),
  _Case('palatino_ligatures', 'StudyPalatino',
      'office affinity efficient AVATAR To Wi'),
  _Case('positive_spacing', 'CheckpointRoboto', 'office affinity AVATAR To Wi',
      spacing: 1),
  _Case('negative_spacing', 'CheckpointRoboto', 'Wi WiWi iiiiiii WWW AVATAR',
      spacing: -5),
  _Case('arabic', 'StudyArabic', 'السلام عليكم ورحمة الله العربية جميلة'),
  _Case('arabic_marks', 'StudyArabic', 'السَّلَامُ عَلَيْكُمْ بِسْمِ اللَّهِ'),
  _Case('urdu_nastaliq', 'StudyNastaliq', 'پاکستان کی خوبصورت زبان اردو ہے'),
  _Case('devanagari', 'StudyDevanagari',
      'नमस्ते दुनिया क्षत्रिय श्रद्धा प्रार्थना'),
  _Case('bengali', 'StudyBengali', 'বাংলা ভাষা সুন্দর পৃথিবী বন্ধু শ্রদ্ধা'),
  _Case('tamil', 'StudyTamil', 'தமிழ் மொழி அழகான உலகம் நண்பர்கள்'),
  _Case('sinhala', 'StudySinhala', 'සිංහල භාෂාව ලස්සන ලෝකයක්'),
  _Case('thai', 'StudyThai', 'ภาษาไทยเป็นภาษาที่สวยงามและน่าสนใจ'),
  _Case('khmer', 'StudyKhmer', 'ភាសាខ្មែរមានភាពស្រស់ស្អាត'),
  _Case('cjk', 'StudyCJK', '中文排版（标点）测试。文字可以换行。'),
  _Case('emoji', 'StudyEmoji', '👩‍👩‍👧‍👦 👨🏽‍💻 🇯🇵 ❤️ 🏳️‍🌈 😀'),
  _Case('combining_marks', 'CheckpointRoboto',
      'cafe\u0301 nai\u0308ve A\u030a e\u0301e\u0301 office'),
  _Case('mixed_bidi_width_only', 'StudyArabic', 'abc العربية 123 (مرحبا) xyz'),
];

Future<Map<String, Object>> runShapingStudy({String assetPrefix = ''}) async {
  await loadCheckpointFonts(prefix: assetPrefix);
  final fontMetadata = <String, Object>{};
  final available = {'CheckpointRoboto', 'CheckpointMono'};
  for (final entry in _fonts.entries) {
    final file = File(entry.value);
    if (!await file.exists()) {
      fontMetadata[entry.key] = {'path': entry.value, 'available': false};
      continue;
    }
    final bytes = await file.readAsBytes();
    await (FontLoader(entry.key)
          ..addFont(Future.value(ByteData.sublistView(bytes))))
        .load();
    final hash =
        await Process.run('/usr/bin/shasum', ['-a', '256', entry.value]);
    if (hash.exitCode != 0) {
      throw StateError('Could not fingerprint ${entry.value}');
    }
    fontMetadata[entry.key] = {
      'path': entry.value,
      'available': true,
      'bytes': bytes.length,
      'sha256': (hash.stdout as String).split(' ').first
    };
    available.add(entry.key);
  }
  final results = <Map<String, Object>>[];
  for (final fixture in _cases) {
    if (!available.contains(fixture.font)) {
      results.add({
        'name': fixture.name,
        'font': fixture.font,
        'skipped': 'Font file unavailable'
      });
      continue;
    }
    final style = TextStyle(
        fontFamily: fixture.font,
        fontSize: fixture.size,
        letterSpacing: fixture.spacing);
    final source = CheckpointSource(fixture.text, style);
    try {
      final offsets = [0, ...source.breaks.map((b) => b.offset)];
      final exact = <(int, int), double>{};
      for (var a = 0; a < offsets.length - 1; a++) {
        for (var b = a + 1; b < offsets.length; b++) {
          exact[(offsets[a], offsets[b])] =
              source.measure(offsets[a], offsets[b], 10000);
        }
      }
      final widths = <String, List<double>>{
        if (fixture.spacing < 0) '24': [24],
        if (fixture.spacing < 0) '40': [40],
        if (fixture.spacing < 0) '60': [60],
        '80': [80],
        '120': [120],
        '200': [200],
        '320': [320],
        'changing': [80, 200, 120, 320],
      };
      // Exact-only probe generation keeps all context sizes on identical inputs.
      for (final end in offsets.skip(1).take(24)) {
        final width = exact[(0, end)]!;
        for (final candidate in [width - .02, width + .02]) {
          if (candidate >= (fixture.spacing < 0 ? 24 : 80) &&
              candidate <= 400) {
            widths['threshold_${end}_$candidate'] = [candidate];
          }
        }
      }
      final oracle = <String, List<CheckpointLine>>{};
      for (final plan in widths.entries) {
        oracle[plan.key] = fitExact(source, plan.value);
      }
      final contexts = <Map<String, Object>>[];
      for (final size in [3, 4, 6, 8]) {
        final model = CompactPreparedSegments(source, maxContext: size);
        var failures = 0, material = 0, breaks = 0;
        var maxError = 0.0;
        final worst = <Map<String, Object>>[];
        for (final entry in exact.entries) {
          final predicted = model.width(entry.key.$1, entry.key.$2);
          final error = (predicted - entry.value).abs();
          if (error > .01) failures++;
          if (error >= .5) material++;
          if (error > maxError) maxError = error;
          if (error > .01) {
            worst.add({
              'start': entry.key.$1,
              'end': entry.key.$2,
              'text': fixture.text.substring(entry.key.$1, entry.key.$2),
              'predicted': predicted,
              'exact': entry.value,
              'error': error
            });
          }
        }
        worst.sort(
            (a, b) => (b['error']! as double).compareTo(a['error']! as double));
        final breakExamples = <Map<String, Object>>[];
        for (final plan in widths.entries) {
          final expected = oracle[plan.key]!;
          try {
            final actual = fitPrepared(model, plan.value);
            final same = listEquals(
                expected.map((l) => (l.row, l.start, l.end)).toList(),
                actual.map((l) => (l.row, l.start, l.end)).toList());
            if (!same) {
              breaks++;
              if (breakExamples.length < 3) {
                breakExamples.add({
                  'plan': plan.key,
                  'widths': plan.value,
                  'exact': expected.map((l) => l.toJson()).toList(),
                  'predicted': actual.map((l) => l.toJson()).toList()
                });
              }
            }
          } on StateError catch (e) {
            breaks++;
            if (breakExamples.length < 3) {
              breakExamples.add({'plan': plan.key, 'error': e.toString()});
            }
          }
        }
        contexts.add({
          'graphemes': size,
          'ranges': exact.length,
          'rangeFailures': failures,
          'errorsAtLeastHalfPixel': material,
          'maxWidthError': maxError,
          'layoutPlans': widths.length,
          'breakFailures': breaks,
          'worstRanges': worst.take(3).toList(),
          'breakExamples': breakExamples,
          'measurementCalls': model.measurementCalls,
          'tableEntries': model.fragmentEntries
        });
      }
      results.add({
        'name': fixture.name,
        'font': fixture.font,
        'text': fixture.text,
        'fontSize': fixture.size,
        'letterSpacing': fixture.spacing,
        'contexts': contexts
      });
    } finally {
      source.dispose();
    }
  }
  return {
    'checkpointVersion': 5,
    'study': 'shaping-context',
    'mode': kProfileMode ? 'profile' : 'debug',
    'recordedAtUtc': DateTime.now().toUtc().toIso8601String(),
    'scope':
        'Width-fitting only in the existing LTR engine. Not RTL visual ordering, editing, selection, or rendering validation. Explicit font aliases; fallback glyph coverage not independently audited. Failures are findings, not suppressed. The .5px count supplements, not replaces, the .01px width criterion.',
    'fonts': fontMetadata,
    'results': results
  };
}
