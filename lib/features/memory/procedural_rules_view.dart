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
    final allProcedures = widget.ctrl.memoryManager.procedures;
    final procedures = _selectedType == null
        ? allProcedures
        : allProcedures.where((p) => p.type == _selectedType).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildHeader(allProcedures.length),
        const SizedBox(height: 20),
        _buildTypeFilter(),
        const SizedBox(height: 20),
        if (procedures.isEmpty)
          _buildEmptyState()
        else
          ...procedures.map((p) => _buildProcedureCard(p)),
      ],
    );
  }

  Widget _buildHeader(int count) {
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
                '$count patterns learned',
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

  Widget _buildProcedureCard(ProceduralMemory proc) {
    final icons = {
      ProceduralType.preference: Icons.favorite,
      ProceduralType.habit: Icons.repeat,
      ProceduralType.pattern: Icons.pattern,
      ProceduralType.rule: Icons.rule,
      ProceduralType.skill: Icons.lightbulb,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.proceduralColor.withAlpha(40),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.proceduralColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icons[proc.type] ?? Icons.psychology,
                  size: 18,
                  color: AppTheme.proceduralColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      proc.type.name.toUpperCase(),
                      style: AppTheme.labelStyle.copyWith(
                        color: AppTheme.proceduralColor,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      proc.description,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Action
          if (proc.action.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.arrow_forward,
                    size: 14,
                    color: AppTheme.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      proc.action,
                      style: AppTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Confidence and reinforcement info
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Confidence: ',
                style: AppTheme.labelStyle,
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: proc.currentConfidence,
                    backgroundColor: Colors.white.withAlpha(10),
                    valueColor: AlwaysStoppedAnimation(
                      _getConfidenceColor(proc.currentConfidence),
                    ),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(proc.currentConfidence * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 11,
                  color: _getConfidenceColor(proc.currentConfidence),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (proc.successCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '+${proc.successCount}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
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

  Color _getConfidenceColor(double confidence) {
    if (confidence > 0.7) return AppTheme.strengthHigh;
    if (confidence > 0.4) return AppTheme.strengthMedium;
    return AppTheme.strengthLow;
  }
}
