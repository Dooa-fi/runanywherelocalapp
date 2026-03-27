import 'package:flutter/material.dart';
import '../services/model_manager.dart';
import '../theme/app_theme.dart';

/// First-launch screen that downloads + loads all AI models.
class ModelSetupScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const ModelSetupScreen({super.key, required this.onComplete});

  @override
  State<ModelSetupScreen> createState() => _ModelSetupScreenState();
}

class _ModelSetupScreenState extends State<ModelSetupScreen>
    with TickerProviderStateMixin {
  bool _loading = false;
  bool _error = false;
  String _phase = '';
  double _progress = 0;
  String _currentModel = '';

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _downloadModels() async {
    setState(() { _loading = true; _error = false; });
    try {
      await for (final event in ModelManager.loadAll()) {
        if (!mounted) return;
        setState(() {
          _phase = event.phase;
          _progress = event.progress;
          _currentModel = event.model;
        });
        if (event.done) {
          await Future.delayed(const Duration(milliseconds: 500));
          widget.onComplete();
        }
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = true; _phase = 'Error: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: colors.bgBase,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Logo area
              Center(
                child: ScaleTransition(
                  scale: _loading ? _pulseAnim : const AlwaysStoppedAnimation(1.0),
                  child: Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: colors.accent.withOpacity(0.35),
                          blurRadius: 32, spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              Text(
                'RunAnywhere\nOffline Copilot',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontSize: 30, height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Privacy-first · 100% On-Device · Works Offline',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),

              const SizedBox(height: 40),

              // Feature cards
              _FeatureRow(
                icon: Icons.mic_rounded,
                color: colors.accent,
                title: 'Meeting Notes',
                subtitle: 'Record → Transcribe → Summarize',
              ),
              const SizedBox(height: 12),
              _FeatureRow(
                icon: Icons.translate_rounded,
                color: colors.accentSecondary,
                title: 'Document Translator',
                subtitle: 'PDF → OCR → Translate offline',
              ),

              const Spacer(),

              // Progress / button area
              if (_loading) ...[
                _ModelBadge(model: _currentModel, colors: colors),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 8,
                    backgroundColor: colors.bgCard,
                    valueColor: AlwaysStoppedAnimation(colors.accent),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _phase,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(_progress * 100).toStringAsFixed(0)}%',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.accent, fontSize: 22, fontWeight: FontWeight.w800,
                  ),
                ),
              ] else if (_error) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.error.withOpacity(0.4)),
                  ),
                  child: Text(
                    _phase,
                    style: TextStyle(color: colors.error, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _downloadModels,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ] else ...[
                _InfoBox(
                  colors: colors,
                  message: 'First-run: downloads ~375 MB of AI models.\n'
                      'Models are cached on device — subsequent launches are instant.',
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _downloadModels,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Download AI Models & Start'),
                ),
              ],

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelBadge extends StatelessWidget {
  final String model;
  final AppColors colors;
  const _ModelBadge({required this.model, required this.colors});

  Color get _color {
    if (model.contains('Vosk')) return colors.accent;
    if (model.contains('Translation')) return colors.accentSecondary;
    return colors.textSecondary;
  }

  String get _label {
    if (model.contains('Vosk')) return '🎤 Speech Recognition ($model)';
    if (model.contains('Translation')) return '🌐 Translation Model (ML Kit)';
    return '⚙️ Initialising…';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _color.withOpacity(0.4)),
        ),
        child: Text(_label, style: TextStyle(color: _color, fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final AppColors colors;
  final String message;
  const _InfoBox({required this.colors, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.warning.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: colors.warning, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.warning.withOpacity(0.9), fontSize: 12.5, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
