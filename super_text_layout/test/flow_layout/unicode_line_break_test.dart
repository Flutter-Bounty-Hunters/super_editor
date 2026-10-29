import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:super_text_layout/experimental_flow.dart';

void main() {
  test('Unicode 16 default opportunities match the complete official corpus',
      () {
    final fixture =
        File('test/flow_layout/data/unicode/LineBreakTest-16.0.0.txt');
    var cases = 0, failures = 0;
    final examples = <String>[];
    for (final line in fixture.readAsLinesSync()) {
      final data = line.split('#').first.trim();
      if (data.isEmpty) {
        continue;
      }
      final tokens = data.split(RegExp(r'\s+'));
      final runes = <int>[], expected = <int>[];
      var offset = 0;
      for (final token in tokens) {
        if (token == '÷') {
          if (offset > 0) {
            expected.add(offset);
          }
        } else if (token != '×') {
          final rune = int.parse(token, radix: 16);
          runes.add(rune);
          offset += rune > 0xffff ? 2 : 1;
        }
      }
      final actual = UnicodeLineBreaks.compute(String.fromCharCodes(runes))
          .map((b) => b.offset)
          .toList();
      cases++;
      if (actual.join(',') != expected.join(',')) {
        failures++;
        if (examples.length < 20) {
          examples.add(
              '$data expected=$expected actual=$actual ${line.split('#').last}');
        }
      }
    }
    expect(cases, 16672);
    expect(failures, 0,
        reason: '$failures / $cases failures\n${examples.join('\n')}');
  });
  test('mandatory breaks and supplementary UTF-16 offsets are explicit', () {
    final breaks = UnicodeLineBreaks.compute('😀\r\nx\u2028y');
    expect(breaks.map((b) => b.offset), [4, 6, 7]);
    expect(breaks.map((b) => b.mandatory), [true, true, false]);
    final empty = UnicodeLineBreaks.compute('');
    expect(empty.single.offset, 0);
    expect(empty.single.mandatory, isFalse);
  });
}
