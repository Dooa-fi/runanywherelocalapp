import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:runanywhere/runanywhere.dart';

/// Handles PDF text extraction (native text or OCR) + LLM translation.
class DocumentService {
  // ── PDF Picking ────────────────────────────────────────────────────────────

  Future<File?> pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final path = result.files.single.path;
    if (path == null) return null;
    return File(path);
  }

  // ── Text Extraction ───────────────────────────────────────────────────────

  /// Extract text from each PDF page. Uses direct text extraction first;
  /// falls back to ML Kit OCR for scanned image pages.
  Future<List<PageContent>> extractPages(File pdfFile) async {
    final bytes = await pdfFile.readAsBytes();
    final pages = <PageContent>[];

    late PdfDocument document;
    try {
      document = PdfDocument(inputBytes: bytes);
    } catch (e) {
      return [PageContent(pageNumber: 1, text: '[Could not open PDF: $e]', isOcr: false)];
    }

    for (int i = 0; i < document.pages.count; i++) {
      final page = document.pages[i];

      // Try native text extraction first
      final extractor = PdfTextExtractor(document);
      String text = '';
      try {
        text = extractor.extractText(startPageIndex: i, endPageIndex: i).trim();
      } catch (_) {}

      if (text.length > 20) {
        // Native text found — use it directly
        pages.add(PageContent(pageNumber: i + 1, text: text, isOcr: false));
      } else {
        // Likely scanned — render page → image → OCR
        final ocrText = await _ocrPage(document, i, bytes);
        pages.add(PageContent(pageNumber: i + 1, text: ocrText, isOcr: true));
      }
    }

    document.dispose();
    return pages;
  }

  /// Renders a single PDF page to an image file and runs ML Kit OCR on it.
  Future<String> _ocrPage(PdfDocument document, int pageIndex, Uint8List pdfBytes) async {
    try {
      // Render the page to bitmap
      final page = document.pages[pageIndex];
      final image = page.convertToImage(
        width: 1200,
        height: (1200 * page.size.height / page.size.width).round(),
      );

      final dir = await getTemporaryDirectory();
      final imgPath = p.join(dir.path, 'page_${pageIndex}_${DateTime.now().millisecondsSinceEpoch}.png');
      await File(imgPath).writeAsBytes(image);

      // ML Kit text recognition
      final inputImage = InputImage.fromFilePath(imgPath);
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final recognized = await recognizer.processImage(inputImage);
      await recognizer.close();

      // Clean up temp image
      try { await File(imgPath).delete(); } catch (_) {}

      return recognized.text.trim().isEmpty
          ? '[No text detected on this page]'
          : recognized.text.trim();
    } catch (e) {
      return '[OCR error: $e]';
    }
  }

  // ── Translation ────────────────────────────────────────────────────────────

  static const int _chunkSize = 400; // characters per LLM call

  /// Translate [pages] to [targetLanguage] using on-device LLM.
  /// Yields translated text progressively as each chunk completes.
  Stream<TranslationProgress> translatePages(
    List<PageContent> pages,
    String targetLanguage,
  ) async* {
    for (int pi = 0; pi < pages.length; pi++) {
      final page = pages[pi];
      final chunks = _splitIntoChunks(page.text, _chunkSize);
      final translatedParts = <String>[];

      for (int ci = 0; ci < chunks.length; ci++) {
        final chunk = chunks[ci];
        final translated = await _translateChunk(chunk, targetLanguage);
        translatedParts.add(translated);

        yield TranslationProgress(
          pageIndex: pi,
          pageNumber: page.pageNumber,
          totalPages: pages.length,
          chunkIndex: ci,
          totalChunks: chunks.length,
          partialPageText: translatedParts.join(' '),
          isDone: false,
        );
      }

      yield TranslationProgress(
        pageIndex: pi,
        pageNumber: page.pageNumber,
        totalPages: pages.length,
        chunkIndex: chunks.length,
        totalChunks: chunks.length,
        partialPageText: translatedParts.join(' '),
        isDone: pi == pages.length - 1,
      );
    }
  }

  Future<String> _translateChunk(String text, String targetLanguage) async {
    if (text.trim().isEmpty) return '';
    final prompt = '''Translate the following text to $targetLanguage.
Output ONLY the translated text — no explanations, no notes.

TEXT:
$text

TRANSLATION:''';

    try {
      final result = await RunAnywhere.generate(
        prompt,
        options: LLMGenerationOptions(
          maxTokens: 512,
          temperature: 0.1,
          systemPrompt: 'You are a precise translator. Translate to $targetLanguage.',
        ),
      );
      return result.trim();
    } catch (e) {
      return '[translation error: $e]';
    }
  }

  List<String> _splitIntoChunks(String text, int size) {
    final chunks = <String>[];
    int start = 0;
    while (start < text.length) {
      int end = start + size;
      if (end < text.length) {
        // Try to break at sentence boundary
        final dot = text.lastIndexOf('.', end);
        final newline = text.lastIndexOf('\n', end);
        final boundary = [dot, newline].where((i) => i > start).fold(-1, (a, b) => b > a ? b : a);
        if (boundary > start) end = boundary + 1;
      } else {
        end = text.length;
      }
      chunks.add(text.substring(start, end).trim());
      start = end;
    }
    return chunks.where((c) => c.isNotEmpty).toList();
  }
}

// ── Data models ───────────────────────────────────────────────────────────────

class PageContent {
  final int pageNumber;
  final String text;
  final bool isOcr;

  const PageContent({
    required this.pageNumber,
    required this.text,
    required this.isOcr,
  });
}

class TranslationProgress {
  final int pageIndex;
  final int pageNumber;
  final int totalPages;
  final int chunkIndex;
  final int totalChunks;
  final String partialPageText;
  final bool isDone;

  const TranslationProgress({
    required this.pageIndex,
    required this.pageNumber,
    required this.totalPages,
    required this.chunkIndex,
    required this.totalChunks,
    required this.partialPageText,
    required this.isDone,
  });

  double get overallProgress {
    if (totalPages == 0) return 0;
    return (pageIndex + (totalChunks == 0 ? 1.0 : chunkIndex / totalChunks)) / totalPages;
  }
}
