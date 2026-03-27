import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/audio_service.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';

enum _RecordState { idle, recording, processing, done }

class MeetingNote {
  final DateTime timestamp;
  final String transcript;
  String summary;
  bool isStreaming;

  MeetingNote({
    required this.timestamp,
    required this.transcript,
    this.summary = '',
    this.isStreaming = false,
  });
}

class MeetingNotesScreen extends StatefulWidget {
  const MeetingNotesScreen({super.key});

  @override
  State<MeetingNotesScreen> createState() => _MeetingNotesScreenState();
}

class _MeetingNotesScreenState extends State<MeetingNotesScreen>
    with SingleTickerProviderStateMixin {
  final AudioService _audio = AudioService();
  final AudioPlayer _player = AudioPlayer();

  _RecordState _state = _RecordState.idle;
  String _statusMessage = '';
  bool _ttsLoading = false;
  
  // History of notes
  final List<MeetingNote> _notes = [];

  late final AnimationController _rippleCtrl;

  @override
  void initState() {
    super.initState();
    _rippleCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rippleCtrl.dispose();
    _audio.dispose();
    _player.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _toggleRecording() async {
    if (_state == _RecordState.recording) {
      await _stopAndProcess();
    } else if (_state == _RecordState.idle || _state == _RecordState.done) {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final started = await _audio.startRecording();
    if (!started) {
      _showSnack('Microphone permission denied');
      return;
    }
    setState(() {
      _state = _RecordState.recording;
      _statusMessage = 'Recording… tap again to stop';
    });
  }

  Future<void> _stopAndProcess() async {
    setState(() {
      _state = _RecordState.processing;
      _statusMessage = 'Transcribing with Whisper…';
    });

    final pcm = await _audio.stopRecordingAndGetPcm();
    if (pcm == null || pcm.isEmpty) {
      setState(() {
        _state = _RecordState.idle;
        _statusMessage = 'Recording too short — try again';
      });
      return;
    }

    final text = await _audio.transcribe(pcm);
    
    // Create new note entry at the top of the history
    final newNote = MeetingNote(
      timestamp: DateTime.now(),
      transcript: text,
      isStreaming: true,
    );
    
    setState(() {
      _notes.insert(0, newNote);
      _statusMessage = 'Summarizing with SmolLM2…';
    });

    // Stream LLM summary safely into the note
    await for (final token in _audio.summarizeMeeting(text)) {
      if (!mounted) return;
      setState(() {
        newNote.summary += token;
      });
    }

    setState(() {
      _state = _RecordState.done;
      newNote.isStreaming = false;
      _statusMessage = 'Done ✓ - Saved to History';
    });
  }

  Future<void> _playSummary(String summaryText) async {
    if (summaryText.isEmpty) return;
    setState(() => _ttsLoading = true);
    // Strip markdown for TTS
    final plainText = summaryText
        .replaceAll(RegExp(r'#+\s?'), '')
        .replaceAll(RegExp(r'\*+'), '')
        .replaceAll(RegExp(r'-\s'), '');
    final path = await _audio.synthesizeSpeech(plainText.substring(0, plainText.length.clamp(0, 800)));
    setState(() => _ttsLoading = false);
    if (path != null) {
      await _player.play(DeviceFileSource(path));
    } else {
      _showSnack('TTS not ready — make sure TTS model is loaded');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
                  _SectionHeader(
                    icon: Icons.mic_rounded,
                    color: colors.accent,
                    title: 'Meeting Notes',
                    subtitle: 'Summarize, save, and playback offline.',
                  ),
                  const SizedBox(height: 28),

                  // Record button
                  _RecordButton(
                    state: _state,
                    rippleAnim: _rippleCtrl,
                    colors: colors,
                    onTap: _toggleRecording,
                  ),

                  if (_statusMessage.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Center(
                      child: Text(
                        _statusMessage,
                        style: TextStyle(color: colors.textSecondary, fontSize: 13),
                      ),
                    ),
                  ],

                  if (_state == _RecordState.processing) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      backgroundColor: colors.bgCard,
                      valueColor: AlwaysStoppedAnimation(colors.accent),
                    ),
                  ],

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
          
          if (_notes.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.history_rounded, size: 48, color: colors.textSecondary.withOpacity(0.3)),
                      const SizedBox(height: 12),
                      Text('No history yet. Tap to start recording!', 
                        style: TextStyle(color: colors.textSecondary.withOpacity(0.5))),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final note = _notes[i];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    child: _NoteHistoryCard(
                      note: note,
                      colors: colors,
                      ttsLoading: _ttsLoading,
                      onPlaySummary: () => _playSummary(note.summary),
                    ),
                  );
                },
                childCount: _notes.length,
              ),
            ),
            
          const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
        ],
      ),
    );
  }
}

class _NoteHistoryCard extends StatelessWidget {
  final MeetingNote note;
  final AppColors colors;
  final bool ttsLoading;
  final VoidCallback onPlaySummary;

  const _NoteHistoryCard({
    required this.note,
    required this.colors,
    required this.ttsLoading,
    required this.onPlaySummary,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a').format(note.timestamp);
    
    return Container(
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Icon(Icons.event_note_rounded, color: colors.accent, size: 18),
                const SizedBox(width: 8),
                Text(
                  dateFormat,
                  style: TextStyle(
                    color: colors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13,
                  ),
                ),
                const Spacer(),
                if (!note.isStreaming && note.summary.isNotEmpty)
                  _IconChip(
                    icon: ttsLoading ? Icons.hourglass_top_rounded : Icons.volume_up_rounded,
                    label: 'Play Summary',
                    color: colors.accentSecondary,
                    onTap: ttsLoading ? null : onPlaySummary,
                  ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFF30363D)),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TRANSCRIPT', style: TextStyle(color: colors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                const SizedBox(height: 6),
                SelectableText(
                  note.transcript,
                  style: TextStyle(color: colors.textPrimary.withOpacity(0.8), fontSize: 13, height: 1.5),
                ),
                
                const SizedBox(height: 20),
                
                Row(
                  children: [
                    Text('AI SUMMARY', style: TextStyle(color: colors.accent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                    if (note.isStreaming) ...[
                      const SizedBox(width: 8),
                      _PulsingDot(color: colors.accent),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                if (note.summary.isEmpty && note.isStreaming)
                  const Text('Generating...', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
                else
                  MarkdownBody(
                    data: note.summary,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                      p: TextStyle(color: colors.textPrimary, fontSize: 14, height: 1.6),
                      h2: TextStyle(
                        color: colors.accent,
                        fontSize: 15, fontWeight: FontWeight.w700,
                      ),
                      listBullet: TextStyle(color: colors.accent),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Subwidgets ─────────────────────────────────────────────────────────────────

class _RecordButton extends StatelessWidget {
  final _RecordState state;
  final Animation<double> rippleAnim;
  final AppColors colors;
  final VoidCallback onTap;

  const _RecordButton({
    required this.state,
    required this.rippleAnim,
    required this.colors,
    required this.onTap,
  });

  Color get _btnColor {
    return switch (state) {
      _RecordState.recording => colors.error,
      _RecordState.processing => colors.warning,
      _ => colors.accent,
    };
  }

  IconData get _icon {
    return switch (state) {
      _RecordState.recording => Icons.stop_rounded,
      _RecordState.processing => Icons.hourglass_top_rounded,
      _ => Icons.mic_rounded,
    };
  }

  String get _label {
    return switch (state) {
      _RecordState.idle => 'Start Recording',
      _RecordState.recording => 'Stop Recording',
      _RecordState.processing => 'Processing…',
      _RecordState.done => 'Record Again',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: rippleAnim,
        builder: (context, child) {
          return GestureDetector(
            onTap: state == _RecordState.processing ? null : onTap,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Ripple rings when recording
                if (state == _RecordState.recording) ...[
                  _Ripple(size: 120 + rippleAnim.value * 30, color: colors.error, opacity: 0.15),
                  _Ripple(size: 100 + rippleAnim.value * 20, color: colors.error, opacity: 0.2),
                ],
                // Main button
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 88, height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _btnColor,
                    boxShadow: [
                      BoxShadow(
                        color: _btnColor.withOpacity(0.5),
                        blurRadius: 24, spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(_icon, color: Colors.black, size: 36),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Ripple extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;
  const _Ripple({required this.size, required this.color, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(opacity),
      ),
    );
  }
}

class _OutputCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  final Widget? trailing;

  const _OutputCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: iconColor, fontWeight: FontWeight.w700, fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          const Divider(height: 20, thickness: 1, color: Color(0xFF30363D)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              Text(subtitle, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.3, end: 1.0).animate(_ctrl),
      child: Container(
        width: 10, height: 10,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _IconChip({required this.icon, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
