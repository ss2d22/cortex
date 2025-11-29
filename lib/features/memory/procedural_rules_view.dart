import 'package:flutter/material.dart';
import '../../shared/theme.dart';
import '../../core/models/procedural_memory.dart';
import '../chat/chat_controller.dart';

class ProceduralRulesView extends StatefulWidget {
  final ChatController ctrl;

  const ProceduralRulesView({super.key, required this.ctrl});

  @override
  State<ProceduralRulesView> createState() => _ProceduralRulesViewState();
}

class _ProceduralRulesViewState extends State<ProceduralRulesView> {
  ProceduralType? _selectedType;

  @override
  Widget build(BuildContext context) {
    // Procedural rules would come from MemoryManager
    // For now, show the empty state with explanation

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildHeader(),
        const SizedBox(height: 20),
        _buildTypeFilter(),
        const SizedBox(height: 20),
        _buildEmptyState(),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.proceduralColor.withAlpha(30),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.rule,
            color: AppTheme.proceduralColor,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Procedural Memory',
                style: AppTheme.headingSmall.copyWith(
                  color: AppTheme.proceduralColor,
                ),
              ),
              Text(
                'Learned patterns and preferences',
                style: AppTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypeFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(null, 'All'),
          const SizedBox(width: 8),
          ...ProceduralType.values.map((t) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildFilterChip(t, t.name),
              )),
        ],
      ),
    );
  }

  Widget _buildFilterChip(ProceduralType? type, String label) {
    final isSelected = _selectedType == type;
    final icons = {
      ProceduralType.preference: Icons.favorite,
      ProceduralType.habit: Icons.repeat,
      ProceduralType.pattern: Icons.pattern,
      ProceduralType.rule: Icons.rule,
      ProceduralType.skill: Icons.lightbulb,
    };

    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.proceduralColor
              : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (type != null) ...[
              Icon(
                icons[type],
                size: 16,
                color: isSelected ? Colors.white : AppTheme.textMuted,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppTheme.bodySmall.copyWith(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
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
          color: AppTheme.proceduralColor.withAlpha(30),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.proceduralColor.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.psychology,
              color: AppTheme.proceduralColor,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Learning your patterns',
            style: AppTheme.headingSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'I learn your preferences, habits, and patterns from our conversations. These help me personalize my responses.',
            style: AppTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildPatternExample(
                  Icons.favorite,
                  'Preferences',
                  '"I prefer short answers"',
                ),
                const Divider(height: 24, color: AppTheme.surfaceColor),
                _buildPatternExample(
                  Icons.repeat,
                  'Habits',
                  '"I usually code in the morning"',
                ),
                const Divider(height: 24, color: AppTheme.surfaceColor),
                _buildPatternExample(
                  Icons.rule,
                  'Rules',
                  '"Never suggest meetings before 10am"',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatternExample(IconData icon, String type, String example) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.proceduralColor.withAlpha(30),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppTheme.proceduralColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                type,
                style: AppTheme.labelStyle.copyWith(
                  color: AppTheme.proceduralColor,
                ),
              ),
              Text(
                example,
                style: AppTheme.bodySmall.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
