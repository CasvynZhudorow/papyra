import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'theme.dart';

class PapyraApp extends StatelessWidget {
  const PapyraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Papyra',
      debugShowCheckedModeBanner: false,
      theme: buildPapyraTheme(Brightness.light),
      darkTheme: buildPapyraTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}