import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import '../../core/services/cactus_service.dart';
import '../../shared/theme.dart';
import '../../shared/constants.dart';
import '../memory/memory_dashboard.dart';
import 'chat_controller.dart';
import 'widgets/message_bubble.dart';
import 'widgets/input_bar.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late ChatController _ctrl;
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _picker = ImagePicker();
  final _recorder = AudioRecorder();

  bool _isRecording = false;
  String? _recordingPath;

  @override
  void initState() {
    super.initState();
    _ctrl = ChatController(context.read<CactusService>())..addListener(_update);
    _ctrl.initialize();
  }

  void _update() {
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _ctrl.removeListener(_update);
    _text.dispose();
    _scroll.dispose();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        title: Row(
          children: [
            const Icon(Icons.psychology, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            const Text('Cortex'),
            if (_ctrl.isReady) ...[
              const Spacer(),
              _buildMemoryIndicator(),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.memory),
            tooltip: 'Memory Explorer',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => MemoryDashboard(ctrl: _ctrl)),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'clear_chat') _ctrl.clearChat();
              if (v == 'clear_all') {
                final confirm = await _showConfirmDialog(
                  'Clear All Memory',
                  'This will delete all memories and facts. This cannot be undone.',
                );
                if (confirm == true) await _ctrl.clearAll();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'clear_chat', child: Text('Clear chat')),
              const PopupMenuItem(
                value: 'clear_all',
                child: Text('Clear all memory', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Recording indicator
          if (_isRecording)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.red.withAlpha(50),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Recording... Tap mic to stop',
                    style: TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),

          // Messages
          Expanded(
            child: _ctrl.messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: _ctrl.messages.length,
                    itemBuilder: (_, i) => MessageBubble(message: _ctrl.messages[i]),
                  ),
          ),

          // Input bar
          InputBar(
            controller: _text,
            isGenerating: _ctrl.isGenerating,
            isRecording: _isRecording,
            onSend: _send,
            onPhoto: _showImageSourceDialog,
            onVoice: _toggleRecording,
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryIndicator() {
    final stats = _ctrl.getMemoryStats();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withAlpha(50),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.memory, size: 14, color: AppTheme.primaryColor),
          const SizedBox(width: 4),
          Text(
            '${stats.totalMemories}',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo with gradient
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withAlpha(60),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.psychology, size: 45, color: Colors.white),
            ),
            const SizedBox(height: 28),

            // Title
            const Text(
              'Meet Cortex',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your AI that actually remembers you',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 32),

            // Privacy highlight
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(20),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.withAlpha(40)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.lock, color: Colors.green, size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '100% Private',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Everything runs on your device. No cloud, no data sharing.',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Features list
            _buildFeatureRow(Icons.memory, 'Remembers facts about you'),
            const SizedBox(height: 12),
            _buildFeatureRow(Icons.mic, 'Understands voice memos'),
            const SizedBox(height: 12),
            _buildFeatureRow(Icons.photo_camera, 'Analyzes your photos'),
            const SizedBox(height: 12),
            _buildFeatureRow(Icons.trending_up, 'Gets smarter over time'),

            const SizedBox(height: 32),

            // Try saying section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    'Start by introducing yourself:',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryColor.withAlpha(40)),
                    ),
                    child: const Text(
                      '"Hi! My name is Alex and I\'m a software engineer"',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 20),
        ),
        const SizedBox(width: 16),
        Text(
          text,
          style: const TextStyle(color: Colors.white70, fontSize: 15),
        ),
      ],
    );
  }

  void _send() {
    if (_text.text.trim().isEmpty) return;
    _ctrl.sendMessage(_text.text);
    _text.clear();
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.primaryColor),
              title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                'Select an existing photo',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.primaryColor),
              title: const Text('Take Photo', style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                'Capture with camera',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Check permission based on source
      Permission permission = source == ImageSource.camera
          ? Permission.camera
          : Permission.photos;

      var status = await permission.status;

      if (status.isDenied || status.isRestricted) {
        status = await permission.request();
      }

      if (status.isPermanentlyDenied) {
        if (mounted) {
          final permissionName = source == ImageSource.camera ? 'Camera' : 'Photos';
          final openSettings = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppTheme.surfaceColor,
              title: Text('$permissionName Access', style: const TextStyle(color: Colors.white)),
              content: Text(
                'Cortex needs $permissionName access to analyze images. Please enable it in Settings.',
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
          if (openSettings == true) {
            await openAppSettings();
          }
        }
        return;
      }

      final img = await _picker.pickImage(
        source: source,
        maxWidth: AppConstants.imageMaxDimension.toDouble(),
        maxHeight: AppConstants.imageMaxDimension.toDouble(),
        imageQuality: AppConstants.imageQuality,
      );
      if (img != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedPath = p.join(appDir.path, 'images', fileName);

        final imageDir = Directory(p.dirname(savedPath));
        if (!await imageDir.exists()) {
          await imageDir.create(recursive: true);
        }

        await File(img.path).copy(savedPath);
        _ctrl.processPhoto(savedPath);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().split(':').last.trim()}')),
        );
      }
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      // Check current permission status first
      var status = await Permission.microphone.status;

      // If not determined, request permission
      if (status.isDenied || status.isRestricted) {
        status = await Permission.microphone.request();
      }

      // Handle permanently denied - show dialog to open settings
      if (status.isPermanentlyDenied) {
        if (mounted) {
          final openSettings = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppTheme.surfaceColor,
              title: const Text('Microphone Access', style: TextStyle(color: Colors.white)),
              content: const Text(
                'Cortex needs microphone access for voice memos. Please enable it in Settings.',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
          if (openSettings == true) {
            await openAppSettings();
          }
        }
        return;
      }

      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tap the mic again to enable voice memos'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Double-check recorder has permission
      if (!await _recorder.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please grant microphone access')),
          );
        }
        return;
      }

      // Create path for recording
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.wav';
      _recordingPath = p.join(appDir.path, 'audio', fileName);

      // Ensure directory exists
      final audioDir = Directory(p.dirname(_recordingPath!));
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      // Start recording
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: _recordingPath!,
      );

      setState(() {
        _isRecording = true;
      });
    } catch (e) {
      debugPrint('Error starting recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting recording: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recorder.stop();

      setState(() {
        _isRecording = false;
      });

      if (path != null && path.isNotEmpty) {
        _ctrl.processVoice(path);
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      setState(() {
        _isRecording = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error stopping recording: $e')),
        );
      }
    }
  }

  Future<bool?> _showConfirmDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
