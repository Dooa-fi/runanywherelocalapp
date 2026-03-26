import 'package:runanywhere/runanywhere.dart';
import 'package:runanywhere_onnx/runanywhere_onnx.dart';
import 'package:runanywhere_llamacpp/runanywhere_llamacpp.dart';

/// Central place to register all AI models used in the app.
/// Call once at startup after backends are registered.
class ModelManager {
  // Model IDs
  static const String sttModelId = 'whisper-tiny-en';
  static const String llmModelId = 'smollm2-360m';
  static const String ttsModelId = 'piper-amy-medium';

  static void registerModels() {
    // ── STT: Whisper Tiny English (~75 MB) ──────────────────────────────────
    Onnx.addModel(
      id: sttModelId,
      name: 'Whisper Tiny (English)',
      url: 'https://github.com/RunanywhereAI/sherpa-onnx/releases/download/'
          'runanywhere-models-v1/sherpa-onnx-whisper-tiny.en.tar.gz',
      modality: ModelCategory.speechRecognition,
      memoryRequirement: 75 * 1000 * 1000,
    );

    // ── TTS: Piper Amy Medium (~50 MB) ──────────────────────────────────────
    Onnx.addModel(
      id: ttsModelId,
      name: 'Piper Amy (English)',
      url: 'https://github.com/RunanywhereAI/sherpa-onnx/releases/download/'
          'runanywhere-models-v1/vits-piper-en_US-amy-medium.tar.gz',
      modality: ModelCategory.speechSynthesis,
      memoryRequirement: 50 * 1000 * 1000,
    );

    // ── LLM: SmolLM2 360M Q4_K_M (~250 MB, good mobile trade-off) ──────────
    LlamaCpp.addModel(
      id: llmModelId,
      name: 'SmolLM2 360M (Quantized)',
      url: 'https://huggingface.co/bartowski/SmolLM2-360M-Instruct-GGUF/'
          'resolve/main/SmolLM2-360M-Instruct-Q4_K_M.gguf',
      memoryRequirement: 250 * 1000 * 1000,
    );
  }

  // ── State helpers ──────────────────────────────────────────────────────────
  static bool get sttReady => RunAnywhere.isSTTModelLoaded;
  static bool get ttsReady => RunAnywhere.isTTSVoiceLoaded;
  static bool get llmReady => RunAnywhere.isModelLoaded;

  /// Download + load all three models, reporting progress via callback.
  static Stream<ModelLoadEvent> loadAll() async* {
    yield ModelLoadEvent(model: 'STT', phase: 'Downloading Whisper…', progress: 0);
    await for (final p in RunAnywhere.downloadModel(sttModelId)) {
      yield ModelLoadEvent(
        model: 'STT',
        phase: 'Downloading Whisper…',
        progress: p.percentage,
      );
      if (p.state.isCompleted) break;
    }
    yield ModelLoadEvent(model: 'STT', phase: 'Loading Whisper…', progress: 1.0);
    await RunAnywhere.loadSTTModel(sttModelId);

    yield ModelLoadEvent(model: 'TTS', phase: 'Downloading TTS voice…', progress: 0);
    await for (final p in RunAnywhere.downloadModel(ttsModelId)) {
      yield ModelLoadEvent(
        model: 'TTS',
        phase: 'Downloading TTS voice…',
        progress: p.percentage,
      );
      if (p.state.isCompleted) break;
    }
    yield ModelLoadEvent(model: 'TTS', phase: 'Loading TTS voice…', progress: 1.0);
    await RunAnywhere.loadTTSVoice(ttsModelId);

    yield ModelLoadEvent(model: 'LLM', phase: 'Downloading SmolLM2…', progress: 0);
    await for (final p in RunAnywhere.downloadModel(llmModelId)) {
      yield ModelLoadEvent(
        model: 'LLM',
        phase: 'Downloading SmolLM2…',
        progress: p.percentage,
      );
      if (p.state.isCompleted) break;
    }
    yield ModelLoadEvent(model: 'LLM', phase: 'Loading SmolLM2…', progress: 1.0);
    await RunAnywhere.loadModel(llmModelId);

    yield ModelLoadEvent(model: 'ALL', phase: 'All models ready!', progress: 1.0, done: true);
  }
}

class ModelLoadEvent {
  final String model;
  final String phase;
  final double progress;
  final bool done;

  const ModelLoadEvent({
    required this.model,
    required this.phase,
    required this.progress,
    this.done = false,
  });
}
