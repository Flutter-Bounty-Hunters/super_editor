import 'package:slack/domain/message.dart';
import 'package:super_editor/super_editor.dart';

final fakeMessages = <Message>[
  _buildMessage(
    from: "1",
    dateTime: DateTime(2025, 5, 14, 16, 50),
    message:
        "**Hey** @DevDana! Have you had a chance to delve deep into the **Flutter** framework? I've found some interesting aspects about it.",
  ),
  _buildMessage(
    from: "2",
    dateTime: DateTime(2025, 5, 14, 16, 52),
    message:
        "Oh, hey @FlutterGuru! I've been dabbling a bit. It's fascinating how it manages to be so _versatile_. What caught your attention?",
  ),
  _buildMessage(
    from: "1",
    dateTime: DateTime(2025, 5, 15, 16, 54),
    message:
        "Here are a few things that really stand out to me:\n\n- **Hot Reload**: Super useful during development.\n- **Single Codebase**: Write once and deploy everywhere.\n- **Dart Language**: Initially a curveball but it grew on me.\n\nWhat about you?",
  ),
  _buildMessage(
    from: "2",
    dateTime: DateTime(2025, 5, 15, 16, 56),
    message:
        "I'm particularly intrigued by the following:\n\n1. _Rich widget catalog_: Makes UI building a breeze.\n2. _Performance_: Apps run smoothly with native-like performance.\n3. _Community support_: The community is simply amazing.",
  ),
  _buildMessage(
    from: "1",
    dateTime: DateTime(2025, 5, 15, 16, 58),
    message:
        "Speaking of community, have you seen the plethora of resources out there? Here are a few I recommend:\n\n-  [Flutter Docs](https://flutter.dev/docs)\n-  [Dart Packages](https://pub.dev/flutter)\n-  [Flutter YouTube Channel](https://www.youtube.com/flutterdev)",
  ),
  _buildMessage(
    from: "2",
    dateTime: DateTime(2025, 5, 16, 17, 01),
    message:
        "Oh, I've been on the YouTube channel! So many tutorials and demos. Also, here's a visual representation of Flutter's architecture I found useful:\n\n![Flutter Architecture](https://docs.flutter.dev/assets/images/docs/arch-overview/archdiagram.png)",
  ),
  _buildMessage(
    from: "1",
    dateTime: DateTime(2025, 5, 16, 17, 03),
    message:
        "I've seen that! It's quite an insightful diagram. By the way, have you heard of the controversies around Flutter? Some say it might not be the best for every project.",
  ),
  _buildMessage(
    from: "1",
    dateTime: DateTime(2025, 5, 16, 17, 05),
    message:
        "For example, while it's great for most apps, heavy 3D games or highly specialized native applications might face challenges. But then again, every tool has its pros and cons, right?",
  ),
  _buildMessage(
    from: "2",
    dateTime: DateTime(2025, 5, 16, 17, 08),
    message:
        "Absolutely! No tool is a one-size-fits-all solution. And it's always about picking the right tool for the right job. By the way, did you see the new updates in the latest version? They've introduced some ~~deprecated widgets~~ and replaced them with more efficient ones.",
  ),
  _buildMessage(
    from: "1",
    dateTime: DateTime(2025, 5, 16, 17, 10),
    message:
        "I did notice that! And it shows how dedicated they are to improving and evolving. It's one of the reasons I'm so bullish on Flutter. **Onward and upward!**",
  ),
];

Message _buildMessage({
  required String from,
  required DateTime dateTime,
  required String message,
}) {
  return Message(
    userId: from,
    sentAt: dateTime,
    content: deserializeMarkdownToDocument(
      message,
    ),
  );
}
