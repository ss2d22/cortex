import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/cactus_service.dart';
import '../../shared/theme.dart';
import '../../shared/constants.dart';
import '../chat/chat_screen.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  String _currentModel = '';
  String _status = 'Starting...';
  double _progress = 0;
  bool _error = false;
  int _modelIndex = 0;
  static const int _totalModels = 5; // Primary, Embedding, RAG, STT, Vision

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _init();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final svc = context.read<CactusService>();

    svc.onProgress = (model, progress, status) {
      if (mounted) {
        setState(() {
          _currentModel = model;
          _progress = progress;
          _status = status;

          // Track model index for overall progress
          if (model == AppConstants.primaryModel) {
            _modelIndex = 0;
          } else if (model == AppConstants.embeddingModel) {
            _modelIndex = 1;
          } else if (model == 'RAG') {
            _modelIndex = 2;
          } else if (model == 'STT') {
            _modelIndex = 3;
          } else if (model == 'Vision') {
            _modelIndex = 4;
          }
        });
      }
    };

    try {
      await svc.initialize();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const ChatScreen(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = true;
          _status = 'Error: $e';
        });
      }
    }
  }

  double get _overallProgress {
    if (_totalModels == 0) return 0;
    return (_modelIndex + _progress) / _totalModels;
  }

  String get _modelDisplayName {
    switch (_currentModel) {
      case 'qwen3-0.6':
        return 'Chat Model';
      case 'nomic2-embed-300m':
        return 'Memory Model';
      case 'RAG':
        return 'Memory Database';
      case 'STT':
        return 'Voice Model';
      case 'Vision':
        return 'Vision Model';
      default:
        return _currentModel;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated logo
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withAlpha(77),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.psychology, size: 60, color: Colors.white),
                ),
              ),
              const SizedBox(height: 32),

              // App name
              const Text(
                'Cortex',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your AI with Memory',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withAlpha(179),
                ),
              ),
              const SizedBox(height: 48),

              // Progress section
              if (!_error) ...[
                // Model indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_totalModels, (index) {
                    final isActive = index == _modelIndex;
                    final isComplete = index < _modelIndex;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isComplete
                            ? AppTheme.primaryColor
                            : isActive
                                ? AppTheme.primaryColor.withAlpha(128)
                                : Colors.white.withAlpha(51),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),

                // Current model name
                if (_currentModel.isNotEmpty)
                  Text(
                    _modelDisplayName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withAlpha(230),
                    ),
                  ),
                const SizedBox(height: 8),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    backgroundColor: Colors.white.withAlpha(26),
                    valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 12),

                // Status text
                Text(
                  _status,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withAlpha(153),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Overall progress percentage
                Text(
                  '${(_overallProgress * 100).toInt()}% complete',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withAlpha(102),
                  ),
                ),
              ],

              // Error state
              if (_error) ...[
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red.withAlpha(204),
                ),
                const SizedBox(height: 16),
                Text(
                  _status,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _error = false;
                      _status = 'Retrying...';
                      _progress = 0;
                      _modelIndex = 0;
                    });
                    _init();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],

              const Spacer(),

              // Footer
              Text(
                'Running 100% on-device',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withAlpha(77),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your data never leaves your phone',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withAlpha(51),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
