import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/audio_service.dart';
import '../theme/app_theme.dart';

enum _RecordState { idle, recording }

class MeetingNote {
  final DateTime timestamp;
  String transcript;
  
  MeetingNote({required this.timestamp, required this.transcript});
}

class MeetingNotesScreen extends StatefulWidget {
  const MeetingNotesScreen({super.key});

  @override
  State<MeetingNotesScreen> createState() => _MeetingNotesScreenState();
}

class _MeetingNotesScreenState extends State<MeetingNotesScreen> with SingleTickerProviderStateMixin {
  final AudioService _audio = AudioService();
  _RecordState _state = _RecordState.idle;
  
  final List<MeetingNote> _notes = [];
  StreamSubscription<String>? _sub;
  
  late final AnimationController _rippleCtrl;
  final ScrollController _scrollCtrl = ScrollController();

  String _currentLang = 'en';
  final _languages = {'English': 'en', 'Hindi': 'hi', 'Spanish': 'es'};

  @override
  void initState() {
    super.initState();
    _rippleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rippleCtrl.dispose();
    _scrollCtrl.dispose();
    _audio.dispose();
    _sub?.cancel();
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

  Future<void> _toggleRecording() async {
    if (_state == _RecordState.recording) {
      // Stop
      await _sub?.cancel();
      final finalStr = await _audio.stopStreamingSTT();
      if (_notes.isNotEmpty) {
        setState(() {
          _notes[0].transcript = finalStr;
          _state = _RecordState.idle;
        });
      }
    } else {
      // Start
      final started = await _audio.startStreamingSTT(_currentLang);
      if (!started) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mic Permission Denied')));
        return;
      }
      
      setState(() {
        _state = _RecordState.recording;
        _notes.insert(0, MeetingNote(timestamp: DateTime.now(), transcript: 'Listening...'));
      });
      
      _sub = _audio.transcriptStream.listen((text) {
        if (mounted) {
          setState(() {
            _notes[0].transcript = text;
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
        title: const Text('Meeting Notes'),
        backgroundColor: colors.bgBase,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _currentLang,
                dropdownColor: colors.bgCard,
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700),
                items: _languages.entries.map((e) => DropdownMenuItem(value: e.value, child: Text(e.key))).toList(),
                onChanged: _state == _RecordState.recording 
                    ? null 
                    : (val) => setState(() => _currentLang = val!),
              ),
            ),
          )
        ],
      ),
      body: _notes.isEmpty
          ? Center(
              child: Text(
                'No history yet. Tap to start recording!',
                style: TextStyle(color: colors.textSecondary.withOpacity(0.5)),
              ),
            )
          : ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100), // padding for bottom button
              itemCount: _notes.length,
              reverse: true, // Auto-scroll natively by showing newest at bottom if we insert at 0 and reverse
              itemBuilder: (context, i) {
                final note = _notes[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.bgCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF30363D)),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('MMM d, yyyy • h:mm a').format(note.timestamp),
                          style: TextStyle(color: colors.accent, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        SelectableText(
                          note.transcript,
                          style: TextStyle(color: colors.textPrimary, fontSize: 14, height: 1.5),
                        ),
                        if (i == 0 && _state == _RecordState.recording)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Row(
                              children: [
                                SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: colors.accent)),
                                const SizedBox(width: 8),
                                Text('Listening...', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                              ],
                            ),
                          )
                      ],
                    ),
                  ),
                );
              },
            ),
      // FIXED BUTTON
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          color: colors.bgBase.withOpacity(0.9),
          child: Center(
            heightFactor: 1.0,
            child: GestureDetector(
              onTap: _toggleRecording,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _state == _RecordState.recording ? colors.error : colors.accent,
                  boxShadow: _state == _RecordState.recording 
                      ? [BoxShadow(color: colors.error.withOpacity(0.5), blurRadius: 20)]
                      : [],
                ),
                child: Icon(
                  _state == _RecordState.recording ? Icons.stop_rounded : Icons.mic_rounded,
                  color: Colors.black, size: 32,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
