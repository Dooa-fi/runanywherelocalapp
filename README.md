# Offline Copilot

[⬇️ Download APK (Google Drive)](https://drive.google.com/file/d/1vBt1ZOCoaBF30J8Cj6qH--s5Xl8pNF89/view?usp=sharing)

Your phone is a full AI workstation — no internet required. Offline Copilot is a Flutter app that puts speech recognition and language translation entirely on-device. No API keys. No subscriptions. No data leaving your phone.

---

## What it does

**Meeting Notes**  
Hit record, start talking. The app transcribes in real time using Vosk — an open-source offline speech engine. When you're done, you have a timestamped, selectable transcript sitting on your device. Works in a basement, a flight, a conference room with no signal.

**Document Translator**  
Pick any PDF. The app pulls the text out and translates it offline using Google ML Kit's neural machine translation. No uploading documents to some cloud API — the whole pipeline runs locally.

**Live Conversation**  
Two microphones, two languages, one screen. Person A speaks English, Person B speaks Hindi — each side transcribes and translates the other automatically. Built for situations where two people literally don't share a language.

---

## Languages supported

English · Hindi · Spanish *(more can be added via model config)*

---

## How it works

On first launch, the app downloads ~375 MB of AI models — the Vosk acoustic model for speech recognition and the ML Kit translation packs. After that, everything runs locally. Cold boot after the first setup is instant since models are cached in the app's document directory.

The audio pipeline streams raw PCM directly into Vosk's recognizer, so transcription happens word-by-word as you speak instead of waiting for you to stop talking. Memory footprint stays low even on hour-long recordings.

---

## Tech stack

| Layer | What's used |
|---|---|
| Framework | Flutter / Dart |
| Speech-to-Text | Vosk (offline streaming) |
| Translation | Google ML Kit (offline NMT) |
| PDF extraction | Syncfusion Flutter PDF |
| Audio recording | `record` package (PCM stream) |

---

## Building from source

You need Flutter SDK installed and your environment set up for Android.

```bash
# Install dependencies
flutter pub get

# Run in debug mode
flutter run

# Build release APK
flutter build apk --release
```

**Minimum Android SDK:** 24  
**Target SDK:** 36

CI is set up with GitHub Actions — every push to main builds and artifacts the APK automatically.

---

## First launch

The setup screen walks you through downloading the models. Keep the app open and on a decent connection — it's a one-time 375 MB download. After that you can go fully offline forever.

---

## Privacy

Nothing leaves your device. Ever. There are no analytics, no crash reporters phoning home, no API calls to any server after the initial model download. The "Offline" badge in the top bar isn't a marketing claim — it's literally the app's operating mode.

---

## Project structure

```
lib/
  main.dart                     # Entry point
  screens/
    home_screen.dart            # Tab navigation + model gate
    model_setup_screen.dart     # First-launch model downloader
    meeting_notes_screen.dart   # Transcription UI
    doc_translator_screen.dart  # PDF pick + translate UI
    conversation_screen.dart    # Dual-mic live translator
  services/
    audio_service.dart          # Vosk STT + ML Kit translation
    document_service.dart       # PDF extraction
    model_manager.dart          # Model download + caching
  theme/
    app_theme.dart              # Dark theme + color system
```
