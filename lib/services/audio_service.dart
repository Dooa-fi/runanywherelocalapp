import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vosk_flutter/vosk_flutter.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'model_manager.dart';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _micSub;
  
  Model? _voskModel;
  Recognizer? _recognizer;
  
  String _bufferedTranscript = '';
  final _transcriptStreamController = StreamController<String>.broadcast();

  final Map<String, OnDeviceTranslator> _translators = {};

  Future<bool> requestMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  // ── Recording & Vosk STT ──────────────────────────────────────────────────

  /// Starts streaming mic audio into Vosk
  Future<bool> startStreamingSTT(String detectLang) async {
    if (!await requestMicPermission()) return false;
    
    _bufferedTranscript = '';
    
    // Convert 'Hindi' to 'hi' to match paths
    String langCode = 'en';
    if (detectLang.toLowerCase().contains('hi')) langCode = 'hi';
    if (detectLang.toLowerCase().contains('spanish') || detectLang.toLowerCase().contains('es')) langCode = 'es';

    try {
      final modelPath = ModelManager.voskPaths[langCode];
      if (modelPath == null) throw Exception('Vosk model for $langCode not loaded');
      
      _voskModel = await ModelManager.voskPlugin.createModel(modelPath);
      _recognizer = await ModelManager.voskPlugin.createRecognizer(model: _voskModel!, sampleRate: 16000);

      final stream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ));

      _micSub = stream.listen((data) async {
        if (_recognizer == null) return;
        
        final isFinal = await _recognizer!.acceptWaveformBytes(data);
        if (isFinal) {
          final resultString = await _recognizer!.getResult();
          final parsed = jsonDecode(resultString);
          final text = parsed['text'] as String? ?? '';
          if (text.isNotEmpty) {
            _bufferedTranscript += '$text ';
            _transcriptStreamController.add(_bufferedTranscript);
          }
        }
      });
      return true;
    } catch(e) {
      debugPrint('Vosk Start Error: $e');
      return false;
    }
  }

  Stream<String> get transcriptStream => _transcriptStreamController.stream;

  Future<String> stopStreamingSTT() async {
    await _micSub?.cancel();
    await _recorder.stop();
    
    if (_recognizer != null) {
      final res = await _recognizer!.getFinalResult();
      final parsed = jsonDecode(res);
      final text = parsed['text'] as String? ?? '';
      if (text.isNotEmpty) {
        _bufferedTranscript += text;
      }
      _recognizer!.dispose();
      _recognizer = null;
    }
    
    if (_voskModel != null) {
      _voskModel!.dispose();
      _voskModel = null;
    }
    
    return _bufferedTranscript.trim();
  }

  // ── Translation (ML Kit) ──────────────────────────────────────────────────

  /// Uses ML Kit to instantly translate offline
  Future<String> translateOffline(String text, String sourceLang, String targetLang) async {
    if (text.trim().isEmpty) return '';

    TranslateLanguage parseLang(String l) {
      l = l.toLowerCase();
      if (l.contains('hi')) return TranslateLanguage.hindi;
      if (l.contains('spanish') || l.contains('es')) return TranslateLanguage.spanish;
      return TranslateLanguage.english;
    }

    final source = parseLang(sourceLang);
    final target = parseLang(targetLang);
    final cacheKey = '${source.bcpCode}_${target.bcpCode}';

    if (!_translators.containsKey(cacheKey)) {
      _translators[cacheKey] = OnDeviceTranslator(sourceLanguage: source, targetLanguage: target);
    }

    try {
      final translator = _translators[cacheKey]!;
      // run in isolate to keep main thread completely unblocked
      final translated = await compute((params) {
        return params.$1.translateText(params.$2);
      }, (translator, text));
      return translated;
    } catch (e) {
      return '[Translation Error: $e]';
    }
  }

  void dispose() {
    _recorder.dispose();
    _micSub?.cancel();
    _recognizer?.dispose();
    _voskModel?.dispose();
    _transcriptStreamController.close();
    for (var t in _translators.values) {
      t.close();
    }
  }
}
