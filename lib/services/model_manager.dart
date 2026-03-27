import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:vosk_flutter/vosk_flutter.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:path/path.dart' as p;

class ModelLoadEvent {
  final String model;
  final String phase;
  final double progress;
  final bool done;
  const ModelLoadEvent({required this.model, required this.phase, required this.progress, this.done = false});
}

class ModelManager {
  static const Map<String, String> voskUrls = {
    'en': 'https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip',
    'hi': 'https://alphacephei.com/vosk/models/vosk-model-small-hi-0.22.zip',
    'es': 'https://alphacephei.com/vosk/models/vosk-model-small-es-0.42.zip',
  };

  static final Map<String, String> voskPaths = {};
  static late final VoskFlutterPlugin voskPlugin;

  static bool sttReady = false;
  static bool translationReady = false;

  /// Loads/Downloads Vosk models and MLKit models
  static Stream<ModelLoadEvent> loadAll() async* {
    sttReady = false;
    translationReady = false;
    
    // 1. Setup Vosk STT Models
    voskPlugin = VoskFlutterPlugin.instance();
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory(p.join(appDir.path, 'vosk_models'));
    if (!modelsDir.existsSync()) modelsDir.createSync(recursive: true);

    for (final entry in voskUrls.entries) {
      final lang = entry.key;
      final url = entry.value;
      final zipName = p.basename(url);
      final modelFolderName = zipName.replaceAll('.zip', '');
      final currentModelDir = Directory(p.join(modelsDir.path, modelFolderName));

      if (!currentModelDir.existsSync()) {
        yield ModelLoadEvent(model: 'Vosk ($lang)', phase: 'Downloading STT ($lang)...', progress: 0.1);
        
        final zipFile = File(p.join(modelsDir.path, zipName));
        final response = await http.get(Uri.parse(url));
        await zipFile.writeAsBytes(response.bodyBytes);
        
        yield ModelLoadEvent(model: 'Vosk ($lang)', phase: 'Extracting STT ($lang)...', progress: 0.5);
        final bytes = zipFile.readAsBytesSync();
        final archive = ZipDecoder().decodeBytes(bytes);
        
        for (final file in archive) {
          final filename = file.name;
          if (file.isFile) {
            final data = file.content as List<int>;
            File(p.join(modelsDir.path, filename))
              ..createSync(recursive: true)
              ..writeAsBytesSync(data);
          } else {
            Directory(p.join(modelsDir.path, filename)).createSync(recursive: true);
          }
        }
        zipFile.deleteSync();
      }
      
      voskPaths[lang] = currentModelDir.path;
      yield ModelLoadEvent(model: 'Vosk ($lang)', phase: 'Loaded STT ($lang)', progress: 1.0);
    }
    
    sttReady = true;

    // 2. Setup Translation Models
    yield ModelLoadEvent(model: 'Translation', phase: 'Checking Translation Models...', progress: 0.0);
    final modelManager = OnDeviceTranslatorModelManager();
    
    yield ModelLoadEvent(model: 'Translation', phase: 'Checking Hindi translation pack...', progress: 0.3);
    final isHiDownloaded = await modelManager.isModelDownloaded(TranslateLanguage.hindi.bcpCode);
    if (!isHiDownloaded) {
      await modelManager.downloadModel(TranslateLanguage.hindi.bcpCode);
    }
    
    yield ModelLoadEvent(model: 'Translation', phase: 'Checking Spanish translation pack...', progress: 0.6);
    final isEsDownloaded = await modelManager.isModelDownloaded(TranslateLanguage.spanish.bcpCode);
    if (!isEsDownloaded) {
      await modelManager.downloadModel(TranslateLanguage.spanish.bcpCode);
    }
    
    translationReady = true;

    yield ModelLoadEvent(model: 'ALL', phase: 'All models ready!', progress: 1.0, done: true);
  }
}
