import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/model_manager.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RunAnywhereApp());
}

class RunAnywhereApp extends StatelessWidget {
  const RunAnywhereApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline Copilot',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
