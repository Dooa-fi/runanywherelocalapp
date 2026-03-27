import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/audio_service.dart';
import '../theme/app_theme.dart';

enum _ConvState { idle, recording, processing, speaking }

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final AudioService _audio = AudioService();
  final AudioPlayer _player = AudioPlayer();

  // "Top" User (Person A)
  String _langA = 'English';
  String _textA = 'Tap mic to speak…';
  
  // "Bottom" User (Person B)
  String _langB = 'Hindi';
  String _textB = 'Tap mic to speak…';

  final _languages = [
    'English', 'Hindi', 'Spanish', 'French', 'German', 'Portuguese', 'Italian',
    'Russian', 'Japanese', 'Korean', 'Chinese (Simplified)', 'Arabic',
  ];

  _ConvState _stateA = _ConvState.idle;
  _ConvState _stateB = _ConvState.idle;

  @override
  void dispose() {
    _audio.dispose();
    _player.dispose();
    super.dispose();
  }

  // ── Logic ──────────────────────────────────────────────────────────────────

  Future<void> _handleMicPress({
    required bool isPersonA,
  }) async {
    // Prevent if the other person is using the mic or currently processing
    if (isPersonA && _stateB != _ConvState.idle) return;
    if (!isPersonA && _stateA != _ConvState.idle) return;

    final currentState = isPersonA ? _stateA : _stateB;

    if (currentState == _ConvState.recording) {
      // Stop recording and process
      await _stopAndProcess(isPersonA);
    } else if (currentState == _ConvState.idle) {
      // Start recording
      final started = await _audio.startRecording();
      if (!started) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission denied')));
        return;
      }
      setState(() {
        if (isPersonA) {
          _stateA = _ConvState.recording;
          _textA = 'Recording...';
        } else {
          _stateB = _ConvState.recording;
          _textB = 'Recording...';
        }
      });
    }
  }

  Future<void> _stopAndProcess(bool isPersonA) async {
    setState(() {
      if (isPersonA) {
        _stateA = _ConvState.processing;
        _textA = 'Processing audio...';
      } else {
        _stateB = _ConvState.processing;
        _textB = 'Processing audio...';
      }
    });

    final pcm = await _audio.stopRecordingAndGetPcm();
    if (pcm == null || pcm.isEmpty) {
      setState(() {
        if (isPersonA) {
          _stateA = _ConvState.idle;
          _textA = 'Recording too short.';
        } else {
          _stateB = _ConvState.idle;
          _textB = 'Recording too short.';
        }
      });
      return;
    }

    // Determine translation target
    final targetLang = isPersonA ? _langB : _langA;

    // Transcribe
    setState(() {
      if (isPersonA) _textA = 'Transcribing...';
      else _textB = 'Transcribing...';
    });
    
    final originalText = await _audio.transcribe(pcm);

    // Translate
    setState(() {
      if (isPersonA) _textA = 'Original: $originalText\n\nTranslating to $targetLang...';
      else _textB = 'Original: $originalText\n\nTranslating to $targetLang...';
    });

    final translatedText = await _audio.translateShort(originalText, targetLang);

    setState(() {
      if (isPersonA) {
        _textA = 'Original: $originalText\n\nTranslated: $translatedText';
        _stateA = _ConvState.speaking;
      } else {
        _textB = 'Original: $originalText\n\nTranslated: $translatedText';
        _stateB = _ConvState.speaking;
      }
    });

    // Play TTS
    final path = await _audio.synthesizeSpeech(translatedText);
    if (path != null) {
      await _player.play(DeviceFileSource(path));
      // Wait for it to finish
      _player.onPlayerComplete.first.then((_) {
        if (mounted) {
          setState(() {
            if (isPersonA) _stateA = _ConvState.idle;
            else _stateB = _ConvState.idle;
          });
        }
      });
    } else {
      setState(() {
        if (isPersonA) _stateA = _ConvState.idle;
        else _stateB = _ConvState.idle;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('TTS error or Model missing.')));
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bgBase,
      body: Column(
        children: [
          // Top Half (Inverted for person opposite you)
          Expanded(
            child: RotatedBox(
              quarterTurns: 2, // Rotates 180 degrees so the person sitting across can read it
              child: _buildHalf(
                isTop: true,
                state: _stateA,
                lang: _langA,
                text: _textA,
                languages: _languages,
                colors: colors,
                onLangChanged: (v) => setState(() => _langA = v!),
                onMicTap: () => _handleMicPress(isPersonA: true),
                disabled: _stateB != _ConvState.idle,
              ),
            ),
          ),

          // Divider
          Container(height: 4, color: const Color(0xFF30363D)),

          // Bottom Half (For you)
          Expanded(
            child: _buildHalf(
              isTop: false,
              state: _stateB,
              lang: _langB,
              text: _textB,
              languages: _languages,
              colors: colors,
              onLangChanged: (v) => setState(() => _langB = v!),
              onMicTap: () => _handleMicPress(isPersonA: false),
              disabled: _stateA != _ConvState.idle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHalf({
    required bool isTop,
    required _ConvState state,
    required String lang,
    required String text,
    required List<String> languages,
    required AppColors colors,
    required ValueChanged<String?> onLangChanged,
    required VoidCallback onMicTap,
    required bool disabled,
  }) {
    final bool isActive = state != _ConvState.idle;
    
    Color boxColor;
    if (state == _ConvState.recording) boxColor = colors.error.withOpacity(0.1);
    else if (state == _ConvState.processing) boxColor = colors.warning.withOpacity(0.1);
    else if (state == _ConvState.speaking) boxColor = colors.success.withOpacity(0.1);
    else boxColor = colors.bgCard;

    return Container(
      color: colors.bgBase,
      child: SafeArea(
        bottom: !isTop,
        top: isTop,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Language Selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: colors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: lang,
                    dropdownColor: colors.bgCard,
                    style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
                    onChanged: (disabled || isActive) ? null : onLangChanged,
                    items: languages.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                  ),
                ),
              ),

              const Spacer(),

              // Text Display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: boxColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: state == _ConvState.recording ? colors.error : const Color(0xFF30363D)),
                ),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textPrimary.withOpacity(0.9),
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ),

              const Spacer(),

              // Mic Button
              GestureDetector(
                onTap: disabled && !isActive ? null : onMicTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: disabled && !isActive 
                        ? colors.bgCard 
                        : (state == _ConvState.recording ? colors.error : colors.accent),
                    boxShadow: (state == _ConvState.recording)
                      ? [BoxShadow(color: colors.error.withOpacity(0.5), blurRadius: 20, spreadRadius: 5)]
                      : [],
                  ),
                  child: Icon(
                    state == _ConvState.recording ? Icons.stop_rounded : Icons.mic_rounded,
                    color: disabled && !isActive ? colors.textSecondary : colors.bgBase,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                state == _ConvState.recording ? 'Tap to Stop' : 'Tap to Speak',
                style: TextStyle(
                  color: disabled && !isActive ? colors.textSecondary : colors.accent, 
                  fontWeight: FontWeight.w600, 
                  fontSize: 12
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
