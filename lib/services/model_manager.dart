import 'package:runanywhere/runanywhere.dart';
import 'package:runanywhere_onnx/runanywhere_onnx.dart';
import 'package:runanywhere_llamacpp/runanywhere_llamacpp.dart';

/// Central place to register & manage all AI models.
/// Model IDs and URLs match the official RunAnywhere starter example.
class ModelManager {
  // ── Model IDs (must match official SDK model registry) ────────────────────
  static const String sttModelId = 'sherpa-onnx-whisper-tiny.en';
  static const String llmModelId = 'smollm2-360m-instruct-q8_0';
  static const String ttsModelId = 'vits-piper-en_US-lessac-medium';

  /// Register all models with their backends. Call once after SDK init.
  static void registerModels() {
    // ── STT: Whisper Tiny English ──────────────────────────────────────────
    Onnx.addModel(
      id: sttModelId,
      name: 'Sherpa Whisper Tiny (ONNX)',
      url: 'https://github.com/RunanywhereAI/sherpa-onnx/releases/download/'
          'runanywhere-models-v1/sherpa-onnx-whisper-tiny.en.tar.gz',
      modality: ModelCategory.speechRecognition,
    );

    // ── TTS: Piper Lessac Medium ──────────────────────────────────────────
    Onnx.addModel(
      id: ttsModelId,
      name: 'Piper TTS (US English - Medium)',
      url: 'https://github.com/RunanywhereAI/sherpa-onnx/releases/download/'
          'runanywhere-models-v1/vits-piper-en_US-lessac-medium.tar.gz',
      modality: ModelCategory.speechSynthesis,
    );

    // ── LLM: SmolLM2 360M Q8 ─────────────────────────────────────────────
    LlamaCpp.addModel(
      id: llmModelId,
      name: 'SmolLM2 360M Instruct Q8_0',
      url: 'https://huggingface.co/HuggingFaceTB/SmolLM2-360M-Instruct-GGUF/'
          'resolve/main/smollm2-360m-instruct-q8_0.gguf',
      memoryRequirement: 400000000, // ~400 MB
    );
  }

  // ── State helpers ─────────────────────────────────────────────────────────
  static bool get sttReady => RunAnywhere.isSTTModelLoaded;
  static bool get ttsReady => RunAnywhere.isTTSVoiceLoaded;
  static bool get llmReady => RunAnywhere.isModelLoaded;

  /// Check if a specific model has been downloaded already.
  static Future<bool> isModelDownloaded(String modelId) async {
    final models = await RunAnywhere.availableModels();
    final model = models.where((m) => m.id == modelId).firstOrNull;
    return model?.localPath != null;
  }

  // ── Download + load all models ────────────────────────────────────────────

  /// Downloads and loads STT, LLM, and optionally TTS.
  /// Yields [ModelLoadEvent] for UI progress tracking.
  /// TTS failure is non-fatal — the rest of the app still works.
  static Stream<ModelLoadEvent> loadAll() async* {
    // ── 1. STT ──────────────────────────────────────────────────────────────
    yield ModelLoadEvent(model: 'STT', phase: 'Checking STT model…', progress: 0);
    final sttDownloaded = await isModelDownloaded(sttModelId);

    if (!sttDownloaded) {
      yield ModelLoadEvent(model: 'STT', phase: 'Downloading Whisper…', progress: 0);
      try {
        await for (final p in RunAnywhere.downloadModel(sttModelId)) {
          yield ModelLoadEvent(
            model: 'STT', phase: 'Downloading Whisper…', progress: p.percentage,
          );
          if (p.state.isCompleted || p.state.isFailed) break;
        }
      } catch (e) {
        yield ModelLoadEvent(model: 'STT', phase: 'STT download error: $e', progress: 0);
        rethrow;
      }
    }

    yield ModelLoadEvent(model: 'STT', phase: 'Loading Whisper…', progress: 1.0);
    try {
      await RunAnywhere.loadSTTModel(sttModelId);
    } catch (e) {
      yield ModelLoadEvent(model: 'STT', phase: 'STT load error: $e', progress: 0);
      rethrow;
    }

    // ── 2. LLM ──────────────────────────────────────────────────────────────
    yield ModelLoadEvent(model: 'LLM', phase: 'Checking LLM model…', progress: 0);
    final llmDownloaded = await isModelDownloaded(llmModelId);

    if (!llmDownloaded) {
      yield ModelLoadEvent(model: 'LLM', phase: 'Downloading SmolLM2…', progress: 0);
      try {
        await for (final p in RunAnywhere.downloadModel(llmModelId)) {
          yield ModelLoadEvent(
            model: 'LLM', phase: 'Downloading SmolLM2…', progress: p.percentage,
          );
          if (p.state.isCompleted || p.state.isFailed) break;
        }
      } catch (e) {
        yield ModelLoadEvent(model: 'LLM', phase: 'LLM download error: $e', progress: 0);
        rethrow;
      }
    }

    yield ModelLoadEvent(model: 'LLM', phase: 'Loading SmolLM2…', progress: 1.0);
    try {
      await RunAnywhere.loadModel(llmModelId);
    } catch (e) {
      yield ModelLoadEvent(model: 'LLM', phase: 'LLM load error: $e', progress: 0);
      rethrow;
    }

    // ── 3. TTS (optional — failure is non-fatal) ────────────────────────────
    yield ModelLoadEvent(model: 'TTS', phase: 'Checking TTS model…', progress: 0);
    try {
      final ttsDownloaded = await isModelDownloaded(ttsModelId);

      if (!ttsDownloaded) {
        yield ModelLoadEvent(model: 'TTS', phase: 'Downloading TTS voice…', progress: 0);
        await for (final p in RunAnywhere.downloadModel(ttsModelId)) {
          yield ModelLoadEvent(
            model: 'TTS', phase: 'Downloading TTS voice…', progress: p.percentage,
          );
          if (p.state.isCompleted || p.state.isFailed) break;
        }
      }

      yield ModelLoadEvent(model: 'TTS', phase: 'Loading TTS voice…', progress: 1.0);
      await RunAnywhere.loadTTSVoice(ttsModelId);
    } catch (e) {
      // TTS failure is non-fatal — app works fine without it
      yield ModelLoadEvent(model: 'TTS', phase: 'TTS skipped (optional): $e', progress: 1.0);
    }

    yield ModelLoadEvent(
      model: 'ALL', phase: 'All models ready!', progress: 1.0, done: true,
    );
  }
}

// ── Event class ──────────────────────────────────────────────────────────────

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

// ── Extension from official RunAnywhere starter ──────────────────────────────

extension DownloadProgressStateExt on DownloadProgressState {
  bool get isCompleted => this == DownloadProgressState.completed;
  bool get isFailed => this == DownloadProgressState.failed;
  bool get isCancelled => this == DownloadProgressState.cancelled;
}
