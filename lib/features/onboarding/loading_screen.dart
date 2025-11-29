import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/cactus_service.dart';
import '../../shared/theme.dart';
import '../chat/chat_screen.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  String _status = 'Starting...';
  double _progress = 0;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final svc = context.read<CactusService>();
    svc.onProgress = (model, progress, status) {
      if (mounted) {
        setState(() {
          _progress = progress;
          _status = '$model: $status';
        });
      }
    };

    try {
      await svc.initialize();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ChatScreen()),
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
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.psychology, size: 60, color: Colors.white),
              ),
              const SizedBox(height: 32),
              const Text(
                'Cortex',
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Your AI with Memory',
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
              const SizedBox(height: 48),
              if (!_error)
                LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
                ),
              const SizedBox(height: 16),
              Text(
                _status,
                style: TextStyle(
                  color: _error ? Colors.red : Colors.white.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              if (_error) ...[
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _error = false;
                    });
                    _init();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
