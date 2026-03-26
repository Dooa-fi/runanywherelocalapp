# RunAnywhere Offline Copilot

> **Hackathon MVP** — 100% on-device AI. No cloud. No backend. Works offline.

A Flutter mobile app demonstrating **on-device AI** for two real-world use-cases:

| Feature | Technology |
|---|---|
| 🎤 Meeting Notes (Record → Transcribe → Summarize) | RunAnywhere STT (Whisper) + LLM (SmolLM2) |
| 📄 Document Translator (PDF → OCR → Translate) | SyncFusion PDF + ML Kit OCR + RunAnywhere LLM |

---

## 📱 Screenshots / Flow

```
App Launch
  └─ Model Setup Screen (downloads AI models ~375 MB once)
        └─ Home (2 tabs)
              ├─ Tab 1: Meeting Notes
              │    ├─ [Start Recording]  → mic → PCM16 audio
              │    ├─ [Stop Recording]   → Whisper STT → transcript
              │    └─ LLM streaming     → Summary + Key Points + Action Items
              │         └─ [Play Summary] → TTS (Piper Amy)
              │
              └─ Tab 2: Document Translator
                   ├─ Language selector (10 languages)
                   ├─ [Pick PDF]         → SyncFusion text extraction
                   │                      or ML Kit OCR (scanned pages)
                   ├─ Progress bar       → chunk-by-chunk LLM translation
                   ├─ Page navigator     → view translated pages
                   └─ [Export as Text]   → share translated .txt
```

---

## ⚙️ AI Models Used

| Model | Size | Purpose |
|---|---|---|
| `whisper-tiny.en` (ONNX) | ~75 MB | Speech-to-Text |
| `piper-en_US-amy-medium` (ONNX) | ~50 MB | Text-to-Speech |
| `SmolLM2-360M-Instruct-Q4_K_M` (GGUF) | ~250 MB | Summarization + Translation |

**Total first-run download: ~375 MB** (cached permanently on device).

---

## 🚀 Getting Started

### Prerequisites

- Flutter 3.10+ with Dart 3.0+
- Android device/emulator: API 24+ (Android 7.0)
- iOS device/simulator: iOS 14.0+
- Android NDK (installed via Android Studio)

### 1. Clone & Install

```bash
git clone <repo-url>
cd runanywhere_copilot
flutter pub get
```

### 2. iOS: Install Pods

```bash
cd ios
pod install
cd ..
```

> ⚠️ iOS requires CocoaPods and Xcode installed.

### 3. Run

```bash
# Android
flutter run

# iOS (needs connected device or simulator)
flutter run -d <device-id>
```

### 4. First Launch

On first launch, tap **"Download AI Models & Start"**. The app will download ~375 MB of AI models (Whisper + Piper TTS + SmolLM2). This is a one-time download; subsequent launches load from cache instantly.

---

## 📁 Project Structure

```
lib/
├── main.dart                    # SDK init (RunAnywhere + backends)
├── theme/
│   └── app_theme.dart           # Dark theme (navy + cyan)
├── services/
│   ├── model_manager.dart       # Model registry + download stream
│   ├── audio_service.dart       # Recording + STT + LLM + TTS
│   └── document_service.dart    # PDF extraction + OCR + translation
└── screens/
    ├── home_screen.dart         # 2-tab scaffold
    ├── model_setup_screen.dart  # First-run model downloader
    ├── meeting_notes_screen.dart# Tab 1: record → transcribe → summarize
    └── doc_translator_screen.dart # Tab 2: PDF → translate
```

---

## 🔒 Privacy

- **No data leaves the device.** All audio, text, and documents are processed entirely on-device.
- Models are downloaded once from GitHub/HuggingFace and cached locally.
- No analytics, no telemetry, no backend.

---

## ⚠️ Known MVP Limitations

- Translation quality depends on SmolLM2 (small model — good for demo, not production)
- OCR accuracy depends on scan quality
- STT may struggle with heavy accents or background noise
- Processing takes 1–10 seconds per chunk depending on device hardware
- iOS build requires Mac + Xcode + CocoaPods

---

## 🧩 Dependencies

| Package | Purpose |
|---|---|
| `runanywhere` | Core on-device AI SDK |
| `runanywhere_onnx` | STT (Whisper) + TTS (Piper) + VAD |
| `runanywhere_llamacpp` | LLM (SmolLM2 via llama.cpp) |
| `record` | Microphone recording (WAV PCM16) |
| `audioplayers` | TTS playback |
| `file_picker` | PDF file selection |
| `syncfusion_flutter_pdf` | Native PDF text extraction |
| `google_mlkit_text_recognition` | OCR for scanned PDFs |
| `permission_handler` | Microphone permissions |
| `flutter_markdown` | Markdown rendering for summaries |
| `share_plus` | Export translated text |

---

## 🏁 Hackathon Notes

This is an MVP. For production you would:
- Add session persistence (save transcripts / translations to SQLite)
- Support more languages with multilingual Whisper
- Use a larger LLM (Qwen-1.5B or Phi-3-mini) for better translation quality
- Add VAD-based live streaming transcription
- Implement proper error recovery and retry logic
