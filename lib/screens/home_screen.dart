import 'package:flutter/material.dart';
import 'meeting_notes_screen.dart';
import 'doc_translator_screen.dart';
import 'conversation_screen.dart';
import 'model_setup_screen.dart';
import '../services/model_manager.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _modelsReady = false;
  late final AnimationController _fadeCtrl;

  final _tabs = const [
    _TabInfo(label: 'Meeting Notes', icon: Icons.mic_rounded),
    _TabInfo(label: 'Doc Translator', icon: Icons.translate_rounded),
    _TabInfo(label: 'Conversation', icon: Icons.forum_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _checkModels();
  }

  void _checkModels() {
    final ready = ModelManager.sttReady && ModelManager.llmReady;
    if (ready) {
      setState(() => _modelsReady = true);
      _fadeCtrl.forward();
    }
  }

  void _onModelsLoaded() {
    setState(() => _modelsReady = true);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (!_modelsReady) {
      return ModelSetupScreen(onComplete: _onModelsLoaded);
    }

    return Scaffold(
      backgroundColor: colors.bgBase,
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/logo.png', width: 32, height: 32),
            ),
            const SizedBox(width: 10),
            const Text('Offline Copilot'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.success.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.success.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(color: colors.success, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Offline',
                    style: TextStyle(
                      color: colors.success, fontSize: 12, fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeCtrl,
        child: IndexedStack(
          index: _currentIndex,
          children: const [
            MeetingNotesScreen(),
            DocTranslatorScreen(),
            ConversationScreen(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colors.bgSurface,
          border: Border(top: BorderSide(color: colors.bgCard, width: 1)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 68,
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final tab = _tabs[i];
                final selected = i == _currentIndex;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _currentIndex = i),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: selected ? colors.accent.withOpacity(0.12) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              tab.icon,
                              color: selected ? colors.accent : colors.textSecondary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            tab.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                              color: selected ? colors.accent : colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabInfo {
  final String label;
  final IconData icon;
  const _TabInfo({required this.label, required this.icon});
}
