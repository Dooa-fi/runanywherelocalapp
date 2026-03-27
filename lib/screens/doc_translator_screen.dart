import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../services/document_service.dart';
import '../theme/app_theme.dart';

enum _DocState { idle, extracting, translating, done, error }

class DocTranslatorScreen extends StatefulWidget {
  const DocTranslatorScreen({super.key});

  @override
  State<DocTranslatorScreen> createState() => _DocTranslatorScreenState();
}

class _DocTranslatorScreenState extends State<DocTranslatorScreen> {
  final DocumentService _docService = DocumentService();
  CancellationFlag? _cancelFlag;

  _DocState _state = _DocState.idle;
  String _statusMsg = '';
  double _progress = 0;

  List<PageContent> _extractedPages = [];
  // pageIndex → translated text so far
  final Map<int, String> _translated = {};
  int _currentPageIndex = 0;
  int _viewPageIndex = 0;

  // Language selection
  String _targetLang = 'Hindi';
  final _languages = [
    'English', 'Hindi', 'Spanish', 'French', 'German', 'Portuguese', 'Italian',
    'Russian', 'Japanese', 'Korean', 'Chinese (Simplified)', 'Arabic',
  ];

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _pickAndTranslate() async {
    final file = await _docService.pickPdf();
    if (file == null) return;

    _cancelFlag = CancellationFlag();

    setState(() {
      _state = _DocState.extracting;
      _statusMsg = 'Extracting text from PDF…';
      _progress = 0;
      _extractedPages = [];
      _translated.clear();
      _viewPageIndex = 0;
      _currentPageIndex = 0;
    });

    final pages = await _docService.extractPages(file);
    if (pages.isEmpty) {
      setState(() { _state = _DocState.error; _statusMsg = 'No text found in PDF'; });
      return;
    }

    if (_cancelFlag?.isCancelled ?? false) return;

    setState(() {
      _extractedPages = pages;
      _state = _DocState.translating;
      _statusMsg = 'Translating with SmolLM2…';
    });

    await for (final event in _docService.translatePages(pages, _targetLang, cancelFlag: _cancelFlag!)) {
      if (!mounted || (_cancelFlag?.isCancelled ?? false)) break;
      
      setState(() {
        _translated[event.pageIndex] = event.partialPageText;
        _currentPageIndex = event.pageIndex;
        _progress = event.overallProgress;
        _statusMsg = 'Page ${event.pageNumber}/${event.totalPages} '
            '(chunk ${event.chunkIndex}/${event.totalChunks})';
      });
      if (event.isDone) {
        setState(() { _state = _DocState.done; _statusMsg = 'Translation complete ✓'; });
      }
    }
  }

  void _stopTranslation() {
    _cancelFlag?.cancel();
    setState(() {
      _state = _DocState.done;
      _statusMsg = 'Translation stopped by user.';
    });
  }

  Future<void> _exportText() async {
    final buffer = StringBuffer();
    for (int i = 0; i < _extractedPages.length; i++) {
      buffer.writeln('=== Page ${_extractedPages[i].pageNumber} ===\n');
      buffer.writeln('--- ORIGINAL TEXT ---');
      buffer.writeln(_extractedPages[i].text);
      buffer.writeln('\n--- TRANSLATED TEXT ---');
      buffer.writeln(_translated[i] ?? '[not yet translated]');
      buffer.writeln();
    }
    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, 'translated_${DateTime.now().millisecondsSinceEpoch}.txt');
    await File(path).writeAsString(buffer.toString());
    await Share.shareXFiles([XFile(path)], subject: 'Translated Document');
  }

  void _reset() {
    _cancelFlag?.cancel();
    setState(() {
      _state = _DocState.idle;
      _extractedPages = [];
      _translated.clear();
      _statusMsg = '';
      _progress = 0;
      _viewPageIndex = 0;
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bgBase,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _SectionHeader(
                    icon: Icons.translate_rounded,
                    color: colors.accentSecondary,
                    title: 'Document Translator',
                    subtitle: 'PDF → Translate — 100% offline',
                  ),
                  const SizedBox(height: 24),

                  // Language selector
                  Row(
                    children: [
                      Expanded(
                        child: _LanguageSelector(
                          label: 'Source',
                          value: 'Auto-detect',
                          languages: const ['Auto-detect'],
                          onChanged: (v) {},
                          colors: colors,
                          enabled: false,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, color: colors.textSecondary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _LanguageSelector(
                          label: 'Target',
                          value: _targetLang,
                          languages: _languages,
                          onChanged: (v) => setState(() => _targetLang = v),
                          colors: colors,
                          enabled: _state == _DocState.idle || _state == _DocState.done,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Upload button
                  _UploadArea(
                    state: _state,
                    onTap: _state == _DocState.idle || _state == _DocState.done
                        ? _pickAndTranslate : null,
                    onReset: _reset,
                    colors: colors,
                  ),

                  // Progress & Cancel
                  if (_state == _DocState.extracting || _state == _DocState.translating) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _ProgressSection(
                            progress: _progress,
                            statusMsg: _statusMsg,
                            colors: colors,
                            pages: _extractedPages,
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          onPressed: _stopTranslation,
                          style: IconButton.styleFrom(
                            backgroundColor: colors.error.withOpacity(0.1),
                            foregroundColor: colors.error,
                          ),
                          icon: const Icon(Icons.stop_rounded),
                          tooltip: 'Stop Translation',
                        ),
                      ],
                    ),
                  ],

                  // Status message (done/error)
                  if (_statusMsg.isNotEmpty &&
                      (_state == _DocState.done || _state == _DocState.error)) ...[
                    const SizedBox(height: 16),
                    _StatusChip(
                      message: _statusMsg,
                      isError: _state == _DocState.error,
                      colors: colors,
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Translated pages view
                  if (_translated.isNotEmpty || _extractedPages.isNotEmpty) ...[
                    _PageNavBar(
                      pages: _extractedPages,
                      currentIndex: _viewPageIndex,
                      translatedKeys: _translated.keys.toSet(),
                      onSelect: (i) => setState(() => _viewPageIndex = i),
                      colors: colors,
                    ),
                    const SizedBox(height: 14),
                    _TranslatedPageView(
                      pageContent: _extractedPages[_viewPageIndex],
                      translatedText: _translated[_viewPageIndex],
                      targetLang: _targetLang,
                      colors: colors,
                    ),
                  ],

                  // Export button
                  if (_state == _DocState.done) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _exportText,
                      icon: const Icon(Icons.ios_share_rounded),
                      label: const Text('Export as Text'),
                    ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Subwidgets ─────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _SectionHeader({required this.icon, required this.color, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(children: [
      Container(
        width: 48, height: 48,
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 24),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          Text(subtitle, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
        ],
      )),
    ]);
  }
}

class _LanguageSelector extends StatelessWidget {
  final String label;
  final String value;
  final List<String> languages;
  final ValueChanged<String> onChanged;
  final AppColors colors;
  final bool enabled;

  const _LanguageSelector({
    required this.label, required this.value, required this.languages, required this.onChanged,
    required this.colors, required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: colors.bgCard,
              style: TextStyle(color: enabled ? colors.textPrimary : colors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13),
              onChanged: enabled ? (v) => onChanged(v!) : null,
              items: languages.map((l) => DropdownMenuItem(value: l, child: Text(l, overflow: TextOverflow.ellipsis))).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// UploadArea, ProgressSection, StatusChip, PageNavBar kept intact
class _UploadArea extends StatelessWidget {
  final _DocState state;
  final VoidCallback? onTap;
  final VoidCallback onReset;
  final AppColors colors;

  const _UploadArea({required this.state, this.onTap, required this.onReset, required this.colors});

  @override
  Widget build(BuildContext context) {
    final isActive = state == _DocState.idle || state == _DocState.done;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 110,
        decoration: BoxDecoration(
          color: colors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? colors.accentSecondary.withOpacity(0.6) : const Color(0xFF30363D),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(
            state == _DocState.done ? Icons.check_circle_outline_rounded : Icons.file_upload_outlined,
            color: state == _DocState.done ? colors.success : colors.accentSecondary,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            state == _DocState.done ? 'Translation done — load another PDF' : 'Tap to pick a PDF Document',
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
        ]),
      ),
    );
  }
}

class _ProgressSection extends StatelessWidget {
  final double progress;
  final String statusMsg;
  final AppColors colors;
  final List<PageContent> pages;

  const _ProgressSection({required this.progress, required this.statusMsg, required this.colors, required this.pages});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: colors.bgCard,
              valueColor: AlwaysStoppedAnimation(colors.accentSecondary),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text('${(progress * 100).toStringAsFixed(0)}%',
          style: TextStyle(color: colors.accentSecondary, fontWeight: FontWeight.w800, fontSize: 16)),
      ]),
      const SizedBox(height: 8),
      Text(statusMsg, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
    ]);
  }
}

class _StatusChip extends StatelessWidget {
  final String message;
  final bool isError;
  final AppColors colors;

  const _StatusChip({required this.message, required this.isError, required this.colors});

  @override
  Widget build(BuildContext context) {
    final c = isError ? colors.error : colors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withOpacity(0.4)),
      ),
      child: Row(children: [
        Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: c, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: TextStyle(color: c, fontSize: 13))),
      ]),
    );
  }
}

class _PageNavBar extends StatelessWidget {
  final List<PageContent> pages;
  final int currentIndex;
  final Set<int> translatedKeys;
  final ValueChanged<int> onSelect;
  final AppColors colors;

  const _PageNavBar({required this.pages, required this.currentIndex, required this.translatedKeys, required this.onSelect, required this.colors});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: pages.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final isSelected = i == currentIndex;
          final isDone = translatedKeys.contains(i);
          return GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? colors.accentSecondary : (isDone ? colors.bgCard : colors.bgBase),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? colors.accentSecondary : (isDone ? const Color(0xFF30363D) : colors.bgCard),
                ),
              ),
              child: Text(
                'p${pages[i].pageNumber}',
                style: TextStyle(
                  color: isSelected ? Colors.white : (isDone ? colors.textPrimary : colors.textSecondary),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TranslatedPageView extends StatelessWidget {
  final PageContent pageContent;
  final String? translatedText;
  final String targetLang;
  final AppColors colors;

  const _TranslatedPageView({
    required this.pageContent, required this.translatedText,
    required this.targetLang, required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Original Text Block
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: colors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF30363D)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF30363D).withOpacity(0.4),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                ),
                child: Text('Original Document Text', style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SelectableText(
                  pageContent.text,
                  style: TextStyle(color: colors.textPrimary.withOpacity(0.8), fontSize: 13, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        const Icon(Icons.swap_vert_rounded, color: Colors.grey, size: 24),
        const SizedBox(height: 12),
        
        // Translated Text Block
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: colors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.accentSecondary.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: colors.accentSecondary.withOpacity(0.05),
                blurRadius: 10, spreadRadius: 2,
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: colors.accentSecondary.withOpacity(0.15),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Translated Text ($targetLang)', style: TextStyle(color: colors.accentSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: translatedText ?? ''));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied!')));
                      },
                      child: Icon(Icons.copy_rounded, color: colors.accentSecondary, size: 14),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: (translatedText == null || translatedText!.isEmpty)
                  ? Row(children: [
                      SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: colors.accentSecondary)),
                      const SizedBox(width: 10),
                      Text('Translating…', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                    ])
                  : SelectableText(
                      translatedText!,
                      style: TextStyle(color: colors.textPrimary, fontSize: 14, height: 1.65),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

