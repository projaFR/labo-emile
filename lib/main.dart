import 'package:flutter/material.dart';
import 'theme.dart';
import 'services/settings_service.dart';
import 'views/launch_screen.dart';
import 'views/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SettingsService().load();
  } catch (_) {}
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
      theme: buildTheme(LaboColors.light),
      home: _showLaunch
          ? LaunchScreen(onDone: () => setState(() => _showLaunch = false))
          : HomeScreen(),
    );
  }
}
