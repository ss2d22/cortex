import 'package:flutter/material.dart';
import '../../shared/theme.dart';
import '../chat/chat_controller.dart';

class EpisodicTimeline extends StatelessWidget {
  final ChatController ctrl;

  const EpisodicTimeline({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    // For now, show placeholder since episodic memories are in RAG
    // In a full implementation, we'd query the RAG for recent memories

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildTimelineHeader(),
        const SizedBox(height: 24),
        _buildEmptyState(),
      ],
    );
  }

  Widget _buildTimelineHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.episodicColor.withAlpha(30),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.timeline,
            color: AppTheme.episodicColor,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Episodic Memory',
                style: AppTheme.headingSmall.copyWith(
                  color: AppTheme.episodicColor,
                ),
              ),
              Text(
                'Your experiences and conversations',
                style: AppTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.episodicColor.withAlpha(30),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.episodicColor.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_stories,
              color: AppTheme.episodicColor,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Your memories are stored',
            style: AppTheme.headingSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Episodic memories from your conversations are automatically stored and organized. They\'re used to provide context in future conversations.',
            style: AppTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildInfoRow(Icons.memory, 'Stored in vector database'),
                const SizedBox(height: 12),
                _buildInfoRow(Icons.trending_down, 'Natural decay over time'),
                const SizedBox(height: 12),
                _buildInfoRow(Icons.repeat, 'Strengthened by recall'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.episodicColor),
        const SizedBox(width: 12),
        Text(text, style: AppTheme.bodyMedium),
      ],
    );
  }
}
