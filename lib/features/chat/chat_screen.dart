import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../core/services/cactus_service.dart';
import '../../shared/theme.dart';
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        title: const Row(
          children: [
            Icon(Icons.psychology, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('Cortex'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.memory),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => MemoryDashboard(ctrl: _ctrl)),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'clear_chat') _ctrl.clearChat();
              if (v == 'clear_all') await _ctrl.clearAll();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'clear_chat', child: Text('Clear chat')),
              const PopupMenuItem(value: 'clear_all', child: Text('Clear all memory')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _ctrl.messages.isEmpty
                ? _empty()
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: _ctrl.messages.length,
                    itemBuilder: (_, i) => MessageBubble(message: _ctrl.messages[i]),
                  ),
          ),
          InputBar(
            controller: _text,
            isGenerating: _ctrl.isGenerating,
            onSend: _send,
            onPhoto: _showImageSourceDialog,
            onVoice: _voice,
          ),
        ],
      ),
    );
  }

  Widget _empty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.psychology, size: 40, color: Colors.white),
        ),
        const SizedBox(height: 24),
        const Text(
          'Hello! I\'m Cortex',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 8),
        const Text(
          'I remember everything you tell me.',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 16),
        const Text(
          'Try: "My name is [Name] and I work at [Company]"',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    ),
  );

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
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.primaryColor),
              title: const Text('Gallery', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.primaryColor),
              title: const Text('Camera', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      // IMPORTANT: Constrain image size to prevent memory issues
      final img = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (img != null) {
        // Copy to permanent location (temp files can be cleaned up)
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedPath = p.join(appDir.path, 'images', fileName);

        // Create images directory if needed
        final imageDir = Directory(p.dirname(savedPath));
        if (!await imageDir.exists()) {
          await imageDir.create(recursive: true);
        }

        // Copy the image file
        await File(img.path).copy(savedPath);
        _ctrl.processPhoto(savedPath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  void _voice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Voice memo: coming soon!')),
    );
  }
}
