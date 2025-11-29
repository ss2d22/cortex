import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/models/chat_message.dart';
import '../../../shared/theme.dart';

class MessageBubble extends StatefulWidget {
  final ChatMessageModel message;

  const MessageBubble({super.key, required this.message});

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _showThinking = false;

  @override
  Widget build(BuildContext context) {
    final message = widget.message;

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        child: Column(
          crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Image preview
            if (message.imageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(message.imageUrl!),
                  width: 200,
                  height: 150,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Message content
            if (message.isUser)
              _buildUserBubble(message)
            else
              _buildAssistantBubble(message),
          ],
        ),
      ),
    );
  }

  Widget _buildUserBubble(ChatMessageModel message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20).copyWith(
          bottomRight: const Radius.circular(4),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withAlpha(50),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        message.content,
        style: const TextStyle(
          color: Colors.white,
          height: 1.5,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildAssistantBubble(ChatMessageModel message) {
    if (message.isLoading && message.content.isEmpty) {
      return _buildTypingIndicator();
    }

    final parsed = _parseContent(message.content);
    final hasThinking = parsed.thinking.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Thinking section (collapsible)
        if (hasThinking) ...[
          GestureDetector(
            onTap: () => setState(() => _showThinking = !_showThinking),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight.withAlpha(150),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryColor.withAlpha(40),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.psychology,
                        size: 16,
                        color: AppTheme.primaryColor.withAlpha(180),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Thinking...',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.primaryColor.withAlpha(180),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        _showThinking ? Icons.expand_less : Icons.expand_more,
                        size: 16,
                        color: AppTheme.textMuted,
                      ),
                    ],
                  ),
                  if (_showThinking) ...[
                    const SizedBox(height: 10),
                    Text(
                      parsed.thinking,
                      style: AppTheme.bodySmall.copyWith(
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Main response
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(20).copyWith(
              bottomLeft: const Radius.circular(4),
            ),
            border: Border.all(
              color: Colors.white.withAlpha(10),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                parsed.response,
                style: const TextStyle(
                  color: Colors.white,
                  height: 1.5,
                  fontSize: 15,
                ),
              ),

              // Memory indicator (if memories were used)
              if (message.usedMemories > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.semanticColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.semanticColor.withAlpha(40),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.memory,
                        size: 14,
                        color: AppTheme.semanticColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${message.usedMemories} ${message.usedMemories == 1 ? 'memory' : 'memories'} used',
                        style: AppTheme.labelStyle.copyWith(
                          color: AppTheme.semanticColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) => _buildDot(i)),
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + index * 200),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withAlpha((100 + value * 155).toInt()),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  _ParsedContent _parseContent(String content) {
    final thinkMatch = RegExp(r'<think>(.*?)</think>', dotAll: true).firstMatch(content);

    String thinking = '';
    String response = content;

    if (thinkMatch != null) {
      thinking = thinkMatch.group(1)?.trim() ?? '';
      response = content.replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '').trim();
    }

    // Clean up response
    response = response
        .replaceAll(RegExp(r'<\|im_end\|>'), '')
        .replaceAll(RegExp(r'</s>'), '')
        .trim();

    return _ParsedContent(thinking: thinking, response: response);
  }
}

class _ParsedContent {
  final String thinking;
  final String response;

  _ParsedContent({required this.thinking, required this.response});
}
