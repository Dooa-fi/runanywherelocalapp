import 'dart:async';
import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../theme/app_theme.dart';

class ChatMessage {
  final bool isPersonA;
  String original;
  String translated;
  ChatMessage(this.isPersonA, this.original, this.translated);
}

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final AudioService _audio = AudioService();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollCtrl = ScrollController();

  String _langA = 'English';
  String _langB = 'Spanish';

  final _languages = ['English', 'Hindi', 'Spanish'];

  bool _isRecordingA = false;
  bool _isRecordingB = false;
  bool _isTranslating = false;

  StreamSubscription<String>? _sub;

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _sub?.cancel();
    _audio.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _toggleMic(bool isPersonA) async {
    if ((isPersonA && _isRecordingB) || (!isPersonA && _isRecordingA) || _isTranslating) return;

    final isRecording = isPersonA ? _isRecordingA : _isRecordingB;

    if (isRecording) {
      // STOP
      await _sub?.cancel();
      final finalStr = await _audio.stopStreamingSTT();
      
      setState(() {
        if (isPersonA) _isRecordingA = false; else _isRecordingB = false;
        if (_messages.isNotEmpty && finalStr.isNotEmpty) {
          _messages.last.original = finalStr;
        } else if (_messages.isNotEmpty && finalStr.isEmpty) {
          _messages.removeLast(); // if empty drop it
        }
        _isTranslating = finalStr.isNotEmpty;
      });

      if (finalStr.isNotEmpty) {
        final source = isPersonA ? _langA : _langB;
        final target = isPersonA ? _langB : _langA;
        final translated = await _audio.translateOffline(finalStr, source, target);
        
        if (mounted) {
          setState(() {
            _messages.last.translated = translated;
            _isTranslating = false;
          });
          _scrollToBottom();
        }
      }
    } else {
      // START
      final lang = isPersonA ? _langA : _langB;
      final started = await _audio.startStreamingSTT(lang);
      
      if (!started) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mic Permission Denied')));
        return;
      }
      
      setState(() {
        if (isPersonA) _isRecordingA = true; else _isRecordingB = true;
        _messages.add(ChatMessage(isPersonA, 'Listening...', ''));
      });
      _scrollToBottom();
      
      _sub = _audio.transcriptStream.listen((text) {
        if (mounted) {
          setState(() {
            _messages.last.original = text;
          });
          _scrollToBottom();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bgBase,
      appBar: AppBar(
        title: const Text('Live Translator'),
        backgroundColor: colors.bgBase,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _LangDropdown(
                    val: _langA,
                    items: _languages,
                    colors: colors,
                    onChanged: (v) => setState(() => _langA = v!),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.sync_alt_rounded, color: colors.textSecondary),
                ),
                Expanded(
                  child: _LangDropdown(
                    val: _langB,
                    items: _languages,
                    colors: colors,
                    onChanged: (v) => setState(() => _langB = v!),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      'Tap a microphone below to start.',
                      style: TextStyle(color: colors.textSecondary.withOpacity(0.5)),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final msg = _messages[i];
                      return _ChatBubble(msg: msg, colors: colors);
                    },
                  ),
          ),
          if (_isTranslating)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Translating...', style: TextStyle(color: colors.textSecondary, fontStyle: FontStyle.italic)),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          color: colors.bgCard,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MicButton(
                isRecording: _isRecordingA,
                colors: colors,
                color: Colors.blueAccent,
                label: _langA,
                onTap: () => _toggleMic(true),
              ),
              _MicButton(
                isRecording: _isRecordingB,
                colors: colors,
                color: Colors.greenAccent,
                label: _langB,
                onTap: () => _toggleMic(false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LangDropdown extends StatelessWidget {
  final String val;
  final List<String> items;
  final AppColors colors;
  final ValueChanged<String?> onChanged;

  const _LangDropdown({required this.val, required this.items, required this.colors, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: val,
          isExpanded: true,
          dropdownColor: colors.bgCard,
          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  final bool isRecording;
  final AppColors colors;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _MicButton({required this.isRecording, required this.colors, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isRecording ? colors.error : color.withOpacity(0.15),
              border: Border.all(color: isRecording ? Colors.transparent : color, width: 2),
              boxShadow: isRecording ? [BoxShadow(color: colors.error.withOpacity(0.5), blurRadius: 20)] : [],
            ),
            child: Icon(
              isRecording ? Icons.stop_rounded : Icons.mic_rounded,
              color: isRecording ? Colors.white : color, size: 32,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage msg;
  final AppColors colors;

  const _ChatBubble({required this.msg, required this.colors});

  @override
  Widget build(BuildContext context) {
    final alignRight = !msg.isPersonA;
    final bubbleColor = msg.isPersonA ? Colors.blueAccent.withOpacity(0.15) : Colors.greenAccent.withOpacity(0.15);
    final borderColor = msg.isPersonA ? Colors.blueAccent.withOpacity(0.3) : Colors.greenAccent.withOpacity(0.3);

    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomLeft: alignRight ? const Radius.circular(16) : Radius.zero,
            bottomRight: alignRight ? Radius.zero : const Radius.circular(16),
          ),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              msg.original,
              style: TextStyle(color: colors.textPrimary, fontSize: 14),
              textAlign: alignRight ? TextAlign.right : TextAlign.left,
            ),
            if (msg.translated.isNotEmpty) ...[
              const Divider(color: Colors.white24, height: 16),
              Text(
                msg.translated,
                style: TextStyle(color: colors.accent, fontSize: 14, fontWeight: FontWeight.w600),
                textAlign: alignRight ? TextAlign.right : TextAlign.left,
              ),
            ]
          ],
        ),
      ),
    );
  }
}
