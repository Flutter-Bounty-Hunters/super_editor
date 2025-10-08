import 'package:flutter/material.dart';

/// A simulated chat conversation thread, which is simulated as a bottom-aligned
/// list of tiles.
class FakeChatThread extends StatelessWidget {
  const FakeChatThread({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      reverse: true,
      // ^ The list starts at the bottom and grows upward. This is how
      //   we should layout chat conversations where the most recent
      //   message appears at the bottom, and you want to retain the
      //   scroll offset near the newest messages, not the oldest.
      itemBuilder: (context, index) {
        if (index == 8) {
          // Arbitrarily placed text field to test moving focus between a non-editor
          // and the editor.
          return TextField(
            decoration: InputDecoration(
              hintText: "Content text field...",
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Material(
            color: Colors.white.withValues(alpha: 0.5),
            child: ListTile(
              title: Text("This is item $index"),
              subtitle: Text("This is a subtitle for $index"),
            ),
          ),
        );
      },
    );
  }
}
