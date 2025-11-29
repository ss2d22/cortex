import 'package:flutter/material.dart';
import '../../shared/theme.dart';
import '../../core/models/semantic_fact.dart';
import '../../shared/widgets/memory_card.dart';
import '../chat/chat_controller.dart';

class SemanticFactsView extends StatefulWidget {
  final ChatController ctrl;

  const SemanticFactsView({super.key, required this.ctrl});

  @override
  State<SemanticFactsView> createState() => _SemanticFactsViewState();
}

class _SemanticFactsViewState extends State<SemanticFactsView> {
  FactCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final allFacts = widget.ctrl.getFacts();
    final facts = _selectedCategory == null
        ? allFacts
        : allFacts.where((f) => f.category == _selectedCategory).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildHeader(allFacts),
        const SizedBox(height: 20),
        _buildCategoryFilter(allFacts),
        const SizedBox(height: 20),
        if (facts.isEmpty)
          _buildEmptyState()
        else
          ...facts.map((f) => SemanticFactCard(
            fact: f,
            onTap: () => _showFactDetails(f),
          )),
      ],
    );
  }

  Widget _buildHeader(List<SemanticFact> facts) {
    final stats = SemanticMemoryStats.fromFacts(facts);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.semanticColor.withAlpha(30),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.lightbulb_outline,
            color: AppTheme.semanticColor,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Semantic Memory',
                style: AppTheme.headingSmall.copyWith(
                  color: AppTheme.semanticColor,
                ),
              ),
              Text(
                '${stats.totalFacts} facts known',
                style: AppTheme.bodySmall,
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.semanticColor.withAlpha(20),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Text(
                '${(stats.averageConfidence * 100).toInt()}%',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.semanticColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'avg',
                style: AppTheme.labelStyle,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryFilter(List<SemanticFact> facts) {
    final categories = <FactCategory, int>{};
    for (final fact in facts) {
      categories[fact.category] = (categories[fact.category] ?? 0) + 1;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(null, facts.length, 'All'),
          const SizedBox(width: 8),
          ...FactCategory.values
              .where((c) => (categories[c] ?? 0) > 0)
              .map((c) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildFilterChip(c, categories[c] ?? 0, c.name),
                  )),
        ],
      ),
    );
  }

  Widget _buildFilterChip(FactCategory? category, int count, String label) {
    final isSelected = _selectedCategory == category;

    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = category),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.semanticColor
              : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.semanticColor
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTheme.bodySmall.copyWith(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withAlpha(50)
                    : AppTheme.textMuted.withAlpha(50),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? Colors.white : AppTheme.textMuted,
                  fontWeight: FontWeight.bold,
                ),
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
          color: AppTheme.semanticColor.withAlpha(30),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.semanticColor.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lightbulb_outline,
              color: AppTheme.semanticColor,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _selectedCategory == null ? 'No facts yet' : 'No ${_selectedCategory!.name} facts',
            style: AppTheme.headingSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Share information about yourself in conversations and I\'ll learn facts about you automatically.',
            style: AppTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Try saying:\n"My name is Alex and I work at a startup"',
            style: AppTheme.bodySmall.copyWith(fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showFactDetails(SemanticFact fact) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  fact.categoryIcon,
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fact.asNaturalLanguage, style: AppTheme.headingSmall),
                      Text(
                        fact.category.name.toUpperCase(),
                        style: AppTheme.labelStyle.copyWith(
                          color: AppTheme.semanticColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildDetailRow('Confidence', '${(fact.confidence * 100).toInt()}%'),
            _buildDetailRow('Reinforced', '${fact.reinforceCount} times'),
            _buildDetailRow('First learned', fact.ageDescription),
            if (fact.isContradicted)
              _buildDetailRow('Status', 'Outdated', color: AppTheme.strengthLow),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTheme.bodyMedium),
          Text(
            value,
            style: AppTheme.bodyMedium.copyWith(
              color: color ?? AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
