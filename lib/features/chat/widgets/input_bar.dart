import 'package:flutter/material.dart';
import '../../../shared/theme.dart';

class InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isGenerating;
  final VoidCallback onSend;
  final VoidCallback onPhoto;
  final VoidCallback onVoice;

  const InputBar({
    super.key,
    required this.controller,
    required this.isGenerating,
    required this.onSend,
    required this.onPhoto,
    required this.onVoice,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.photo_camera),
              color: AppTheme.primaryColor,
              onPressed: isGenerating ? null : onPhoto,
            ),
            IconButton(
              icon: const Icon(Icons.mic),
              color: AppTheme.primaryColor,
              onPressed: isGenerating ? null : onVoice,
            ),
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Message Cortex...',
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: InputBorder.none,
                ),
                style: const TextStyle(color: Colors.white),
                onSubmitted: (_) => onSend(),
                enabled: !isGenerating,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: isGenerating
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              color: AppTheme.primaryColor,
              onPressed: isGenerating ? null : onSend,
            ),
          ],
        ),
      ),
    );
  }
}
