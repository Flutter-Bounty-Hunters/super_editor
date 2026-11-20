import 'package:flutter/material.dart';
import 'package:gemini/features/home_screen.dart';

import 'infrastructure/theme.dart';

void main() {
  runApp(const SuperGeminiCloneApp());
}

class SuperGeminiCloneApp extends StatelessWidget {
  const SuperGeminiCloneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Super Gemini', //
      theme: appTheme,
      home: const HomeScreen(),
    );
  }
}
