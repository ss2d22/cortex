import 'package:flutter/material.dart';
import '../../shared/theme.dart';
import '../../core/models/memory.dart';
import '../chat/chat_controller.dart';

class EpisodicTimeline extends StatelessWidget {
  final ChatController ctrl;

  const EpisodicTimeline({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final episodes = ctrl.memoryManager.recentEpisodes;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildTimelineHeader(episodes.length),
        const SizedBox(height: 24),
        if (episodes.isEmpty)
          _buildEmptyState()
        else
          ...episodes.reversed.map((ep) => _buildEpisodeCard(ep)),
      ],
    );
  }

  Widget _buildTimelineHeader(int count) {
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
                '$count experiences stored',
                style: AppTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEpisodeCard(EpisodicMemory episode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getSourceColor(episode.source).withAlpha(40),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getSourceColor(episode.source).withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getSourceIcon(episode.source),
                      size: 14,
                      color: _getSourceColor(episode.source),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      episode.source.name,
                      style: TextStyle(
                        fontSize: 11,
                        color: _getSourceColor(episode.source),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (episode.importance > 0.6)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.star,
                    size: 12,
                    color: Colors.amber,
                  ),
                ),
              const Spacer(),
              Text(
                _formatTime(episode.timestamp),
                style: AppTheme.labelStyle,
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            _truncateContent(episode.content),
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textPrimary,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Strength: ',
                style: AppTheme.labelStyle,
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: episode.strength,
                    backgroundColor: Colors.white.withAlpha(10),
                    valueColor: AlwaysStoppedAnimation(
                      _getStrengthColor(episode.strength),
                    ),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(episode.strength * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 11,
                  color: _getStrengthColor(episode.strength),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
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
            'Your memories will appear here',
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

  Color _getSourceColor(MemorySource source) {
    switch (source) {
      case MemorySource.conversation:
        return AppTheme.primaryColor;
      case MemorySource.voice:
        return Colors.orange;
      case MemorySource.photo:
        return Colors.green;
      case MemorySource.explicit:
        return Colors.amber;
      case MemorySource.note:
        return Colors.blue;
    }
  }

  IconData _getSourceIcon(MemorySource source) {
    switch (source) {
      case MemorySource.conversation:
        return Icons.chat_bubble_outline;
      case MemorySource.voice:
        return Icons.mic;
      case MemorySource.photo:
        return Icons.photo_camera;
      case MemorySource.explicit:
        return Icons.push_pin;
      case MemorySource.note:
        return Icons.note;
    }
  }

  Color _getStrengthColor(double strength) {
    if (strength > 0.7) return AppTheme.strengthHigh;
    if (strength > 0.4) return AppTheme.strengthMedium;
    return AppTheme.strengthLow;
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.month}/${time.day}';
  }

  String _truncateContent(String content) {
    String cleaned = content
        .replaceAll(RegExp(r'^User:\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^Assistant:\s*', multiLine: true), '')
        .trim();

    if (cleaned.length > 200) {
      return '${cleaned.substring(0, 200)}...';
    }
    return cleaned;
  }
}
