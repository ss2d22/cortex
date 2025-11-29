import 'package:flutter/material.dart';
import '../../../shared/theme.dart';

class InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isGenerating;
  final bool isRecording;
  final VoidCallback onSend;
  final VoidCallback onPhoto;
  final VoidCallback onVoice;

  const InputBar({
    super.key,
    required this.controller,
    required this.isGenerating,
    this.isRecording = false,
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
            color: Colors.black.withAlpha(51),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Photo button
            IconButton(
              icon: const Icon(Icons.photo_camera),
              color: AppTheme.primaryColor,
              onPressed: isGenerating || isRecording ? null : onPhoto,
              tooltip: 'Add photo',
            ),

            // Voice button
            IconButton(
              icon: Icon(
                isRecording ? Icons.stop : Icons.mic,
                color: isRecording ? Colors.red : AppTheme.primaryColor,
              ),
              onPressed: isGenerating ? null : onVoice,
              tooltip: isRecording ? 'Stop recording' : 'Voice memo',
            ),

            // Text input
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: 'Message Cortex...',
                    hintStyle: TextStyle(color: Colors.white38),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(color: Colors.white),
                  onSubmitted: (_) => onSend(),
                  enabled: !isGenerating && !isRecording,
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Send button
            Container(
              decoration: BoxDecoration(
                color: isGenerating || isRecording
                    ? Colors.grey.withAlpha(50)
                    : AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: isGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white70),
                        ),
                      )
                    : const Icon(Icons.send, size: 20),
                color: Colors.white,
                onPressed: isGenerating || isRecording ? null : onSend,
                tooltip: 'Send message',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
