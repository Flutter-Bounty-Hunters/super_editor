import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/unicode/generate_line_break_data.dart';

void main() {
  test('unverified Unicode inputs cannot overwrite the generated table', () {
    final directory = Directory.systemTemp.createTempSync('unicode_generator_');
    addTearDown(() => directory.deleteSync(recursive: true));
    File('${directory.path}/FlowLineBreak-16.txt')
        .writeAsStringSync('modified data');
    final output = File('${directory.path}/table.dart')
      ..writeAsStringSync('existing table');

    expect(
      () => generateLineBreakData(directory, output),
      throwsA(isA<FormatException>().having((error) => error.message, 'message',
          contains('pinned Unicode 16 data'))),
    );
    expect(output.readAsStringSync(), 'existing table');
  });
}
