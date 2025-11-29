import 'package:flutter/material.dart';
import '../theme.dart';
import '../../core/models/memory.dart';
import '../../core/models/semantic_fact.dart';
import '../../core/models/procedural_memory.dart';
import 'memory_strength_meter.dart';

/// Card displaying an episodic memory
class EpisodicMemoryCard extends StatelessWidget {
  final EpisodicMemory memory;
  final VoidCallback? onTap;

  const EpisodicMemoryCard({
    super.key,
    required this.memory,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: AppTheme.cardDecoration.copyWith(
          border: Border.all(
            color: AppTheme.episodicColor.withAlpha(50),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.episodicColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          memory.sourceIcon,
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          memory.source.name.toUpperCase(),
                          style: AppTheme.labelStyle.copyWith(
                            color: AppTheme.episodicColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    memory.ageDescription,
                    style: AppTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Content
              Text(
                memory.content,
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // Footer with strength
              Row(
                children: [
                  MemoryStrengthBar(
                    strength: memory.strength,
                    height: 6,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    memory.strengthDescription,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.getStrengthColor(memory.strength),
                    ),
                  ),
                  const Spacer(),
                  if (memory.consolidationState != ConsolidationState.shortTerm)
                    Icon(
                      memory.consolidationState == ConsolidationState.longTerm
                          ? Icons.lock
                          : Icons.sync,
                      size: 14,
                      color: AppTheme.textMuted,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card displaying a semantic fact
class SemanticFactCard extends StatelessWidget {
  final SemanticFact fact;
  final VoidCallback? onTap;

  const SemanticFactCard({
    super.key,
    required this.fact,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.semanticColor.withAlpha(40),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Category icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.semanticColor.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  fact.categoryIcon,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Fact content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fact.asNaturalLanguage,
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        fact.category.name,
                        style: AppTheme.labelStyle,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        fact.confidenceIndicator,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.semanticColor,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Confidence indicator
            Column(
              children: [
                Text(
                  '${(fact.confidence * 100).toInt()}%',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.semanticColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  fact.ageDescription,
                  style: AppTheme.labelStyle,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Card displaying a procedural rule
class ProceduralRuleCard extends StatelessWidget {
  final ProceduralMemory procedure;
  final VoidCallback? onTap;

  const ProceduralRuleCard({
    super.key,
    required this.procedure,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.proceduralColor.withAlpha(40),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Type icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.proceduralColor.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  procedure.typeIcon,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    procedure.description,
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        procedure.type.name.toUpperCase(),
                        style: AppTheme.labelStyle.copyWith(
                          color: AppTheme.proceduralColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        procedure.confidenceIndicator,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.proceduralColor,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Reliability
            Column(
              children: [
                Text(
                  '${(procedure.reliability * 100).toInt()}%',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.proceduralColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'reliable',
                  style: AppTheme.labelStyle,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
