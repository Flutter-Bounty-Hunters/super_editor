import 'package:example_chat/message_page_scaffold_demo/demo_chaos_monkey_message_page.dart';
import 'package:example_chat/message_page_scaffold_demo/demo_super_editor_message_page.dart';
import 'package:example_chat/message_page_scaffold_demo/demo_textfield_message_page.dart';
import 'package:flutter/material.dart';

class MessagePageScaffoldDemo extends StatefulWidget {
  const MessagePageScaffoldDemo({super.key});

  @override
  State<MessagePageScaffoldDemo> createState() => _MessagePageScaffoldDemoState();
}

class _MessagePageScaffoldDemoState extends State<MessagePageScaffoldDemo> {
  var _demo = _Demo.superEditor;

  void _showChaosMonkeyDemo() {
    setState(() {
      _demo = _Demo.chaosMonkey;
    });
  }

  void _showTextFieldDemo() {
    setState(() {
      _demo = _Demo.textfield;
    });
  }

  void _showSuperEditorDemo() {
    setState(() {
      _demo = _Demo.superEditor;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red,
        elevation: 0,
        actions: [
          IconButton(onPressed: _showChaosMonkeyDemo, icon: Icon(Icons.pets)),
          IconButton(onPressed: _showTextFieldDemo, icon: Icon(Icons.format_line_spacing)),
          IconButton(onPressed: _showSuperEditorDemo, icon: Icon(Icons.edit)),
        ],
      ),
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth / constraints.maxHeight <= 1) {
            // Show phone experience.
            return _buildDemo();
          }

          // Show the tablet experience.
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 64,
              ),
              Container(
                width: 1,
                color: Colors.black.withValues(alpha: 0.1),
              ),
              Spacer(),
              Container(
                width: 1,
                color: Colors.black.withValues(alpha: 0.1),
              ),
              SizedBox(
                width: 450,
                child: _buildDemo(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDemo() {
    return switch (_demo) {
      _Demo.chaosMonkey => ChaosMonkeyMessagePageDemo(),
      _Demo.textfield => TextFieldMessagePageDemo(),
      _Demo.superEditor => SuperEditorMessagePageDemo(),
    };
  }
}

enum _Demo {
  chaosMonkey,
  textfield,
  superEditor;
}
