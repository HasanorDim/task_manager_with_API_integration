import 'package:flutter/material.dart';
import 'package:task_manager/screens/home_screen.dart';
import 'utils/app_styles.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;

  void _toggleTheme(bool isDark) {
    setState(() {
      _isDarkMode = isDark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      debugShowCheckedModeBanner: false,
      theme: _isDarkMode ? AppStyles.darkTheme : AppStyles.lightTheme,
      home: HomeScreen(isDarkMode: _isDarkMode, onThemeChanged: _toggleTheme),
    );
  }
}
