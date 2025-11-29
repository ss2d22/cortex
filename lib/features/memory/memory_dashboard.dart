import 'package:flutter/material.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/memory_strength_meter.dart';
import '../../core/services/memory_manager.dart';
import '../../core/models/semantic_fact.dart';
import '../chat/chat_controller.dart';
import 'episodic_timeline.dart';
import 'semantic_facts_view.dart';
import 'procedural_rules_view.dart';

class MemoryDashboard extends StatefulWidget {
  final ChatController ctrl;

  const MemoryDashboard({super.key, required this.ctrl});

  @override
  State<MemoryDashboard> createState() => _MemoryDashboardState();
}

class _MemoryDashboardState extends State<MemoryDashboard>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withAlpha(
                          (50 + _pulseController.value * 50).toInt(),
                        ),
                        blurRadius: 8 + _pulseController.value * 4,
                        spreadRadius: _pulseController.value * 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.psychology,
                    color: Colors.white,
                    size: 20,
                  ),
                );
              },
            ),
            const SizedBox(width: 12),
            const Text('Memory', style: AppTheme.headingSmall),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textSecondary),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats header
          _buildStatsHeader(),

          // Tab bar
          Container(
            color: AppTheme.surfaceColor,
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: AppTheme.textMuted,
              indicatorColor: AppTheme.primaryColor,
              indicatorWeight: 3,
              labelStyle: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Episodes'),
                Tab(text: 'Facts'),
                Tab(text: 'Rules'),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                EpisodicTimeline(ctrl: widget.ctrl),
                SemanticFactsView(ctrl: widget.ctrl),
                ProceduralRulesView(ctrl: widget.ctrl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    final stats = _getStats();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withAlpha(10),
          ),
        ),
      ),
      child: Row(
        children: [
          _buildMiniStat(
            '${stats.semanticFactCount}',
            'Facts',
            AppTheme.semanticColor,
            Icons.lightbulb_outline,
          ),
          _buildMiniStat(
            '${stats.episodicCount}',
            'Episodes',
            AppTheme.episodicColor,
            Icons.timeline,
          ),
          _buildMiniStat(
            '${stats.proceduralCount}',
            'Rules',
            AppTheme.proceduralColor,
            Icons.rule,
          ),
          _buildMiniStat(
            '${(stats.averageFactConfidence * 100).toInt()}%',
            'Confidence',
            AppTheme.strengthHigh,
            Icons.verified,
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String value, String label, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: AppTheme.labelStyle.copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final stats = _getStats();
    final facts = widget.ctrl.getFacts();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Welcome card
        _buildWelcomeCard(stats),
        const SizedBox(height: 20),

        // Memory health
        Text('Memory Health', style: AppTheme.headingSmall),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildHealthCard(
                'Semantic',
                stats.averageFactConfidence,
                AppTheme.semanticColor,
                Icons.lightbulb,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildHealthCard(
                'Procedural',
                stats.averageProceduralConfidence,
                AppTheme.proceduralColor,
                Icons.rule,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Recent facts
        if (facts.isNotEmpty) ...[
          Row(
            children: [
              Text('Known Facts', style: AppTheme.headingSmall),
              const Spacer(),
              TextButton(
                onPressed: () => _tabController.animateTo(2),
                child: Text(
                  'See all',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...facts.take(5).map((fact) => _buildFactTile(fact)),
        ] else ...[
          _buildEmptyFactsCard(),
        ],
      ],
    );
  }

  Widget _buildWelcomeCard(MemoryStatistics stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withAlpha(40),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stats.totalMemories > 0
                      ? 'Memory Active'
                      : 'Getting Started',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stats.totalMemories > 0
                      ? '${stats.semanticFactCount} facts learned'
                      : 'Tell me about yourself!',
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Show fact count instead of confusing percentage
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${stats.semanticFactCount}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'facts',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withAlpha(200),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthCard(String label, double value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              Text(
                '${(value * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          MemoryStrengthBar(strength: value, height: 6),
          const SizedBox(height: 8),
          Text(label, style: AppTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildFactTile(SemanticFact fact) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.semanticColor.withAlpha(30)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.semanticColor.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  fact.categoryIcon,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),
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
                  const SizedBox(height: 2),
                  Text(
                    fact.category.name,
                    style: AppTheme.labelStyle.copyWith(
                      color: AppTheme.semanticColor,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              fact.confidenceIndicator,
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.semanticColor,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFactsCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withAlpha(
                    (20 + _pulseController.value * 20).toInt(),
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.psychology,
                  color: AppTheme.primaryColor,
                  size: 40,
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            'No memories yet',
            style: AppTheme.headingSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Share things about yourself and I\'ll remember them!',
            style: AppTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Try: "My name is Alex and I work at a startup"',
              style: AppTheme.bodySmall.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  MemoryStatistics _getStats() {
    return widget.ctrl.getMemoryStats();
  }
}
