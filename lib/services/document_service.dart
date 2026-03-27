import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class DocumentService {
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
      final extractor = PdfTextExtractor(document);
      String text = '';
      try {
        text = extractor.extractText(startPageIndex: i, endPageIndex: i).trim();
      } catch (_) {}

      if (text.length > 20) {
        pages.add(PageContent(pageNumber: i + 1, text: text, isOcr: false));
      } else {
        pages.add(PageContent(
          pageNumber: i + 1,
          text: text.isNotEmpty
              ? text
              : '[Page ${i + 1} appears to be a scanned image. OCR support for scanned documents will be added later.]',
          isOcr: true,
        ));
      }
    }

    document.dispose();
    return pages;
  }

  static const int _chunkSize = 1000; 

  Stream<TranslationProgress> translatePages(
    List<PageContent> pages,
    String targetLangStr,
    {required CancellationFlag cancelFlag}
  ) async* {
    TranslateLanguage targetLanguage = TranslateLanguage.english;
    if (targetLangStr.toLowerCase().contains('hi')) targetLanguage = TranslateLanguage.hindi;
    if (targetLangStr.toLowerCase().contains('es') || targetLangStr.toLowerCase().contains('spanish')) targetLanguage = TranslateLanguage.spanish;

    final translator = OnDeviceTranslator(
      sourceLanguage: TranslateLanguage.english,
      targetLanguage: targetLanguage,
    );

    for (int pi = 0; pi < pages.length; pi++) {
      if (cancelFlag.isCancelled) break;
      
      final page = pages[pi];

      if (page.text.startsWith('[Page ')) {
        yield TranslationProgress(
          pageIndex: pi, pageNumber: page.pageNumber, totalPages: pages.length,
          chunkIndex: 1, totalChunks: 1, partialPageText: page.text, isDone: pi == pages.length - 1,
        );
        continue;
      }

      final chunks = _splitIntoChunks(page.text, _chunkSize);
      final translatedParts = <String>[];

      for (int ci = 0; ci < chunks.length; ci++) {
        if (cancelFlag.isCancelled) break;
        
        final chunk = chunks[ci];
        final translated = await translator.translateText(chunk);

        translatedParts.add(translated);

        yield TranslationProgress(
          pageIndex: pi, pageNumber: page.pageNumber, totalPages: pages.length,
          chunkIndex: ci + 1, totalChunks: chunks.length,
          partialPageText: translatedParts.join(' '), isDone: false,
        );
      }

      if (cancelFlag.isCancelled) break;
      
      yield TranslationProgress(
        pageIndex: pi, pageNumber: page.pageNumber, totalPages: pages.length,
        chunkIndex: chunks.length, totalChunks: chunks.length,
        partialPageText: translatedParts.join(' '), isDone: pi == pages.length - 1,
      );
    }
    
    translator.close();
  }

  List<String> _splitIntoChunks(String text, int size) {
    final chunks = <String>[];
    int start = 0;
    while (start < text.length) {
      int end = start + size;
      if (end < text.length) {
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

class CancellationFlag {
  bool isCancelled = false;
  void cancel() {
    isCancelled = true;
  }
}

class PageContent {
  final int pageNumber;
  final String text;
  final bool isOcr;
  const PageContent({required this.pageNumber, required this.text, required this.isOcr});
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
    required this.pageIndex, required this.pageNumber, required this.totalPages,
    required this.chunkIndex, required this.totalChunks, required this.partialPageText, required this.isDone,
  });
  double get overallProgress {
    if (totalPages == 0) return 0;
    return (pageIndex + (totalChunks == 0 ? 1.0 : chunkIndex / totalChunks)) / totalPages;
  }
}
