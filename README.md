# Offline Copilot

[⬇️ **Download Latest APK (Google Drive)**](https://drive.google.com/file/d/1vBt1ZOCoaBF30J8Cj6qH--s5Xl8pNF89/view?usp=sharing)

Offline Copilot is a privacy-first, fully offline AI assistant built with Flutter. It utilizes on-device machine learning models to provide real-time speech-to-text transcription and document translation without relying on cloud services or active internet connections.

## Core Features

- **Meeting Notes**: Continuous offline speech recognition using Vosk for generating real-time meeting transcripts.
- **Document Translator**: On-device PDF text extraction and offline translation utilizing Google ML Kit.
- **Live Conversation**: Split-screen dual-microphone interface facilitating real-time translated conversations.

## Architecture & Technology Stack

- **Framework**: Flutter / Dart
- **Speech-to-Text Engine**: Vosk (Offline Streaming PCM Audio Processing)
- **Translation Engine**: Google ML Kit (Offline Neural Machine Translation)
- **Supported Languages**: English, Hindi, Spanish (expandable via model configuration)

The application handles extreme cases such as prolonged recording sessions by processing the raw PCM audio byte stream sequentially through the Vosk recognizer isolate, ensuring minimal memory footprint and zero cloud data leaks.

## Build Instructions (Android)

Ensure you have the Flutter SDK installed and environment variables configured.

1. Install dependencies:
   ```bash
   flutter pub get
   ```

2. Build the release APK:
   ```bash
   flutter build apk --release
   ```

The compiled Android application requires a minimum SDK version of 24 and targets SDK version 36. Upon the initial launch, the application will download the required acoustic language models directly to the application's local document directory. Subsequent launches load these models instantly from local storage.
