import 'dart:io';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:runanywhere/runanywhere.dart';

/// Manages audio recording + STT transcription using RunAnywhere SDK.
class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  String? _recordingPath;

  // ── Permissions ────────────────────────────────────────────────────────────

  Future<bool> requestMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  // ── Recording lifecycle ────────────────────────────────────────────────────

  /// Start capturing audio. Returns [false] if permission denied.
  Future<bool> startRecording() async {
    if (!await requestMicPermission()) return false;

    final dir = await getTemporaryDirectory();
    _recordingPath = p.join(
      dir.path,
      'rec_${DateTime.now().millisecondsSinceEpoch}.wav',
    );

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav, // raw PCM16 wrapped in WAV
        sampleRate: 16000,         // Whisper expects 16 kHz
        numChannels: 1,            // mono
      ),
      path: _recordingPath!,
    );
    return true;
  }

  /// Stop recording and return raw PCM16 bytes ready for Whisper.
  Future<Uint8List?> stopRecordingAndGetPcm() async {
    final path = await _recorder.stop();
    if (path == null) return null;

    final file = File(path);
    if (!file.existsSync()) return null;

    final bytes = await file.readAsBytes();

    // WAV header = 44 bytes; strip it to expose raw PCM16 payload
    return bytes.length > 44 ? bytes.sublist(44) : bytes;
  }

  Future<bool> get isRecording => _recorder.isRecording();

  // ── Transcription ──────────────────────────────────────────────────────────

  /// Transcribe PCM16 bytes using RunAnywhere Whisper STT.
  Future<String> transcribe(Uint8List pcmBytes) async {
    try {
      final result = await RunAnywhere.transcribe(pcmBytes);
      // SDK returns an object with .text property
      return result.text ?? '';
    } catch (e) {
      return '[transcription error: $e]';
    }
  }

  // ── LLM helpers ───────────────────────────────────────────────────────────

  /// Stream meeting summary + key points + action items from the transcript.
  Stream<String> summarizeMeeting(String transcript) {
    final prompt = '''You are a professional meeting assistant.

Below is a raw meeting transcript. Produce a concise structured report in Markdown with exactly these three sections:

## Summary
A 3-5 sentence overview of what was discussed.

## Key Points
- Bullet-point list of the most important topics covered.

## Action Items
- Bullet-point list of concrete next steps with owner names if mentioned.

TRANSCRIPT:
---
$transcript
---

Output only the Markdown report, nothing else.''';

    return _streamLLM(prompt);
  }

  Stream<String> _streamLLM(String prompt) async* {
    try {
      final result = await RunAnywhere.generateStream(
        prompt,
        options: const LLMGenerationOptions(
          maxTokens: 600,
          temperature: 0.3,
        ),
      );
      await for (final token in result.stream) {
        yield token;
      }
    } catch (e) {
      yield '\n\n[LLM error: $e]';
    }
  }

  // ── TTS ───────────────────────────────────────────────────────────────────

  /// Synthesize [text] and write WAV bytes to a temp file. Returns file path.
  Future<String?> synthesizeSpeech(String text) async {
    try {
      final result = await RunAnywhere.synthesize(text, rate: 1.0, pitch: 1.0);
      final dir = await getTemporaryDirectory();
      final wavPath = p.join(dir.path, 'tts_${DateTime.now().millisecondsSinceEpoch}.wav');
      final wavBytes = _samplesToWav(result.samples, result.sampleRate);
      await File(wavPath).writeAsBytes(wavBytes);
      return wavPath;
    } catch (e) {
      return null;
    }
  }

  /// Convert raw float32 samples → 16-bit PCM WAV bytes.
  Uint8List _samplesToWav(List<double> samples, int sampleRate) {
    final pcm16 = Int16List(samples.length);
    for (int i = 0; i < samples.length; i++) {
      pcm16[i] = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    }
    final pcmBytes = pcm16.buffer.asUint8List();
    final dataSize = pcmBytes.length;
    final header = ByteData(44);

    // RIFF header
    header.setUint8(0, 0x52); header.setUint8(1, 0x49);
    header.setUint8(2, 0x46); header.setUint8(3, 0x46); // "RIFF"
    header.setUint32(4, 36 + dataSize, Endian.little);
    header.setUint8(8, 0x57); header.setUint8(9, 0x41);
    header.setUint8(10, 0x56); header.setUint8(11, 0x45); // "WAVE"
    // fmt chunk
    header.setUint8(12, 0x66); header.setUint8(13, 0x6D);
    header.setUint8(14, 0x74); header.setUint8(15, 0x20); // "fmt "
    header.setUint32(16, 16, Endian.little);  // chunk size
    header.setUint16(20, 1, Endian.little);   // PCM
    header.setUint16(22, 1, Endian.little);   // mono
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    header.setUint16(32, 2, Endian.little);   // block align
    header.setUint16(34, 16, Endian.little);  // bits per sample
    // data chunk
    header.setUint8(36, 0x64); header.setUint8(37, 0x61);
    header.setUint8(38, 0x74); header.setUint8(39, 0x61); // "data"
    header.setUint32(40, dataSize, Endian.little);

    final wavBytes = Uint8List(44 + dataSize);
    wavBytes.setRange(0, 44, header.buffer.asUint8List());
    wavBytes.setRange(44, 44 + dataSize, pcmBytes);
    return wavBytes;
  }

  void dispose() {
    _recorder.dispose();
  }
}
