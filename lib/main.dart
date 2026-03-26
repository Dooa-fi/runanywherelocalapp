import 'package:flutter/material.dart';
import 'package:runanywhere/runanywhere.dart';
import 'package:runanywhere_onnx/runanywhere_onnx.dart';
import 'package:runanywhere_llamacpp/runanywhere_llamacpp.dart';

import 'screens/home_screen.dart';
import 'services/model_manager.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize RunAnywhere SDK
  await RunAnywhere.initialize();

  // Register ONNX backend (STT / TTS / VAD)
  await Onnx.register();

  // Register LlamaCpp backend (LLM)
  await LlamaCpp.register();

  // Register all models we will use
  ModelManager.registerModels();

  runApp(const RunAnywhereApp());
}

class RunAnywhereApp extends StatelessWidget {
  const RunAnywhereApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RunAnywhere Offline Copilot',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
