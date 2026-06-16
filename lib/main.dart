import 'package:flutter/material.dart';
import 'views/launch_screen.dart';
import 'views/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _showLaunch = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Labo d'Émile",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: _showLaunch
          ? LaunchScreen(onDone: () => setState(() => _showLaunch = false))
          : HomeScreen(),
    );
  }
}
