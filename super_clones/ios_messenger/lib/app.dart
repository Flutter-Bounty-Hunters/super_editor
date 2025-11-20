import 'package:flutter/material.dart';
import 'package:ios_messenger/conversation/conversation_screen.dart';

class IOSMessengerApp extends StatelessWidget {
  const IOSMessengerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Messenger',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      home: const ConversationScreen(),
    );
  }
}
