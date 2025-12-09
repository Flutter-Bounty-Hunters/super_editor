import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/src/test/super_editor_test/tasks_test_tools.dart';
import 'package:super_editor/super_editor.dart';

import '../../../lib/src/test/super_reader_test/reader_test_tools.dart';

void main() {
  group('SuperReader tasks >', () {
    testWidgetsOnAllPlatforms("are displayed in a read-only document", (tester) async {
      await tester //
          .createDocument()
          .withCustomContent(
            MutableDocument(
              nodes: [
                TaskNode(id: "1", text: AttributedText(), isComplete: false),
                TaskNode(id: "2", text: AttributedText(), isComplete: true),
              ],
            ),
          )
          .pump();

      // Ensure the default task component is rendered.
      expect(find.byType(TaskComponent), findsNWidgets(2));
    });

    testWidgetsOnAllPlatforms("cannot be toggled by the user", (tester) async {
      await tester //
          .createDocument()
          .withCustomContent(
            MutableDocument(
              nodes: [
                TaskNode(id: '1', text: AttributedText(), isComplete: false),
                TaskNode(id: '2', text: AttributedText(), isComplete: true),
              ],
            ),
          )
          .pump();

      // Tap on the first task's checkbox.
      await tester.tapOnCheckbox('1');

      // Ensure that the task's checkbox didn't change from unchecked to checked.
      expect(TaskInspector.isChecked('1'), isFalse);

      // Tap on the second task's checkbox.
      await tester.tapOnCheckbox('2');

      // Ensure that the task's checkbox didn't change from checked to unchecked.
      expect(TaskInspector.isChecked('1'), isFalse);
    });
  });
}
